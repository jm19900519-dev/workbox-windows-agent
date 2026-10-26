[CmdletBinding(SupportsShouldProcess)]
param([Parameter(Mandatory)][string]$ConfigPath)
. "$PSScriptRoot/Common.ps1"
$c=Read-WorkBoxConfig $ConfigPath
if(!$PSCmdlet.ShouldProcess($c.vmName,'Install WorkBox files and a non-elevated interactive scheduled task')){return}
$s=Open-WorkBoxSession $c
try {
 $preflight=Test-WorkBoxCompatibilityFacts -Facts (Get-WorkBoxGuestFacts -Session $s -Config $c) -Role guest
 Assert-WorkBoxCompatibility $preflight
 Invoke-Command -Session $s -ArgumentList $c -ScriptBlock {
  param($c)
  if($env:COMPUTERNAME -ne $c.guestComputerName -or (Get-CimInstance Win32_ComputerSystem).Model -ne 'Virtual Machine'){throw 'Guest identity mismatch'}
  $u=Get-LocalUser -Name $c.guestUser
  $admins=@(Get-LocalGroupMember -SID 'S-1-5-32-544')
  if($admins.SID.Value -contains $u.SID.Value){throw 'Use a dedicated non-administrator guest user'}
  if(Test-Path $c.guestRoot){throw 'Guest root already exists; installation will not overwrite a deployment'}
  if(Get-ScheduledTask -TaskName 'WorkBox Desktop Worker' -ErrorAction SilentlyContinue){throw 'Task already exists; no files were installed'}
  New-Item -ItemType Directory -Path $c.guestRoot|Out-Null
  $userSid=$u.SID.Value
  & icacls.exe $c.guestRoot /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' "*${userSid}:(OI)(CI)RX"|Out-Null
  if($LASTEXITCODE -ne 0){throw 'Guest source ACL failed'}
  foreach($name in @('desktop','desktop/requests','desktop/results','desktop/request-history','browser-state')){New-Item -ItemType Directory -Path (Join-Path $c.guestRoot $name)|Out-Null}
  foreach($name in @('desktop','browser-state')) {
   & icacls.exe (Join-Path $c.guestRoot $name) /grant:r "*${userSid}:(OI)(CI)M"|Out-Null
   if($LASTEXITCODE -ne 0){throw 'Guest state ACL failed'}
  }
  @{guestRoot=$c.guestRoot;guestComputerName=$c.guestComputerName;guestUser=$c.guestUser}|ConvertTo-Json|Set-Content (Join-Path $c.guestRoot 'guest.json') -Encoding UTF8
 }
 Copy-Item -ToSession $s -LiteralPath "$PSScriptRoot/../guest/desktop-worker.ps1" -Destination (Join-Path $c.guestRoot 'desktop-worker.ps1')
 Invoke-Command -Session $s -ArgumentList $c -ScriptBlock {
  param($c)
  $worker=Join-Path $c.guestRoot 'desktop-worker.ps1';$config=Join-Path $c.guestRoot 'guest.json'
  $exe=Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
  $action=New-ScheduledTaskAction -Execute $exe -Argument ('-NoProfile -NonInteractive -WindowStyle Hidden -File "{0}" -ConfigPath "{1}"' -f $worker,$config)
  $principal=New-ScheduledTaskPrincipal -UserId $c.guestUser -LogonType Interactive -RunLevel Limited
  $trigger=New-ScheduledTaskTrigger -AtLogOn -User $c.guestUser
  $settings=New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
  if(Get-ScheduledTask -TaskName 'WorkBox Desktop Worker' -ErrorAction SilentlyContinue){throw 'Task already exists; no overwrite'}
  Register-ScheduledTask -TaskName 'WorkBox Desktop Worker' -Action $action -Principal $principal -Trigger $trigger -Settings $settings|Out-Null
  $task=Get-ScheduledTask -TaskName 'WorkBox Desktop Worker'
  if($task.Principal.RunLevel -ne 'Limited' -or $task.Actions.Execute -ne $exe){throw 'Scheduled task readback mismatch'}
  Start-ScheduledTask -TaskName 'WorkBox Desktop Worker'
 }
 Write-Output 'Guest files/task installed. A signed-in ordinary desktop is required. Run Get-WorkBoxState; install success is not readiness.'
} finally {Remove-PSSession $s}
