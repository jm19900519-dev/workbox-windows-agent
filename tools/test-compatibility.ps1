[CmdletBinding()]
param([Parameter(Mandatory)][string]$EvidenceDirectory)
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -ne 'Core' -or $PSVersionTable.PSVersion.Major -lt 7){throw 'Run fixture tests with PowerShell 7.'}
. "$PSScriptRoot/../src/host/Compatibility.ps1"
$hostBase=@{windows=$true;osArchitecture='AMD64';processArchitecture='AMD64';build=26100;productType=1;installationType='Client';editionId='Professional';psEdition='Core';psVersion='7.4';languageMode='FullLanguage';getVm=$true;vmmsRunning=$true;psDirect=$true;vmconnect=$true;requireVm=$true;vmMatch=$true}
$guestBase=@{windows=$true;osArchitecture='AMD64';processArchitecture='AMD64';build=26100;productType=1;installationType='Client';editionId='Enterprise';psEdition='Desktop';psVersion='5.1';languageMode='FullLanguage';guestIdentity=$true;desktopAssemblies=$true;localAccounts=$true;scheduledTasks=$true;accountExists=$true;accountEnabled=$true;accountAdministrator=$false;interactiveSession=$true;targetPolicyKnown=$true;targetPolicy='RemoteSigned';nodeMajor=22;nodeArchitecture='x64';npmAvailable=$true;networkCmdlets=$true}
$cases=@(
 @{name='win11-host';role='host';patch=@{};desktop='pass';browser='pass'},
 @{name='win10-education-desktop-only';role='host';patch=@{build=19045;editionId='Education'};desktop='pass';browser='block'},
 @{name='win10-minimum-desktop-only';role='guest';patch=@{build=14393};desktop='pass';browser='block'},
 @{name='server2016-desktop-only';role='guest';patch=@{build=14393;productType=3;installationType='Server'};desktop='pass';browser='block'},
 @{name='server2019-desktop';role='host';patch=@{build=17763;productType=3;installationType='Server';editionId='ServerStandard'};desktop='pass';browser='pass'},
 @{name='home-host';role='host';patch=@{editionId='Core'};desktop='block';browser='block'},
 @{name='unknown-host-edition';role='host';patch=@{editionId=$null};desktop='unknown';browser='unknown'},
 @{name='old-os';role='guest';patch=@{build=10240};desktop='block';browser='block'},
 @{name='server-core';role='host';patch=@{productType=3;installationType='Server Core'};desktop='block';browser='block'},
 @{name='arm64';role='host';patch=@{osArchitecture='ARM64';processArchitecture='ARM64'};desktop='block';browser='block'},
 @{name='wow64';role='host';patch=@{osArchitecture='AMD64';processArchitecture='x86'};desktop='block';browser='block'},
 @{name='x86';role='guest';patch=@{osArchitecture='x86';processArchitecture='x86'};desktop='block';browser='block'},
 @{name='host-winps51';role='host';patch=@{psEdition='Desktop';psVersion='5.1'};desktop='block';browser='block'},
 @{name='host-winps-restricted-does-not-block-ps7';role='host';patch=@{targetPolicyKnown=$true;targetPolicy='Restricted'};desktop='pass';browser='pass'},
 @{name='missing-hyperv';role='host';patch=@{getVm=$false};desktop='block';browser='block'},
 @{name='missing-psdirect';role='host';patch=@{psDirect=$false};desktop='block';browser='block'},
 @{name='hyperv-stopped';role='host';patch=@{vmmsRunning=$false};desktop='block';browser='block'},
 @{name='wrong-vm';role='host';patch=@{vmMatch=$false};desktop='block';browser='block'},
 @{name='guest-identity';role='guest';patch=@{guestIdentity=$false};desktop='block';browser='block'},
 @{name='guest-ps7-is-not-worker51';role='guest';patch=@{psEdition='Core';psVersion='7.4'};desktop='block';browser='block'},
 @{name='missing-winforms';role='guest';patch=@{desktopAssemblies=$false};desktop='block';browser='block'},
 @{name='missing-localaccounts';role='guest';patch=@{localAccounts=$false};desktop='block';browser='block'},
 @{name='missing-scheduledtasks';role='guest';patch=@{scheduledTasks=$false};desktop='block';browser='block'},
 @{name='constrainedlanguage';role='guest';patch=@{languageMode='ConstrainedLanguage'};desktop='block';browser='block'},
 @{name='admin-target';role='guest';patch=@{accountAdministrator=$true};desktop='block';browser='block'},
 @{name='disabled-target';role='guest';patch=@{accountEnabled=$false};desktop='block';browser='block'},
 @{name='missing-target';role='guest';patch=@{accountExists=$false;accountAdministrator=$null};desktop='block';browser='block'},
 @{name='no-interactive-session';role='guest';patch=@{interactiveSession=$false};desktop='block';browser='block'},
 @{name='restricted-target';role='guest';patch=@{targetPolicy='Restricted'};desktop='block';browser='block'},
 @{name='allsigned-needs-trust-evidence';role='guest';patch=@{targetPolicy='AllSigned'};desktop='unknown';browser='unknown'},
 @{name='admin-policy-not-target-proof';role='guest';patch=@{targetPolicyKnown=$false;targetPolicy='RemoteSigned'};desktop='unknown';browser='unknown'},
 @{name='unrecognized-policy';role='guest';patch=@{targetPolicy='Unrecognized'};desktop='unknown';browser='unknown'},
 @{name='unknown-account';role='guest';patch=@{accountExists=$null};desktop='unknown';browser='unknown'},
 @{name='node20-desktop-unaffected';role='guest';patch=@{nodeMajor=20};desktop='pass';browser='block'},
 @{name='node24';role='guest';patch=@{nodeMajor=24};desktop='pass';browser='pass'},
 @{name='node26';role='guest';patch=@{nodeMajor=26};desktop='pass';browser='pass'},
 @{name='node-arm64';role='guest';patch=@{nodeArchitecture='arm64'};desktop='pass';browser='block'},
 @{name='missing-node';role='guest';patch=@{nodeMajor=$null;nodeArchitecture=$null};desktop='pass';browser='unknown'},
 @{name='missing-npm';role='guest';patch=@{npmAvailable=$false};desktop='pass';browser='block'},
 @{name='missing-browser-network';role='guest';patch=@{networkCmdlets=$false};desktop='pass';browser='block'}
)
$results=foreach($case in $cases){
 $base=if($case.role -eq 'host'){$hostBase}else{$guestBase};$facts=$base.Clone();foreach($key in $case.patch.Keys){$facts[$key]=$case.patch[$key]}
 $r=Test-WorkBoxCompatibilityFacts -Facts ([pscustomobject]$facts) -Role $case.role -Browser
 if($r.desktopStatus -ne $case.desktop -or $r.browserStatus -ne $case.browser){throw ('Fixture failed: '+$case.name+' got '+$r.desktopStatus+'/'+$r.browserStatus)}
 $denied=$false;try{Assert-WorkBoxCompatibility $r -Browser}catch{$denied=$true}
 if($denied -ne ($case.browser -ne 'pass')){throw ('Fail-closed guard mismatch: '+$case.name)}
 $desktopOnly=Test-WorkBoxCompatibilityFacts -Facts ([pscustomobject]$facts) -Role $case.role
 if($desktopOnly.browserRequested -or $null -ne $desktopOnly.browserStatus -or $desktopOnly.status -ne $case.desktop){throw 'Optional browser contaminated desktop result'}
 [pscustomobject]@{case=$case.name;role=$case.role;desktop=$r.desktopStatus;browser=$r.browserStatus;passed=$true}
}
$collectorProbe=& {
 function Invoke-Command {param($Session,$ArgumentList,$ScriptBlock) $ErrorActionPreference='Continue'; & $ScriptBlock @ArgumentList}
 function Get-CimInstance {param($ClassName,$Filter) switch($ClassName){'Win32_OperatingSystem'{[pscustomobject]@{BuildNumber=26100;ProductType=1}} 'Win32_ComputerSystem'{[pscustomobject]@{Model='Virtual Machine'}} 'Win32_Process'{[pscustomobject]@{SessionId=1}}}}
 function Get-ItemProperty {param($Path,$LiteralPath) if($Path){[pscustomobject]@{EditionID='Enterprise';InstallationType='Client'}}elseif($LiteralPath -like '*ShellIds*'){[pscustomobject]@{ExecutionPolicy='RemoteSigned'}}else{[pscustomobject]@{}}}
 function Test-Path {$true}
 function Add-Type {}
 function Get-LocalUser {[pscustomobject]@{SID=[pscustomobject]@{Value='S-1-5-21-111-222-333-1001'};Enabled=$true}}
 function Get-LocalGroupMember {Write-Error 'synthetic group lookup unavailable'}
 function Invoke-CimMethod {[pscustomobject]@{Sid='S-1-5-21-111-222-333-1001'}}
 $facts=Get-WorkBoxGuestFacts -Session synthetic -Config ([pscustomobject]@{guestComputerName=$env:COMPUTERNAME;guestUser='synthetic-user'}) 2>$null
 $decision=Test-WorkBoxCompatibilityFacts -Facts $facts -Role guest
 $accountCheck=@($decision.checks|Where-Object id -eq 'ordinary-account')[0]
 [pscustomobject]@{kind='Actual collector with inert OS/registry/account/PSDirect mocks; no VM contacted';accountExists=$facts.accountExists;accountAdministrator=$facts.accountAdministrator;accountCheck=$accountCheck.status;passed=($null -eq $facts.accountAdministrator -and $accountCheck.status -eq 'unknown')}
}
New-Item -ItemType Directory -Path $EvidenceDirectory -Force|Out-Null
$collectorProbe|ConvertTo-Json|Set-Content (Join-Path $EvidenceDirectory 'guest-collector-error.json') -Encoding UTF8
if(!$collectorProbe.passed){throw 'Unavailable group lookup must remain unknown, never non-administrator'}
$cmd=Get-Content "$PSScriptRoot/../src/host/Open-WorkBoxConsole.cmd" -Raw
$line=@($cmd -split '\r?\n'|Where-Object {$_ -like '*-Command *'})
if($line.Count -ne 1){throw 'Expected one CMD inline bootstrap'}
$inline=$line[0].Substring($line[0].IndexOf('-Command "')+10);$inline=$inline.Substring(0,$inline.Length-1)
$missingEdition=@'
function Get-CimInstance { [pscustomobject]@{BuildNumber='26100';ProductType=1} }
function Get-ItemProperty { [pscustomobject]@{EditionID=$null;InstallationType='Client'} }
function Get-VM { throw 'UNEXPECTED_VM_LOOKUP' }
'@
$nativePowerShell=Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
$output=& $nativePowerShell -NoProfile -NonInteractive -Command ($missingEdition+"`n"+$inline) 2>&1
$exitCode=$LASTEXITCODE
$cmdPassed=$exitCode -eq 10 -and ($output -join '') -match 'Windows metadata incomplete'
[pscustomobject]@{name='Missing EditionID rejected before config/VM lookup';exitCode=$exitCode;passed=$cmdPassed;output=@($output)}|ConvertTo-Json|Set-Content (Join-Path $EvidenceDirectory 'cmd-missing-edition.json') -Encoding UTF8
if(!$cmdPassed){throw 'CMD unknown metadata rejection fixture failed'}
[pscustomobject]@{passed=$true;kind='injected compatibility facts; NOT multi-Windows runtime acceptance';count=$results.Count;results=@($results)}|ConvertTo-Json -Depth 6|Set-Content (Join-Path $EvidenceDirectory 'compatibility-fixtures.json') -Encoding UTF8
Write-Output "$($results.Count) compatibility fixture cases passed; no VM was contacted or changed."
