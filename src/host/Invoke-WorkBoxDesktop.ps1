[CmdletBinding()]
param([Parameter(Mandatory)][string]$ConfigPath,[Parameter(Mandatory)][string]$RequestPath,[Parameter(Mandatory)][string]$OutputDirectory,[ValidateRange(1,300)][int]$TimeoutSeconds=60)
. "$PSScriptRoot/Common.ps1"
$c=Read-WorkBoxConfig $ConfigPath
$q=Get-Content -LiteralPath $RequestPath -Raw -Encoding UTF8|ConvertFrom-Json
if($q.id -notmatch '^[a-zA-Z0-9_-]{1,80}$'){throw 'Invalid request id'}
$s=Open-WorkBoxSession $c
try {
 $ready=Assert-WorkBoxWorker $s $c
 if($q.session -ne $ready.session){throw 'Request session mismatch'}
 if($ready.pendingRequests -gt 0){throw 'Unfinished request exists; inspect its original ID before sending any new request'}
 $root=Join-Path $c.guestRoot 'desktop'
 Invoke-Command -Session $s -ArgumentList $root,$q.id -ScriptBlock {
  param($root,$id)
  if((Test-Path "$root/requests/$id.json") -or (Test-Path "$root/results/$id.json") -or (Test-Path "$root/results/$id.claim") -or @(Get-ChildItem "$root/request-history" -Filter "$id.json" -Recurse -File).Count){throw 'ID already used; refuse replay'}
 }
 Copy-Item -ToSession $s -LiteralPath $RequestPath -Destination "$root/requests/$($q.id).tmp"
 Invoke-Command -Session $s -ArgumentList $root,$q.id -ScriptBlock {param($root,$id) Move-Item -LiteralPath "$root/requests/$id.tmp" -Destination "$root/requests/$id.json"}
 $deadline=(Get-Date).AddSeconds($TimeoutSeconds)
 do {
  $done=Invoke-Command -Session $s -ArgumentList $root,$q.id -ScriptBlock {param($root,$id) Test-Path "$root/results/$id.json"}
  if(!$done){Start-Sleep -Milliseconds 500}
 } until($done -or (Get-Date) -ge $deadline)
 if(!$done){throw 'Timed out. Do not replay. Use Get-WorkBoxResult with this same request ID.'}
 & "$PSScriptRoot/Get-WorkBoxResult.ps1" -ConfigPath $ConfigPath -RequestId $q.id -OutputDirectory $OutputDirectory
} finally {Remove-PSSession $s}
