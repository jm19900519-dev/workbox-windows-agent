[CmdletBinding()]
param([Parameter(Mandatory)][string]$ConfigPath)
. "$PSScriptRoot/Common.ps1"
$c=Read-WorkBoxConfig $ConfigPath;$s=Open-WorkBoxSession $c
try {
 $state=Invoke-Command -Session $s -ArgumentList $c -ScriptBlock {
  param($c)
  if($env:COMPUTERNAME -ne $c.guestComputerName -or (Get-CimInstance Win32_ComputerSystem).Model -ne 'Virtual Machine'){throw 'Guest identity mismatch'}
  $cfg=Get-Content (Join-Path $c.guestRoot 'browser.json') -Raw -Encoding UTF8|ConvertFrom-Json
  $r=Get-Content (Join-Path $c.guestRoot 'browser-state/server.json') -Raw -Encoding UTF8|ConvertFrom-Json
  $n=Get-CimInstance Win32_Process -Filter "ProcessId=$($r.nodePid)"
  $b=Get-CimInstance Win32_Process -Filter "ProcessId=$($r.browserPid)"
  $listener=@(Get-NetTCPConnection -State Listen -LocalPort $c.browserPort)
  if(!$n -or !$b -or $listener.Count -ne 1 -or $listener[0].OwningProcess -ne $n.ProcessId -or $listener[0].LocalAddress -ne $cfg.bindAddress){throw 'Listener/process proof failed'}
  if($n.ExecutablePath -ne $cfg.nodePath -or !$n.CommandLine.Contains((Join-Path $c.guestRoot 'browser/server.cjs')) -or $b.ParentProcessId -ne $n.ProcessId -or $b.SessionId -le 0 -or $b.SessionId -ne $n.SessionId -or $b.CommandLine -match '--headless|headless_shell'){throw 'Browser process/session proof failed'}
  foreach($p in @($n,$b)){if((Invoke-CimMethod -InputObject $p -MethodName GetOwner).User -ne $c.guestUser -or ([datetime]$r.timestamp).ToUniversalTime() -lt $p.CreationDate.ToUniversalTime()){throw 'Owner/creation proof failed'}}
  $url=[uri]$r.endpoint
  if($url.Scheme -ne 'ws' -or $url.Host -ne $cfg.bindAddress -or $url.Port -ne $c.browserPort -or $url.AbsolutePath.TrimStart('/') -ne $cfg.wsPath){throw 'Endpoint/config proof failed'}
  @{endpoint=$r.endpoint;playwright=$r.playwright;vmId=$c.vmId}
 }
 $state|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $c.stateDirectory 'connection.json') -Encoding UTF8
 Write-Output 'Verified connection saved in private state directory; endpoint suppressed.'
} finally {Remove-PSSession $s}
