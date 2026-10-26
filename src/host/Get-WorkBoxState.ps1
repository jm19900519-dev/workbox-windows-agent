[CmdletBinding()]
param([Parameter(Mandatory)][string]$ConfigPath)
. "$PSScriptRoot/Common.ps1"
$c=Read-WorkBoxConfig $ConfigPath;$s=Open-WorkBoxSession $c
try { Assert-WorkBoxWorker $s $c | ConvertTo-Json } finally {Remove-PSSession $s}
