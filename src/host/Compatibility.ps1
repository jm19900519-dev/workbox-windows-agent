# Read-only collectors plus a pure, injectable compatibility decision function.
# A pass is a prerequisite result, never cross-version or UI acceptance.
function Test-WorkBoxCompatibilityFacts {
 param([Parameter(Mandatory)]$Facts,[Parameter(Mandatory)][ValidateSet('host','guest')][string]$Role,[switch]$Browser)
 $checks=[Collections.Generic.List[object]]::new()
 function Add-Check($Id,$Value,$Reason,$Component='desktop') {
  $status=if($null -eq $Value){'unknown'}elseif($Value -eq $true){'pass'}else{'block'}
  $checks.Add([pscustomobject]@{id=$Id;component=$Component;status=$status;reason=$Reason})
 }
 Add-Check 'windows' $Facts.windows 'Use a Windows Hyper-V environment; no feature is enabled automatically.'
 Add-Check 'native-x64' $(if(!$Facts.osArchitecture -or !$Facts.processArchitecture){$null}else{$Facts.osArchitecture -eq 'AMD64' -and $Facts.processArchitecture -eq 'AMD64'}) 'Use native x64 Windows and a 64-bit process. ARM64/x86 are outside this candidate.'
 Add-Check 'os-baseline' $(if(!$Facts.build -or !$Facts.productType){$null}else{[int]$Facts.build -ge 14393 -and [int]$Facts.productType -in @(1,2,3)}) 'Desktop baseline: x64 Windows build 14393 or later; this is a dependency floor, not all-version acceptance.'
 Add-Check 'desktop-experience' $(if(!$Facts.installationType){$null}else{$Facts.installationType -in @('Client','Server')}) 'A desktop-capable Windows installation is required. Server Core/Nano are not supported by this package.'
 Add-Check 'full-language' $(if(!$Facts.languageMode){$null}else{$Facts.languageMode -eq 'FullLanguage'}) 'FullLanguage is required by the native worker. Do not bypass a constrained-language policy.'
 if($Role -eq 'host') {
  Add-Check 'host-powershell7' $(if(!$Facts.psVersion -or !$Facts.psEdition){$null}else{$Facts.psEdition -eq 'Core' -and [version]$Facts.psVersion -ge [version]'7.0'}) 'Run host PS1 entrypoints using native PowerShell 7; Windows PowerShell 5.1 is reserved for the CMD bootstrap and guest worker.'
  Add-Check 'host-edition' $(if(!$Facts.editionId){$null}else{$Facts.editionId -notmatch '^(Core|CoreN|CoreSingleLanguage|CoreCountrySpecific|Starter|StarterN)$'}) 'Windows Home host editions do not provide the supported Hyper-V host role; Education is not excluded.'
  Add-Check 'hyperv-command' $Facts.getVm 'Install/enable the supported Hyper-V management tools through your normal administrator process.'
  Add-Check 'hyperv-service' $Facts.vmmsRunning 'The Hyper-V VM management service must already be running.'
  Add-Check 'psdirect-host' $Facts.psDirect 'The selected host PowerShell must expose New-PSSession -VMId.'
  Add-Check 'vmconnect' $Facts.vmconnect 'The official native VMConnect executable must be available for this package.'
  if($Facts.requireVm) { Add-Check 'configured-vm' $Facts.vmMatch 'The configured VM name/GUID must match a Running local VM; the checker never starts it.' }
 } else {
  Add-Check 'guest-windows-powershell51' $(if(!$Facts.psVersion -or !$Facts.psEdition){$null}else{$Facts.psEdition -eq 'Desktop' -and [version]$Facts.psVersion -ge [version]'5.1'}) 'The guest worker requires native Windows PowerShell 5.1.'
  Add-Check 'guest-identity' $Facts.guestIdentity 'PSDirect must reach the configured guest computer and Hyper-V virtual machine model.'
  Add-Check 'guest-desktop-assemblies' $Facts.desktopAssemblies 'System.Windows.Forms and System.Drawing must load; no GUI is opened by this check.'
  Add-Check 'guest-localaccounts' $Facts.localAccounts 'Get-LocalUser and Get-LocalGroupMember must be available in the native guest process.'
  Add-Check 'guest-scheduledtasks' $Facts.scheduledTasks 'The ScheduledTasks cmdlets must be available before any files or tasks are installed.'
  Add-Check 'ordinary-account' $(if($Facts.accountExists -eq $false){$false}elseif($null -eq $Facts.accountExists -or $null -eq $Facts.accountAdministrator -or $null -eq $Facts.accountEnabled){$null}else{$Facts.accountEnabled -and !$Facts.accountAdministrator}) 'Use the configured existing enabled non-administrator local account, checked against the Administrators group SID.'
  Add-Check 'ordinary-interactive-session' $Facts.interactiveSession 'Sign in normally to the configured ordinary desktop first; no password or logon policy is changed.'
  $policyOK=$null
  if($Facts.targetPolicyKnown) {
   if($Facts.targetPolicy -eq 'Restricted'){$policyOK=$false}
   elseif($Facts.targetPolicy -eq 'AllSigned'){$policyOK=$null}
   elseif($Facts.targetPolicy -in @('RemoteSigned','Unrestricted','Bypass')){$policyOK=$true}
  }
  Add-Check 'ordinary-script-policy' $policyOK 'This is the target ordinary account policy, not the PSDirect administrator policy. Restricted blocks; AllSigned needs independently trusted signed deployment. Unknown requires operator review; the installer never changes policy.'
 }
 if($Browser) {
  Add-Check 'browser-os' $(if(!$Facts.build -or !$Facts.productType){$null}else{([int]$Facts.productType -eq 1 -and [int]$Facts.build -ge 22000) -or ([int]$Facts.productType -in @(2,3) -and [int]$Facts.build -ge 17763)}) 'Optional browser baseline: Windows 11 or Windows Server 2019+ with desktop. Windows 10 desktop eligibility does not imply browser support.' 'browser'
  if($Role -eq 'guest') {
   Add-Check 'browser-node' $(if($null -eq $Facts.nodeMajor -or !$Facts.nodeArchitecture){$null}else{[int]$Facts.nodeMajor -in @(22,24,26) -and $Facts.nodeArchitecture -eq 'x64'}) 'Provide an existing native x64 Node.js 22, 24 or 26 executable. No runtime is downloaded by preflight.' 'browser'
   Add-Check 'browser-npm' $Facts.npmAvailable 'Provide an existing npm entrypoint before dependency download.' 'browser'
   Add-Check 'browser-network-cmdlets' $Facts.networkCmdlets 'NetTCPIP and NetSecurity commands must exist before browser/firewall installation.' 'browser'
  }
 }
 function Combine($Items) {if(@($Items|Where-Object status -eq 'block').Count){'block'}elseif(@($Items|Where-Object status -eq 'unknown').Count){'unknown'}else{'pass'}}
 $desktop=Combine @($checks|Where-Object component -eq 'desktop')
 $browserStatus=if($Browser){Combine @($checks)}else{$null}
 [pscustomobject]@{schema=1;role=$Role;desktopStatus=$desktop;browserRequested=[bool]$Browser;browserStatus=$browserStatus;browserScope=$(if(!$Browser){'not-requested'}elseif($Role -eq 'host'){'host OS prerequisites only; host Node/client package and browser readiness NOT assessed'}else{'guest installation prerequisites; installed Playwright identity and browser readiness NOT assessed'});readiness='not-assessed';status=$(if($Browser){$browserStatus}else{$desktop});checks=@($checks);evidenceKind='prerequisite facts only; not a cross-system or UI acceptance';summary=[pscustomobject]@{build=$Facts.build;productType=$Facts.productType;editionId=$Facts.editionId;installationType=$Facts.installationType;osArchitecture=$Facts.osArchitecture;processArchitecture=$Facts.processArchitecture;psVersion=$Facts.psVersion;psEdition=$Facts.psEdition}}
}

