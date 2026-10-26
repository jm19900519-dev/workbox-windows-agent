$ErrorActionPreference='Stop'
function Read-WorkBoxConfig([string]$Path) {
    $c=Get-Content -LiteralPath $Path -Raw -Encoding UTF8|ConvertFrom-Json
    if($c.schema -ne 1){throw 'Unsupported configuration schema'}
    if([guid]$c.vmId -eq [guid]::Empty){throw 'Configure a real VM ID'}
    foreach($key in @('stateDirectory','guestRoot','leaseFile','credentialPath')) {
        if([string]$c.$key -notmatch '^[A-Za-z]:[\\/]' -or [string]$c.$key -match '[\r\n"`]' -or ([string]$c.$key).Contains('..')){throw "Invalid absolute path: $key"}
    }
    if($c.guestComputerName -notmatch '^[A-Za-z0-9-]{1,15}$' -or $c.guestUser -notmatch '^[A-Za-z0-9_-]{1,32}$'){throw 'Invalid guest identity'}
    if($c.browserPort -lt 1024 -or $c.browserPort -gt 65535){throw 'Invalid browser port'}
    if($c.guestRoot.TrimEnd('\','/').Length -le 3){throw 'Guest root must be a dedicated directory'}
    return $c
}
function Get-WorkBoxVM($Config) {
    $vm=Get-VM -Id ([guid]$Config.vmId)
    if($vm.Name -ne $Config.vmName -or $vm.State -ne 'Running'){throw 'Configured VM name/id/state mismatch; no automatic restart'}
    return $vm
}
function Open-WorkBoxSession($Config) {
    $vm=Get-WorkBoxVM $Config
    $cred=Import-Clixml -LiteralPath $Config.credentialPath
    New-PSSession -VMId $vm.Id -Credential $cred
}
function Assert-WorkBoxWorker($Session,$Config) {
    $hash=(Get-FileHash (Join-Path $PSScriptRoot '../guest/desktop-worker.ps1') -Algorithm SHA256).Hash
    Invoke-Command -Session $Session -ArgumentList $Config,$hash -ScriptBlock {
        param($c,$hash)
        if($env:COMPUTERNAME -ne $c.guestComputerName -or (Get-CimInstance Win32_ComputerSystem).Model -ne 'Virtual Machine'){throw 'Guest identity mismatch'}
        $root=Join-Path $c.guestRoot 'desktop'
        $r=Get-Content "$root/ready.json" -Raw -Encoding UTF8|ConvertFrom-Json
        $p=Get-CimInstance Win32_Process -Filter "ProcessId=$($r.pid)"
        $worker=Join-Path $c.guestRoot 'desktop-worker.ps1'
        if(!$p -or $p.SessionId -le 0 -or $p.SessionId -ne $r.session -or (Invoke-CimMethod -InputObject $p -MethodName GetOwner).User -ne $c.guestUser -or !$p.CommandLine.Contains($worker)){throw 'Worker identity mismatch'}
        if($p.CreationDate.ToUniversalTime().Ticks.ToString() -ne [string]$r.processCreatedUtcTicks -or (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().Ticks.ToString() -ne [string]$r.bootUtcTicks){throw 'Worker creation/boot identity mismatch'}
        if($r.sourceSha256 -ne $hash -or (Get-FileHash $worker).Hash -ne $hash){throw 'Worker source identity mismatch'}
        $pending=@(Get-ChildItem "$root/requests" -Filter '*.json' -File | Where-Object {!(Test-Path "$root/results/$($_.BaseName).json")}).Count
        [pscustomobject]@{session=$r.session;workerPid=$r.pid;pendingRequests=$pending;sourceSha256=$hash}
    }
}
