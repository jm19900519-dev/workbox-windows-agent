[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$ConfigPath,
 [Parameter(Mandatory)][guid]$VMId,
 [Parameter(Mandatory)][string]$VMName,
 [Parameter(Mandatory)][string]$StateDirectory,
 [Parameter(Mandatory)][string]$GuestRoot,
 [Parameter(Mandatory)][string]$GuestComputerName,
 [Parameter(Mandatory)][string]$GuestUser,
 [Parameter(Mandatory)][pscredential]$GuestAdministratorCredential,
 [ValidateRange(1024,65535)][int]$BrowserPort=3033
)
. "$PSScriptRoot/Common.ps1"
if(Test-Path -LiteralPath $ConfigPath){throw 'Configuration exists; review it instead of overwriting'}
$c=[ordered]@{schema=1;vmId=$VMId.ToString();vmName=$VMName;stateDirectory=$StateDirectory;guestRoot=$GuestRoot;guestComputerName=$GuestComputerName;guestUser=$GuestUser;browserPort=$BrowserPort;credentialPath=(Join-Path $StateDirectory 'manager.credential.xml');leaseFile=(Join-Path $StateDirectory 'desktop.lease')}
$null=Get-VM -Id $VMId | Where-Object Name -eq $VMName
if(!(Get-VM -Id $VMId | Where-Object Name -eq $VMName)){throw 'VM name and ID must match'}
if(Test-Path -LiteralPath $StateDirectory){throw 'Use a new dedicated private state directory'}
New-Item -ItemType Directory -Path $StateDirectory|Out-Null
$sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
& icacls.exe $StateDirectory /inheritance:r /grant:r "*${sid}:(OI)(CI)F" '*S-1-5-18:(OI)(CI)F' | Out-Null
if($LASTEXITCODE -ne 0){throw 'Private directory ACL setup failed'}
$GuestAdministratorCredential|Export-Clixml -LiteralPath $c.credentialPath
$parent=Split-Path -Parent ([IO.Path]::GetFullPath($ConfigPath));New-Item -ItemType Directory -Path $parent -Force|Out-Null
$c|ConvertTo-Json|Set-Content -LiteralPath $ConfigPath -Encoding UTF8
$null=Read-WorkBoxConfig $ConfigPath
Write-Output 'Local configuration and same-user/machine protected credential created. Do not publish them.'
