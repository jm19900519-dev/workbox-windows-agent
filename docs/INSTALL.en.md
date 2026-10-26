# Installation

## Prerequisites

Use a supported Windows Hyper-V host with hardware virtualization, SLAT and sufficient memory/storage for both systems. Microsoft lists Windows 11 Pro/Enterprise for client Hyper-V; a Home host is not a supported target of this toolkit. Enable Hyper-V through Microsoft's normal process, including any required restart. [Official requirements](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/host-hardware-requirements).

Create or reuse a local Windows VM using your own licensed media. This package does not create a VM, install Windows, bypass OOBE, or provide activation. The [official Enterprise evaluation](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-11-enterprise) is 90 days, intended for professional evaluation; expiration can cause hourly shutdowns. Read the actual media terms. Do not redistribute the ISO/VHD under this project's license.

Configure one guest administrator for PowerShell Direct and a separate ordinary local guest user. Complete the ordinary user's first interactive sign-in. Keep the guest desktop unlocked during a trial. Do not use a personal browsing profile. PowerShell Direct requires a running local VM, valid guest credentials and Hyper-V administrator rights on the host. [Microsoft setup](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/powershell-direct).

Install [PowerShell 7](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows) on the host. The guest worker uses Windows PowerShell and WinForms. Apply your organization's script-signing/execution policy normally: this installer does not change machine policy or use a bypass. Run from a reviewed/unblocked local source checkout. This package does not use host GUI automation.

## Desktop setup

Run in elevated PowerShell 7. All examples use illustrative paths; replace every value with your own existing VM and directories. The state directory must be new and outside the repository. Avoid a synced/shared directory. Use one state directory and lease for every project sharing this VM.

```powershell
Get-VM | Select-Object Name,Id,State
$cfg='E:/WorkBoxLocal/workbox.local.json'
$cred=Get-Credential  # credentials of the guest administrator, never paste a password into source
./src/host/Initialize-WorkBoxConfig.ps1 -ConfigPath $cfg -VMId '<your-vm-guid>' -VMName 'MyWorkBox' -StateDirectory 'E:/WorkBoxPrivate' -GuestRoot 'D:/WorkBox' -GuestComputerName 'MYWORKBOX' -GuestUser 'DesktopAgent' -GuestAdministratorCredential $cred -BrowserPort 3033
./src/host/Install-WorkBoxGuest.ps1 -ConfigPath $cfg -WhatIf
./src/host/Install-WorkBoxGuest.ps1 -ConfigPath $cfg
./src/host/Get-WorkBoxState.ps1 -ConfigPath $cfg
./examples/observe.ps1 -ConfigPath $cfg -EvidenceDirectory 'E:/WorkBoxTrial/observe-01'
```

The guest root drive must exist. Installation refuses an existing root/task to avoid overwriting another deployment. It installs read-only source/config for the ordinary user, writable request/result areas and a non-elevated interactive scheduled task. Successful installation is not successful desktop readiness. Inspect the fresh image and receipt. State and credentials stay local; the credential XML is bound by Windows DPAPI to the host user/machine.

## Optional browser setup

For a person who wants to view the already running VM, double-click `src/host/Open-WorkBoxConsole.cmd` and enter the absolute private configuration path (or set `WORKBOX_CONFIG` to that path beforehand). From a terminal use `Open-WorkBoxConsole.cmd <config-path> -CheckOnly` for preflight, then omit `-CheckOnly` to open it. This inline preflight does not require PS1 execution-policy permission, changes no policy and does not start/reboot Windows. The official VMConnect process is launched maximized; a visible diagnostic window and private `console-launch.log` preserve failure information. Keep the diagnostic window until the console appears. Exit zero alone is not desktop acceptance. Background agents must not auto-open this visible entry.

Install a supported [official Node.js LTS](https://nodejs.org/en/download) inside the guest and on the host. This candidate pins the exact historical Playwright package in `src/browser/package.json`; both ends must match. The npm registry package's existence was checked, but a fresh download/start on another machine remains a trial item. No fallback silently upgrades the version. If your policy disallows prereleases, agree and validate a stable-version migration before deployment.

Supply actual guest and host NAT-side IPv4 addresses. Do not pass public address ranges or disable the firewall. Install/download operations require network access; download sizes vary. Put large dependency caches on your selected data/cache drive, not inside this source repository.

```powershell
./src/host/Install-WorkBoxBrowser.ps1 -ConfigPath $cfg -GuestNodePath 'D:/Node/node.exe' -GuestNpmPath 'D:/Node/npm.cmd' -GuestCacheDirectory 'D:/WorkBoxCache' -GuestIPv4 '<guest-ipv4>' -HostIPv4 '<host-nat-ipv4>' -WhatIf
# Review the plan, then repeat without -WhatIf.
# Host client dependencies (only when optional browser use is wanted):
$env:npm_config_cache='F:/WorkBoxCache/npm'
$env:PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD='1'
Push-Location ./src/browser
npm ci --ignore-scripts --no-audit --no-fund
if($LASTEXITCODE -ne 0){throw 'npm ci failed'}
Pop-Location
./examples/browser.ps1 -ConfigPath $cfg -NodePath 'D:/Node/node.exe' -EvidenceDirectory 'E:/WorkBoxTrial/browser-01'
```

The Node path in the final command is the host's path. The guest installer obtains Chromium from Playwright's official download mechanism and restricts the inbound rule to one host address. Inspect existing broader firewall rules before network use; this package cannot prove unrelated rules are safe. Guest/host IP changes require administrator review and updating the existing exact rule/config; no automatic widening is included.

## Upgrade and removal

Keep private evidence outside the checkout. Do not rerun installation over a live worker. Finish pending requests, hold the shared lease, then use Task Scheduler/PowerShell Direct to stop only the named WorkBox task you own. Back up private state locally. Review the new source hashes and reinstall into a new dedicated guest directory with new task names after retiring the old tasks. Remove only this installation's two scheduled tasks and the exact `WorkBox Browser Host Only` firewall rule when retiring it. Never delete a VM or another project's data as cleanup. This candidate intentionally has no destructive auto-uninstaller or migration helper.

The console entry records a newly started VMConnect PID with matching parent, creation time and configured VM GUID. An early process exit or missing process produces a visible failure. A live PID still does not prove desktop visibility; inspect the actual window. If startup observation times out, inspect the original attempt before retrying.
