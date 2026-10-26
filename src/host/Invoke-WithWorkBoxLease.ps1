[CmdletBinding(DefaultParameterSetName='ScriptPath')]
param(
    [Parameter(Mandatory)][ValidatePattern('^[\p{L}\p{N} ._-]{1,80}$')][string]$ProjectName,
    [Parameter(Mandatory,ParameterSetName='ScriptPath')][string]$ScriptPath,
    [Parameter(Mandatory,ParameterSetName='ScriptBlock')][scriptblock]$ScriptBlock,
    [object[]]$ArgumentList = @(),
    [ValidateRange(0,300)][int]$WaitSeconds = 0,
    # Every caller sharing a VM must use the same configured path.
    [Parameter(Mandatory)][string]$LeaseFile
)
$ErrorActionPreference = 'Stop'
if (![IO.Path]::IsPathRooted($LeaseFile)) { throw 'LeaseFile must be absolute.' }
$leasePath = [IO.Path]::GetFullPath($LeaseFile)
if ($PSCmdlet.ParameterSetName -eq 'ScriptPath') {
    if (![IO.Path]::IsPathRooted($ScriptPath)) { throw 'ScriptPath must be absolute.' }
    $target = Get-Item -LiteralPath $ScriptPath
    if ($target.PSIsContainer -or $target.Extension -ne '.ps1') { throw 'ScriptPath must be an existing PS1 file.' }
    $taskPath = $target.FullName
}
$null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($leasePath))
$held = $null
$timer = [Diagnostics.Stopwatch]::StartNew()
try {
    while ($null -eq $held) {
        try {
            $held = [IO.File]::Open($leasePath, [IO.FileMode]::OpenOrCreate,
                [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        } catch [IO.IOException] {
            $nativeCode = $_.Exception.HResult -band 0xffff
            if ($nativeCode -ne 32 -and $nativeCode -ne 33) { throw 'Lease file could not be opened; no task was run.' }
            if ($timer.Elapsed.TotalSeconds -ge $WaitSeconds) { throw 'WorkBox lease busy; no task was run.' }
            Start-Sleep -Milliseconds 100
        }
    }
    $owner = [ordered]@{
        project = $ProjectName
        processId = $PID
        processStartedUtc = (Get-Process -Id $PID).StartTime.ToUniversalTime().ToString('o')
        acquiredUtc = [DateTime]::UtcNow.ToString('o')
    }
    $bytes = [Text.Encoding]::UTF8.GetBytes(($owner | ConvertTo-Json -Compress))
    $held.SetLength(0)
    $held.Write($bytes, 0, $bytes.Length)
    $held.Flush()
    try {
        if ($PSCmdlet.ParameterSetName -eq 'ScriptPath') { & $taskPath @ArgumentList }
        else { & $ScriptBlock @ArgumentList }
    } catch {
        # Do not echo caller scripts, arguments, or exception data containing secrets.
        throw 'WorkBox task failed; inspect caller-owned evidence.'
    }
} finally {
    if ($null -ne $held) { $held.Dispose() }
}
