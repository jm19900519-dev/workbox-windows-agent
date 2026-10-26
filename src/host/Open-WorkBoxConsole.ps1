[CmdletBinding()]
param([Parameter(Mandatory)][string]$ConfigPath,[switch]$CheckOnly)
. "$PSScriptRoot/Common.ps1"
$c=Read-WorkBoxConfig $ConfigPath;$vm=Get-WorkBoxVM $c
# Human-invoked entry only. The CMD entry also works without permission to run PS1 files.
$cmd=Join-Path $PSScriptRoot 'Open-WorkBoxConsole.cmd'
if($CheckOnly){& $cmd ([IO.Path]::GetFullPath($ConfigPath)) '-CheckOnly';if($LASTEXITCODE -ne 0){throw 'Console preflight failed'};return}
& $cmd ([IO.Path]::GetFullPath($ConfigPath))
if($LASTEXITCODE -ne 0){throw 'Console launch failed; inspect the private diagnostic'}