function Get-WorkBoxHostFacts {
 param($Config)
 $f=[ordered]@{windows=($env:OS -eq 'Windows_NT');osArchitecture=$env:PROCESSOR_ARCHITECTURE;processArchitecture=$env:PROCESSOR_ARCHITECTURE;psVersion=$PSVersionTable.PSVersion.ToString();psEdition=$PSVersionTable.PSEdition;languageMode=$ExecutionContext.SessionState.LanguageMode.ToString();getVm=$null;vmmsRunning=$null;psDirect=$null;vmconnect=$null;requireVm=($null -ne $Config);vmMatch=$null}
 if($env:PROCESSOR_ARCHITEW6432){$f.osArchitecture=$env:PROCESSOR_ARCHITEW6432}
 if($f.windows){
  try {$os=Get-CimInstance Win32_OperatingSystem;$reg=Get-ItemProperty 'HKLM:/SOFTWARE/Microsoft/Windows NT/CurrentVersion';$f.build=[int]$os.BuildNumber;$f.productType=[int]$os.ProductType;$f.editionId=$reg.EditionID;$f.installationType=$reg.InstallationType}catch{}
  $f.getVm=[bool](Get-Command Get-VM -ErrorAction SilentlyContinue)
  $cmd=Get-Command New-PSSession -ErrorAction SilentlyContinue;$f.psDirect=[bool]($cmd -and $cmd.Parameters.ContainsKey('VMId'))
  $f.vmmsRunning=[bool](Get-Service vmms -ErrorAction SilentlyContinue|Where-Object Status -eq 'Running')
  $f.vmconnect=Test-Path (Join-Path $env:SystemRoot 'System32/vmconnect.exe') -PathType Leaf
  if($Config -and $f.getVm){try{$vm=Get-VM -Id ([guid]$Config.vmId);$f.vmMatch=($vm.Name -eq $Config.vmName -and $vm.State.ToString() -eq 'Running')}catch{$f.vmMatch=$false}}
 }
 [pscustomobject]$f
}

