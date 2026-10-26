[CmdletBinding()]
param([string]$ConfigPath,[switch]$IncludeGuest,[switch]$Browser,[string]$GuestNodePath,[string]$GuestNpmPath)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/Compatibility.ps1"
$config=$null
if($ConfigPath){try{$config=Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8|ConvertFrom-Json}catch{throw 'Private configuration could not be read/parsed; no guest was contacted. Details suppressed.'}}
$hostReport=Test-WorkBoxCompatibilityFacts -Facts (Get-WorkBoxHostFacts -Config $config) -Role host -Browser:$Browser
$guestReport=$null;$guestProbe='not-requested'
if($IncludeGuest){
 $guestProbe='unknown'
 if(!$config){$guestProbe='unknown: ConfigPath is required'}
 elseif($hostReport.desktopStatus -ne 'pass'){$guestProbe='blocked by host prerequisites; guest not contacted'}
 else {
  $s=$null
  try {
   . "$PSScriptRoot/Common.ps1"
   $config=Read-WorkBoxConfig $ConfigPath
   $s=Open-WorkBoxSession $config
   $guestReport=Test-WorkBoxCompatibilityFacts -Facts (Get-WorkBoxGuestFacts -Session $s -Config $config -Browser:$Browser -GuestNodePath $GuestNodePath -GuestNpmPath $GuestNpmPath) -Role guest -Browser:$Browser
   $guestProbe='completed'
  }catch{$guestProbe='unknown: guest probe failed ('+$_.Exception.GetType().Name+'); verify credentials/PSDirect locally; no configuration changed'}
  finally{if($s){Remove-PSSession $s}}
 }
}
$status=if($hostReport.status -eq 'block' -or ($guestReport -and $guestReport.status -eq 'block')){'block'}elseif($hostReport.status -eq 'unknown' -or ($IncludeGuest -and (!$guestReport -or $guestReport.status -eq 'unknown'))){'unknown'}else{'pass'}
[pscustomobject]@{schema=1;readOnly=$true;status=$status;time=(Get-Date -Format o);host=$hostReport;guest=$guestReport;guestProbe=$guestProbe;note='Use the shared whole-task lease for IncludeGuest. No VM start/install/policy changes. A pass is not cross-version or UI acceptance.'}|ConvertTo-Json -Depth 10
if($status -eq 'block'){exit 2}
if($status -eq 'unknown'){exit 3}
