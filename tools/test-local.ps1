[CmdletBinding()]
param([Parameter(Mandatory)][string]$EvidenceDirectory)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
New-Item -ItemType Directory -Path $EvidenceDirectory -Force|Out-Null
& "$PSScriptRoot/validate.ps1" -ReportPath (Join-Path $EvidenceDirectory 'powershell-parse.json')
$lease=Join-Path $EvidenceDirectory 'synthetic.lease'
$wrapper=Join-Path $repo 'src/host/Invoke-WithWorkBoxLease.ps1'
$held=[IO.File]::Open($lease,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
$denied=$false
try {
 try {& $wrapper -ProjectName 'fixture' -LeaseFile $lease -WaitSeconds 0 -ScriptBlock {throw 'SHOULD_NOT_RUN'}}
 catch {if($_.Exception.Message -like '*lease busy*'){$denied=$true}else{throw}}
} finally {$held.Dispose()}
if(!$denied){throw 'Busy lease fixture failed'}
$v=& $wrapper -ProjectName 'fixture' -LeaseFile $lease -ScriptBlock {'acquired'}
if($v -ne 'acquired'){throw 'Lease release/acquire fixture failed'}
$failed=$false
try {& $wrapper -ProjectName 'fixture' -LeaseFile $lease -ScriptBlock {throw 'synthetic task error'}}catch{$failed=$true}
$v=& $wrapper -ProjectName 'fixture' -LeaseFile $lease -ScriptBlock {'reacquired'}
if(!$failed -or $v -ne 'reacquired'){throw 'Lease finally-release fixture failed'}
$protector=Join-Path $repo 'src/browser/Protect-WorkBoxState.ps1'
$pwsh=(Get-Process -Id $PID).Path
function Protect-Fixture([string]$Mode,[string]$InputValue) {
 $info=[Diagnostics.ProcessStartInfo]::new($pwsh)
 $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardInput=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
 $info.StandardInputEncoding=[Text.UTF8Encoding]::new($false);$info.StandardOutputEncoding=[Text.UTF8Encoding]::new($false);$info.StandardErrorEncoding=[Text.UTF8Encoding]::new($false)
 foreach($arg in @('-NoProfile','-NonInteractive','-File',$protector,'-Mode',$Mode)){$info.ArgumentList.Add($arg)}
 $p=[Diagnostics.Process]::Start($info)
 try {$out=$p.StandardOutput.ReadToEndAsync();$err=$p.StandardError.ReadToEndAsync();$p.StandardInput.Write($InputValue);$p.StandardInput.Close();if(!$p.WaitForExit(10000)){$p.Kill();throw 'Synthetic protector test timed out'};$outValue=$out.GetAwaiter().GetResult();$null=$err.GetAwaiter().GetResult();return @{code=$p.ExitCode;value=$outValue}}finally{$p.Dispose()}
}
$plain='synthetic-workbox-state-中文-42'
$encrypted=Protect-Fixture 'Protect' $plain
if($encrypted.code -ne 0 -or $encrypted.value -eq $plain){throw 'DPAPI synthetic encryption failed'}
$decrypted=Protect-Fixture 'Unprotect' $encrypted.value
if($decrypted.code -ne 0 -or $decrypted.value -ne $plain){throw 'DPAPI synthetic roundtrip failed'}
$invalid=Protect-Fixture 'Unprotect' 'not-base64'
if($invalid.code -eq 0 -or $invalid.value){throw 'Invalid ciphertext must fail without plaintext output'}
@{passed=$true;scope='Local file handles and same-current-user synthetic DPAPI only. No VM/real login state used.';checks=@('busy lease refused','lease reacquired after release','lease released after task exception','DPAPI synthetic Unicode roundtrip','invalid ciphertext rejected');powershell=$PSVersionTable.PSVersion.ToString()}|ConvertTo-Json|Set-Content (Join-Path $EvidenceDirectory 'local-functional.json') -Encoding UTF8
Write-Output '5 local functional checks passed; no VM or real browser state used.'
