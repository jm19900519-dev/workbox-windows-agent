param([Parameter(Mandatory)][string]$ConfigPath,[Parameter(Mandatory)][string]$EvidenceDirectory)
$ErrorActionPreference='Stop'
$hostDir=Join-Path $PSScriptRoot '../src/host'
. "$hostDir/Common.ps1"
$c=Read-WorkBoxConfig $ConfigPath
$task={
 param($hostDir,$config,$evidence)
 $state=& "$hostDir/Get-WorkBoxState.ps1" -ConfigPath $config|ConvertFrom-Json
 $id='observe-'+[guid]::NewGuid().ToString('N')
 New-Item -ItemType Directory -Path $evidence -Force|Out-Null
 $request=Join-Path $evidence "$id.request.json"
 @{id=$id;session=$state.session;action='observe'}|ConvertTo-Json|Set-Content $request -Encoding UTF8
 & "$hostDir/Invoke-WorkBoxDesktop.ps1" -ConfigPath $config -RequestPath $request -OutputDirectory $evidence
}
& "$hostDir/Invoke-WithWorkBoxLease.ps1" -ProjectName 'first-trial' -LeaseFile $c.leaseFile -ScriptBlock $task -ArgumentList @($hostDir,$ConfigPath,$EvidenceDirectory) -WaitSeconds 30
