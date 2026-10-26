[CmdletBinding()]
param([Parameter(Mandatory)][string]$ReportPath)
$ErrorActionPreference='Stop'
if($PSVersionTable.PSEdition -ne 'Core' -or $PSVersionTable.PSVersion.Major -lt 7){throw 'Run host validation with native PowerShell 7.'}
$root=Split-Path -Parent $PSScriptRoot
$results=@()
foreach($file in Get-ChildItem "$root/src","$root/tools","$root/examples" -Filter '*.ps1' -Recurse -File -ErrorAction SilentlyContinue) {
 $tokens=$null;$errors=$null
 $null=[Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
 $results += [pscustomobject]@{file=[IO.Path]::GetRelativePath($root,$file.FullName).Replace('\','/');passed=($errors.Count -eq 0);errors=@($errors|ForEach-Object {$_.Message})}
}
$passed=@($results|Where-Object {!$_.passed}).Count -eq 0
@{passed=$passed;kind='PowerShell AST syntax only; no VM commands executed';powershell=$PSVersionTable.PSVersion.ToString();files=$results}|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $ReportPath -Encoding UTF8
if(!$passed){throw 'PowerShell parsing failed; inspect report'}
Write-Output "Parsed $($results.Count) PowerShell files; no VM changes."
