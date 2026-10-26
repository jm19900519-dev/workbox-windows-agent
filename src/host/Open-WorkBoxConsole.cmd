@echo off
setlocal EnableExtensions DisableDelayedExpansion
title WorkBox - Open existing desktop
set "WB_CONFIG=%~1"
set "WB_CHECK=0"
if /i "%~2"=="-CheckOnly" set "WB_CHECK=1"
if /i "%~1"=="-CheckOnly" set "WB_CHECK=1"
if /i "%~1"=="-CheckOnly" set "WB_CONFIG="
if not defined WB_CONFIG set "WB_CONFIG=%WORKBOX_CONFIG%"
if not defined WB_CONFIG set /p "WB_CONFIG=Absolute path to your private WorkBox config: "
if not defined WB_CONFIG goto FAILED
set "WB_POWERSHELL=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
rem A 32-bit caller on x64 must use the native system shell, not redirected SysWOW64.
if defined PROCESSOR_ARCHITEW6432 set "WB_POWERSHELL=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%WB_POWERSHELL%" goto MISSING
echo Checking the configured VM. No restart or credential change will be performed.
rem Inline read-only preflight and official CMD start route; no PS1 execution-policy bypass.
"%WB_POWERSHELL%" -NoProfile -NonInteractive -Command "$ErrorActionPreference='Stop'; $phase='configuration'; $log=$null; try { $phase='native Windows compatibility'; if($PSVersionTable.PSVersion -lt [version]'5.1' -or [IntPtr]::Size -ne 8 -or $env:PROCESSOR_ARCHITECTURE -ne 'AMD64'){throw 'Use native x64 Windows PowerShell 5.1 for this console bootstrap'}; $os=Get-CimInstance Win32_OperatingSystem; $edition=Get-ItemProperty 'HKLM:/SOFTWARE/Microsoft/Windows NT/CurrentVersion'; $phase='Windows metadata incomplete'; if(!$edition.EditionID -or !$edition.InstallationType -or !$os.BuildNumber -or !$os.ProductType){throw 'Required Windows metadata is unavailable'}; $phase='Windows desktop baseline'; if([int]$os.ProductType -notin @(1,2,3) -or [int]$os.BuildNumber -lt 14393 -or $edition.InstallationType -notin @('Client','Server') -or $edition.EditionID -match '^(Core|CoreN|CoreSingleLanguage|CoreCountrySpecific|Starter|StarterN)$'){throw 'Unsupported Windows desktop/Hyper-V host baseline'}; if(!(Get-Command Get-VM -ErrorAction SilentlyContinue)){throw 'Hyper-V management tools are unavailable'}; $phase='configuration'; $c=Get-Content -LiteralPath $env:WB_CONFIG -Raw -Encoding UTF8|ConvertFrom-Json; if($c.schema -ne 1){throw 'Unsupported config'}; $id=[guid]$c.vmId; if($id -eq [guid]::Empty){throw 'Empty VM ID'}; if([string]$c.stateDirectory -notmatch '^[A-Za-z]:[\\/]'){throw 'Absolute private state directory required'}; if(!(Test-Path -LiteralPath $c.stateDirectory -PathType Container)){throw 'Existing private state directory required'}; $log=Join-Path $c.stateDirectory 'console-launch.log'; $phase='VM identity/state'; $vm=Get-VM -Id $id; if($vm.Name -ne $c.vmName -or $vm.State.ToString() -ne 'Running'){throw 'Configured VM name/id/state mismatch'}; $exe=Join-Path $env:SystemRoot 'System32/vmconnect.exe'; if(!(Test-Path -LiteralPath $exe)){throw 'Official VMConnect unavailable'}; Add-Content -LiteralPath $log -Value ((Get-Date -Format o)+' preflight passed; no authentication change'); if($env:WB_CHECK -eq '1'){Write-Output 'Preflight passed; no window opened.'; exit 0}; $phase='console launch'; Write-Output ('Opening official console. Keep this window open. Local diagnostic: '+$log); $q=[char]34; $launch='start '+$q+$q+' /max /wait '+$q+$exe+$q+' localhost -G '+$id; $phase='console process startup'; $started=Get-Date; $launcher=Start-Process -FilePath $env:ComSpec -ArgumentList ('/d /c '+$launch) -WindowStyle Hidden -PassThru; $deadline=$started.AddSeconds(8); $console=$null; do { $items=@(Get-CimInstance Win32_Process -Filter ([char]78+'ame='+[char]39+'vmconnect.exe'+[char]39) | Where-Object { $_.ParentProcessId -eq $launcher.Id -and $_.CreationDate -ge $started.AddSeconds(-1) -and $_.CommandLine -match [regex]::Escape($id.ToString()) }); if($items.Count -eq 1){$console=$items[0]; break}; if($launcher.HasExited){break}; Start-Sleep -Milliseconds 200 } while((Get-Date) -lt $deadline); if(!$console){$phase='new VMConnect process not observed; inspect before retry'; throw 'No verified console PID'}; $phase='VMConnect exited too quickly'; $visible=Get-Process -Id $console.ProcessId -ErrorAction Stop; if($visible.WaitForExit(1000)){throw 'Console exited before visual acceptance'}; $phase='console lifetime'; Add-Content -LiteralPath $log -Value ((Get-Date -Format o)+' new VMConnect PID='+$console.ProcessId); Write-Output ('New VMConnect PID: '+$console.ProcessId+'. Verify the actual desktop yourself.'); $launcher.WaitForExit(); $code=$launcher.ExitCode; Add-Content -LiteralPath $log -Value ((Get-Date -Format o)+' console process exit='+$code); if($code -ne 0){throw 'VMConnect returned nonzero'}; Write-Output 'Console process exited. This does not prove visible desktop or successful authentication.'; exit 0 } catch { if($log){Add-Content -LiteralPath $log -Value ((Get-Date -Format o)+' failed phase='+$phase+' type='+$_.Exception.GetType().FullName) -ErrorAction SilentlyContinue}; Write-Output ('WorkBox failed during '+$phase+'. No restart or credential change requested.'); if($log){Write-Output ('Local diagnostic: '+$log)}; exit 10 }"
set "WB_EXIT=%ERRORLEVEL%"
if not "%WB_EXIT%"=="0" goto FAILED
if "%WB_CHECK%"=="1" exit /b 0
echo If no console appeared, preserve the diagnostic path above. Do not report success from exit code alone.
pause
exit /b 0
:MISSING
echo Required Windows PowerShell component was not found.
:FAILED
echo WorkBox could not be opened. Review the configured path, VM identity and local diagnostic.
if "%WB_CHECK%"=="1" exit /b 10
pause
exit /b 10
