[CmdletBinding()]
param([Parameter(Mandatory)][string]$ConfigPath,[Parameter(Mandatory)][ValidatePattern('^[a-zA-Z0-9_-]{1,80}$')][string]$RequestId,[Parameter(Mandatory)][string]$OutputDirectory)
. "$PSScriptRoot/Common.ps1"
$c=Read-WorkBoxConfig $ConfigPath;$s=Open-WorkBoxSession $c
try {
 $root=Join-Path $c.guestRoot 'desktop';$remote="$root/results/$RequestId.json"
 $status=Invoke-Command -Session $s -ArgumentList $root,$RequestId,$c.guestComputerName -ScriptBlock {
  param($root,$id,$expected)
  if($env:COMPUTERNAME -ne $expected -or (Get-CimInstance Win32_ComputerSystem).Model -ne 'Virtual Machine'){throw 'Guest identity mismatch'}
  @{result=(Test-Path "$root/results/$id.json");claimed=(Test-Path "$root/results/$id.claim");pending=(Test-Path "$root/requests/$id.json")}
 }
 if(!$status.result){$status|ConvertTo-Json;return}
 New-Item -ItemType Directory -Path $OutputDirectory -Force|Out-Null
 $local=Join-Path $OutputDirectory "$RequestId.json"
 if(Test-Path $local){throw 'Result destination already exists; use a new evidence directory'}
 Copy-Item -FromSession $s -LiteralPath $remote -Destination $local
 $r=Get-Content $local -Raw -Encoding UTF8|ConvertFrom-Json
 if($r.id -ne $RequestId){throw 'Result ID mismatch'}
 if($r.status -ne 'completed'){throw 'Guest action failed; inspect the local result privately'}
 $expected=[IO.Path]::GetFullPath("$root/results/$RequestId.png")
 if([IO.Path]::GetFullPath([string]$r.screenshot) -ne $expected){throw 'Unexpected screenshot path'}
 $png=Join-Path $OutputDirectory "$RequestId.png"
 Copy-Item -FromSession $s -LiteralPath $expected -Destination $png
 if((Get-FileHash $png).Hash -ne $r.sha256){throw 'Screenshot hash mismatch'}
 foreach($cap in $r.windowCaptures){
  $name="$RequestId-window-$([long]$cap.hwnd).png";$expected=[IO.Path]::GetFullPath("$root/results/$name")
  if([IO.Path]::GetFullPath([string]$cap.path) -ne $expected){throw 'Unexpected window image path'}
  $dest=Join-Path $OutputDirectory $name;Copy-Item -FromSession $s -LiteralPath $expected -Destination $dest
  if((Get-FileHash $dest).Hash -ne $cap.sha256){throw 'Window image hash mismatch'}
 }
 [pscustomobject]@{status='completed';request=$RequestId;result=$local;image=$png;meaning='Transport/action finished; inspect screenshot and task outcome separately'}|ConvertTo-Json
} finally {Remove-PSSession $s}
