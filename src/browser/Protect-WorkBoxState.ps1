param([Parameter(Mandatory)][ValidateSet('Protect','Unprotect')][string]$Mode)
$ErrorActionPreference='Stop'
try {
 [Console]::InputEncoding=[Text.UTF8Encoding]::new($false)
 [Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
 Add-Type -AssemblyName System.Security
 $inputText=[Console]::In.ReadToEnd()
 $entropy=[Text.Encoding]::UTF8.GetBytes('WorkBox.project-state.v1')
 if($Mode -eq 'Protect') {
  $bytes=[Text.Encoding]::UTF8.GetBytes($inputText)
  $cipher=[Security.Cryptography.ProtectedData]::Protect($bytes,$entropy,[Security.Cryptography.DataProtectionScope]::CurrentUser)
  [Console]::Out.Write([Convert]::ToBase64String($cipher))
 } else {
  $bytes=[Convert]::FromBase64String($inputText)
  $plain=[Security.Cryptography.ProtectedData]::Unprotect($bytes,$entropy,[Security.Cryptography.DataProtectionScope]::CurrentUser)
  [Console]::Out.Write([Text.Encoding]::UTF8.GetString($plain))
 }
} catch { [Console]::Error.Write('Protected project state operation failed.'); exit 1 }