function Get-WorkBoxGuestFacts {
 param([Parameter(Mandatory)]$Session,[Parameter(Mandatory)]$Config,[switch]$Browser,[string]$GuestNodePath,[string]$GuestNpmPath)
 Invoke-Command -Session $Session -ArgumentList $Config,[bool]$Browser,$GuestNodePath,$GuestNpmPath -ScriptBlock {
  param($c,$browser,$node,$npm)
  $ErrorActionPreference='Stop'
  $os=Get-CimInstance Win32_OperatingSystem;$reg=Get-ItemProperty 'HKLM:/SOFTWARE/Microsoft/Windows NT/CurrentVersion'
  $f=[ordered]@{windows=$true;build=[int]$os.BuildNumber;productType=[int]$os.ProductType;editionId=$reg.EditionID;installationType=$reg.InstallationType;osArchitecture=$env:PROCESSOR_ARCHITECTURE;processArchitecture=$env:PROCESSOR_ARCHITECTURE;psVersion=$PSVersionTable.PSVersion.ToString();psEdition=$PSVersionTable.PSEdition;languageMode=$ExecutionContext.SessionState.LanguageMode.ToString();guestIdentity=($env:COMPUTERNAME -eq $c.guestComputerName -and (Get-CimInstance Win32_ComputerSystem).Model -eq 'Virtual Machine');desktopAssemblies=$null;localAccounts=$false;scheduledTasks=$false;accountExists=$null;accountAdministrator=$null;interactiveSession=$null;targetPolicyKnown=$false;targetPolicy=$null;nodeMajor=$null;nodeArchitecture=$null;npmAvailable=$null;networkCmdlets=$null}
  if($env:PROCESSOR_ARCHITEW6432){$f.osArchitecture=$env:PROCESSOR_ARCHITEW6432}
  if(!$f.guestIdentity){return [pscustomobject]$f}
  try {Add-Type -AssemblyName System.Windows.Forms,System.Drawing;$f.desktopAssemblies=$true}catch{$f.desktopAssemblies=$false}
  $f.localAccounts=@('Get-LocalUser','Get-LocalGroupMember'|Where-Object {!(Get-Command $_ -ErrorAction SilentlyContinue)}).Count -eq 0
  $f.scheduledTasks=@('New-ScheduledTaskAction','New-ScheduledTaskPrincipal','New-ScheduledTaskTrigger','New-ScheduledTaskSettingsSet','Get-ScheduledTask','Register-ScheduledTask','Start-ScheduledTask'|Where-Object {!(Get-Command $_ -ErrorAction SilentlyContinue)}).Count -eq 0
  if($f.localAccounts){
   $u=$null
   try {$u=Get-LocalUser -Name $c.guestUser;$f.accountExists=[bool]$u;$f.accountEnabled=$u.Enabled;$f.accountAdministrator=@(Get-LocalGroupMember -SID 'S-1-5-32-544'|Where-Object {$_.SID.Value -eq $u.SID.Value}).Count -gt 0}catch{}
   if($u){
    try {$f.interactiveSession=@(Get-CimInstance Win32_Process -Filter "Name='explorer.exe'"|Where-Object {$_.SessionId -gt 0 -and (Invoke-CimMethod -InputObject $_ -MethodName GetOwnerSid).Sid -eq $u.SID.Value}).Count -gt 0}catch{}
    # Read the loaded target user's hive, never the PSDirect administrator's HKCU.
    $userHive='Registry::HKEY_USERS\'+$u.SID.Value
    if(Test-Path $userHive){
     try {
      $policies=@()
      foreach($entry in @(@{path='HKLM:/SOFTWARE/Policies/Microsoft/Windows/PowerShell';policy=$true},@{path=($userHive+'\Software\Policies\Microsoft\Windows\PowerShell');policy=$true},@{path=($userHive+'\Software\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell');policy=$false},@{path='HKLM:/SOFTWARE/Microsoft/PowerShell/1/ShellIds/Microsoft.PowerShell';policy=$false})){
       $v=$null
       try {$v=Get-ItemProperty -LiteralPath $entry.path -ErrorAction Stop}catch [System.Management.Automation.ItemNotFoundException]{}catch{throw}
       if($entry.policy -and $null -ne $v.EnableScripts){if($v.EnableScripts -eq 0){$policies+='Restricted'}elseif($v.ExecutionPolicy){$policies+=[string]$v.ExecutionPolicy}else{throw 'Unrecognized policy'}}
       elseif(!$entry.policy -and $v.ExecutionPolicy){$policies+=[string]$v.ExecutionPolicy}
      }
      $f.targetPolicy=if($policies.Count){$policies[0]}elseif($os.ProductType -eq 1){'Restricted'}else{'RemoteSigned'}
      $f.targetPolicyKnown=$f.targetPolicy -in @('Restricted','RemoteSigned','AllSigned','Unrestricted','Bypass')
     }catch{$f.targetPolicyKnown=$false}
    }
   }
  }
  if($browser){
   $f.npmAvailable=[bool]($npm -and (Test-Path -LiteralPath $npm -PathType Leaf))
   $f.networkCmdlets=@('Get-NetIPAddress','Get-NetTCPConnection','Get-NetFirewallRule','New-NetFirewallRule'|Where-Object {!(Get-Command $_ -ErrorAction SilentlyContinue)}).Count -eq 0
   if($node -and (Test-Path -LiteralPath $node -PathType Leaf)){
    try {$text=& $node -p 'JSON.stringify({major:Number(process.versions.node.split(String.fromCharCode(46))[0]),arch:process.arch})' 2>$null;if($LASTEXITCODE -eq 0){$n=$text|ConvertFrom-Json;$f.nodeMajor=$n.major;$f.nodeArchitecture=$n.arch}}catch{}
   }
  }
  [pscustomobject]$f
 }
}

function Assert-WorkBoxCompatibility {
 param([Parameter(Mandatory)]$Report,[switch]$Browser)
 $status=if($Browser){$Report.browserStatus}else{$Report.desktopStatus}
 if($status -ne 'pass'){
  $bad=@($Report.checks|Where-Object {$_.status -ne 'pass' -and ($Browser -or $_.component -eq 'desktop')}|ForEach-Object {$_.id+' ['+$_.status+']: '+$_.reason})
  throw ('WorkBox prerequisites '+$status+'. '+($bad -join ' '))
 }
}
