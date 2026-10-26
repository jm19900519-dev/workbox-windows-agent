[CmdletBinding(SupportsShouldProcess)]
param([Parameter(Mandatory)][string]$ConfigPath,[Parameter(Mandatory)][string]$GuestNodePath,[Parameter(Mandatory)][string]$GuestNpmPath,[Parameter(Mandatory)][string]$GuestCacheDirectory,[Parameter(Mandatory)][string]$GuestIPv4,[Parameter(Mandatory)][string]$HostIPv4)
. "$PSScriptRoot/Common.ps1"
$c=Read-WorkBoxConfig $ConfigPath
foreach($ip in @($GuestIPv4,$HostIPv4)){$parsed=$null;if(![Net.IPAddress]::TryParse($ip,[ref]$parsed) -or $parsed.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork -or $ip -eq '0.0.0.0' -or $ip -eq '255.255.255.255'){throw 'Provide one explicit IPv4 per side, no ranges'}}
foreach($p in @($GuestNodePath,$GuestNpmPath,$GuestCacheDirectory)){if($p -notmatch '^[A-Za-z]:[\\/]' -or $p -match '[\r\n"`]' -or $p.Contains('..')){throw 'Use absolute guest paths'}}
if(!$PSCmdlet.ShouldProcess($c.vmName,'Download browser dependencies in guest, restrict one firewall rule, register an interactive browser task')){return}
Assert-WorkBoxCompatibility (Test-WorkBoxCompatibilityFacts -Facts (Get-WorkBoxHostFacts -Config $c) -Role host -Browser) -Browser
$s=Open-WorkBoxSession $c
try {
 $preflight=Test-WorkBoxCompatibilityFacts -Facts (Get-WorkBoxGuestFacts -Session $s -Config $c -Browser -GuestNodePath $GuestNodePath -GuestNpmPath $GuestNpmPath) -Role guest -Browser
 Assert-WorkBoxCompatibility $preflight -Browser
 $app=Join-Path $c.guestRoot 'browser'
 Invoke-Command -Session $s -ArgumentList $c,$app,$GuestNodePath,$GuestNpmPath,$GuestIPv4 -ScriptBlock {
  param($c,$app,$node,$npm,$guestIp)
  if($env:COMPUTERNAME -ne $c.guestComputerName -or (Get-CimInstance Win32_ComputerSystem).Model -ne 'Virtual Machine'){throw 'Guest identity mismatch'}
  if(!(Test-Path (Join-Path $c.guestRoot 'guest.json'))){throw 'Install the desktop package first'}
  if(!(Test-Path $node) -or !(Test-Path $npm)){throw 'Install official Node.js in the guest first'}
  if(Test-Path $app){throw 'Browser directory exists; no overwrite'}
  if(!(Get-NetIPAddress -AddressFamily IPv4|Where-Object IPAddress -eq $guestIp)){throw 'Guest IP mismatch; no files were installed'}
  if(Get-NetFirewallRule -DisplayName 'WorkBox Browser Host Only' -ErrorAction SilentlyContinue){throw 'Firewall rule already exists; no files were installed'}
  if(Get-ScheduledTask -TaskName 'WorkBox Browser Server' -ErrorAction SilentlyContinue){throw 'Task already exists; no files were installed'}
  New-Item -ItemType Directory -Path $app|Out-Null
 }
 foreach($name in @('server.cjs','package.json','package-lock.json')){Copy-Item -ToSession $s -LiteralPath "$PSScriptRoot/../browser/$name" -Destination (Join-Path $app $name)}
 Invoke-Command -Session $s -ArgumentList $c,$app,$GuestNodePath,$GuestNpmPath,$GuestCacheDirectory,$GuestIPv4,$HostIPv4 -ScriptBlock {
  param($c,$app,$node,$npm,$cache,$guestIp,$hostIp)
  if(!(Get-NetIPAddress -AddressFamily IPv4|Where-Object IPAddress -eq $guestIp)){throw 'Guest IP mismatch'}
  if(Get-NetFirewallRule -DisplayName 'WorkBox Browser Host Only' -ErrorAction SilentlyContinue){throw 'Firewall rule already exists; review instead of overwriting'}
  if(Get-ScheduledTask -TaskName 'WorkBox Browser Server' -ErrorAction SilentlyContinue){throw 'Task already exists; no overwrite'}
  $env:npm_config_cache=Join-Path $cache 'npm';$env:PLAYWRIGHT_BROWSERS_PATH=Join-Path $cache 'browsers'
  New-Item -ItemType Directory -Path $cache -Force|Out-Null
  $userSid=(Get-LocalUser -Name $c.guestUser).SID.Value
  & icacls.exe $cache /grant:r "*${userSid}:(OI)(CI)RX"|Out-Null
  if($LASTEXITCODE -ne 0){throw 'Cache ACL failed'}
  Push-Location $app
  try {
   & $npm ci --ignore-scripts --no-audit --no-fund
   if($LASTEXITCODE -ne 0){throw 'npm install failed; exact candidate version may be unavailable; do not silently upgrade'}
   & $node (Join-Path $app 'node_modules/playwright/cli.js') install chromium
   if($LASTEXITCODE -ne 0){throw 'Chromium download failed'}
  } finally {Pop-Location}
  $bytes=New-Object byte[] 32;$rng=[Security.Cryptography.RandomNumberGenerator]::Create();try{$rng.GetBytes($bytes)}finally{$rng.Dispose()}
  $token=([BitConverter]::ToString($bytes)).Replace('-','').ToLowerInvariant()
  $bc=Join-Path $c.guestRoot 'browser.json'
  @{guestComputerName=$c.guestComputerName;guestUser=$c.guestUser;port=$c.browserPort;bindAddress=$guestIp;wsPath=$token;browserCache=$env:PLAYWRIGHT_BROWSERS_PATH;stateDirectory=(Join-Path $c.guestRoot 'browser-state');nodePath=$node}|ConvertTo-Json|Set-Content $bc -Encoding UTF8
  New-NetFirewallRule -DisplayName 'WorkBox Browser Host Only' -Direction Inbound -Action Allow -Protocol TCP -LocalAddress $guestIp -LocalPort $c.browserPort -RemoteAddress $hostIp -Program $node -Profile Any|Out-Null
  $action=New-ScheduledTaskAction -Execute $node -Argument ('"{0}" "{1}"' -f (Join-Path $app 'server.cjs'),$bc) -WorkingDirectory $app
  $principal=New-ScheduledTaskPrincipal -UserId $c.guestUser -LogonType Interactive -RunLevel Limited
  $settings=New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
  Register-ScheduledTask -TaskName 'WorkBox Browser Server' -Action $action -Principal $principal -Trigger (New-ScheduledTaskTrigger -AtLogOn -User $c.guestUser) -Settings $settings|Out-Null
  Start-ScheduledTask -TaskName 'WorkBox Browser Server'
 }
 Write-Output 'Browser files/task installed. Run Connect-WorkBoxBrowser and the leased sample to verify. No readiness claim.'
} finally {Remove-PSSession $s}
