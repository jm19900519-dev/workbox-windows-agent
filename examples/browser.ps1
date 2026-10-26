param([Parameter(Mandatory)][string]$ConfigPath,[Parameter(Mandatory)][string]$NodePath,[Parameter(Mandatory)][string]$EvidenceDirectory)
$ErrorActionPreference='Stop'
$hostDir=Join-Path $PSScriptRoot '../src/host'
. "$hostDir/Common.ps1"
$c=Read-WorkBoxConfig $ConfigPath
$task={
 param($hostDir,$config,$node,$connection,$evidence)
 & "$hostDir/Connect-WorkBoxBrowser.ps1" -ConfigPath $config
 & $node "$hostDir/../browser/example-task.cjs" $connection $evidence
 if($LASTEXITCODE -ne 0){throw 'Browser sample failed'}
}
& "$hostDir/Invoke-WithWorkBoxLease.ps1" -ProjectName 'browser-trial' -LeaseFile $c.leaseFile -ScriptBlock $task -ArgumentList @($hostDir,$ConfigPath,$NodePath,(Join-Path $c.stateDirectory 'connection.json'),$EvidenceDirectory) -WaitSeconds 30
