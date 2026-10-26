# Windows compatibility and evidence boundaries

[中文](COMPATIBILITY.zh-CN.md) · [Installation](INSTALL.en.md) · [Usage](USAGE.en.md) · [Troubleshooting](TROUBLESHOOTING.en.md)

WorkBox has separate **host tools, a guest desktop worker and an optional browser path**. An environment may qualify as a desktop candidate without qualifying for the browser path. A Hyper-V host edition restriction must not automatically be applied to a guest. The following defines this candidate's scope, not a claim that every listed system has been tested.

## Reading the status

- **Limited local evidence:** particular scenarios were observed on a particular machine; the evidence covers only those scenarios.
- **Conditional candidate / untested:** within the version baseline, subject to components, permissions, user session, policy and actual runtime checks.
- **Unsupported:** outside this candidate's implementation or dependency scope. Do not force it through by changing policy, silently downgrading dependencies or weakening safety checks.

A preflight `pass` establishes only that individual condition. `block` means a known condition is unmet; `unknown` means evidence is insufficient. Do not treat `unknown` as success: pause the installation or runtime step that depends on it until real evidence is available. Passing preflight still does not replace fresh screenshots, task outputs and end-to-end acceptance.

## Running the actual preflight

Run from the repository root in native 64-bit PowerShell 7. Host-only checks do not contact the guest:

```powershell
pwsh -NoProfile -File ./src/host/Test-WorkBoxCompatibility.ps1
pwsh -NoProfile -File ./src/host/Test-WorkBoxCompatibility.ps1 -Browser
```

Once a private configuration exists, hold the VM's original shared lease for the entire guest check. This example does not start, install or reboot the VM:

```powershell
$cfg='<absolute-path-to-private-config>'
$c=Get-Content -LiteralPath $cfg -Raw -Encoding UTF8 | ConvertFrom-Json
$shell=(Get-Process -Id $PID).Path
$entry=(Resolve-Path ./src/host/Test-WorkBoxCompatibility.ps1).Path
./src/host/Invoke-WithWorkBoxLease.ps1 -ProjectName 'compatibility-check' -LeaseFile $c.leaseFile -WaitSeconds 30 -ScriptBlock {
    param($shell,$entry,$cfg)
    & $shell -NoProfile -NonInteractive -File $entry -ConfigPath $cfg -IncludeGuest
    if($LASTEXITCODE -ne 0){throw 'Preflight did not pass; inspect the preceding JSON and do not install.'}
} -ArgumentList @($shell,$entry,$cfg)
```

For guest browser installation prerequisites, append these actual parameters to the `$shell` command inside that lease: `-Browser -GuestNodePath '<absolute-guest-node.exe-path>' -GuestNpmPath '<absolute-guest-npm.cmd-path>'`. Do not substitute host paths for guest paths. The CLI does not acquire the lease automatically.

| Output | Meaning |
| --- | --- |
| Top-level `status` | `pass` / `block` / `unknown`, with CLI exit codes 0 / 2 / 3 respectively. Read/parse and other execution errors return other nonzero failures |
| `desktopStatus` in `host` / `guest` | That role's desktop prerequisites; `guestProbe` says whether guest facts were obtained |
| `browserRequested` / `browserStatus` | Without `-Browser`, browser status is `null`, not a pass |
| `browserScope` | Host checks cover browser OS prerequisites only: **host Node and client package are not checked**. Guest checks cover installation prerequisites only: **installed Playwright identity and browser readiness are not checked** |
| `readiness` | Always `not-assessed`; an overall `pass` does not mean a service is ready |
| `checks` | Per-item `id`, `component`, `status` and `reason` identify unmet or unproven conditions |

Installers use the same decision gate to reject `block` and `unknown` before file writes, downloads or task registration. `-WhatIf` shows an installation plan and can return before guest fact collection; it does not replace the read-only CLI. Save preflight JSON only in private evidence storage, not a public repository containing machine, path or user facts.

## Host matrix

All host candidates require **x64 Windows, a native 64-bit calling process, working Hyper-V and PowerShell Direct, and appropriate host administrator rights**. Use **PowerShell 7 for the host scripts**. Guest requirements are separate.

The explicitly invoked console CMD bootstrap uses system Windows PowerShell 5.1 for inline preflight. That is a separate console-entry implementation, not a replacement for the PowerShell 7 requirement of the host PS1 tools.

| Host environment | Desktop path | Optional browser client | Evidence status |
| --- | --- | --- | --- |
| Windows 11 Pro / Enterprise, build 22000+ | Conditional candidate | Conditional candidate; Node/Playwright conditions also apply | Current host: Pro build 26100 x64, PowerShell 7.6.5. Limited evidence from this machine only |
| Windows 11 Education, build 22000+ | Decide from actual Hyper-V/PSDirect capability, not the edition name alone | Conditional candidate | Not tested across versions |
| Windows 10 Pro / Enterprise / Education with the required capabilities, 1607 / build 14393+ | Conditional candidate | This candidate does not support this browser path | Not tested across versions; the desktop path is not excluded merely because the browser path is unsupported |
| Windows Home as host | Unsupported: lacks the official Hyper-V host feature required here | No separate WorkBox route that bypasses the host requirements | This does not exclude Home guests |
| Windows Server 2016+ with Desktop Experience | Conditional candidate | Server 2019+ is a conditional browser candidate; 2016 is unsupported for this browser path | Server environments untested |
| Server Core, older versions, x86, ARM64 or non-Windows systems | Unsupported for this candidate's desktop workflow | Outside this candidate's browser combinations | A WorkBox scope limit, not a claim about what platforms could ever implement |

The actual preflight and host PowerShell process must be native 64-bit. A 32-bit parent process does not disqualify the whole x64 machine: if an entry transfers execution to a native 64-bit process before checking, assess the resulting capabilities. Do not run host tools directly in an unconverted WOW64 PowerShell process.

Hyper-V needs hardware virtualization, SLAT and adequate resources. Having management cmdlets installed does not prove the virtualization role is usable. [Microsoft host requirements](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/host-hardware-requirements)

## Guest matrix

The guest needs **x64 Windows with an interactive desktop**, **Windows PowerShell 5.1, WinForms/System.Drawing, LocalAccounts, ScheduledTasks and the other required components**, plus a configured ordinary user's interactive session. Installing PowerShell 7 on the host does not install or establish these guest capabilities.

| Guest environment | Desktop worker | Optional headed browser | Evidence status |
| --- | --- | --- | --- |
| Windows 11, build 22000+, including Home when guest conditions are met | Conditional candidate | Conditional candidate | This round's read-only check observed EnterpriseEval build 26300 x64 / WinPS 5.1. The ordinary user's Restricted policy blocks portable fresh installation; not all workflows passed |
| Windows 10 1607 / build 14393+, including Home when guest conditions are met | Conditional candidate | This candidate does not support this browser path | Not tested across versions |
| Windows Server 2016+ with Desktop Experience | Conditional candidate | Server 2019+ conditional candidate; 2016 unsupported for this browser path | Untested |
| Server Core, no interactive desktop, older versions, x86 or ARM64 | Unsupported by this candidate | Outside this candidate's combinations | Do not weaken target checks to substitute for missing desktop capabilities |

Home cannot serve as this toolkit's Hyper-V **host**; that does not prevent it from being a **guest** in an existing, properly licensed Hyper-V VM. It must still meet every PSDirect, component, ordinary-user, session and policy condition.

Microsoft's PSDirect baseline is Windows 10 / Server 2016 or later on host and guest; persistent sessions require build 14280+. WorkBox uses persistent PSDirect, file transfer and guest WinPS 5.1, so its Windows 10 candidate baseline is 1607 / build 14393+. This is a project baseline, not a claim that the official minimum equals package acceptance. [Microsoft PSDirect documentation](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/powershell-direct)

## The browser has additional version requirements

At review time, Playwright's current official requirements list Windows 11+ / Windows Server 2019+ and Node.js 22, 24 or 26. [Official system requirements](https://playwright.dev/docs/intro#system-requirements) These constrain the optional browser candidates; they do not raise the desktop-only baseline in the tables.

This package still pins `1.63.0-alpha-2026-08-31` in `src/browser/package.json`. **This batch does not upgrade that dependency.** The current upstream support list is not proof that this historical alpha works in every listed combination. Both ends must use the same exact version; check Node version/architecture, the actual browser cache and launch outcome. Prefer a still-supported Node LTS. If the prerelease is unavailable or disallowed by policy, handle migration and acceptance separately rather than silently changing the lockfile.

The current guest preflight checks Node major version and architecture, not whether the latest security patch of that line is installed or whether the pinned Playwright actually launches. Host Node/client checks remain separate.

## Policy and the ordinary user's session

The worker runs as an ordinary guest user through an interactive scheduled task. Successful commands in an administrator's PSDirect session **do not establish the target ordinary user's effective execution policy, language mode or interactive session**. `Restricted`, `AllSigned`, organization policy and file signature/origin restrictions can allow task registration while preventing script execution.

The toolkit does not automatically change execution policy, add a bypass, sign a user in or reboot the guest. Keep an unobserved target-user policy as `unknown` and obtain evidence in that user's actual context and task result. An administrator context or an unverified assertion is not a substitute. Recheck affected conditions after system/version changes.

## Existing evidence and the next trial

Evidence comes from one local setup: Windows 11 Pro build 26100 x64 with PowerShell 7.6.5 on the host. This round's read-only preflight freshly observed an EnterpriseEval build 26300 x64 guest with Windows PowerShell 5.1, and an existing, enabled, non-administrator target account with an interactive session. That user's effective policy is `Restricted`, so portable fresh installation must be blocked. This does not establish failure of the existing worker or success of a new installation.

Existing evidence for selected desktop/web actions, window fitting, synthetic browser-state isolation and one entry into an existing guest session remains separate. Read-only preflight did not perform a new installation or deployment/regression runs across all Windows releases. The checked Node was 22/x64, but the supplied npm path was absent; a bounded check of four standard entries beside that known Node executable also found none. This is a path check, not proof that npm is absent from the entire guest or must immediately be installed.

On a new machine, check the host, guest and selected path separately. Then verify ordinary-user observation, Unicode input/file outputs, wrong-target rejection, original-ID timeout lookup and task cleanup. The browser additionally needs display, version matching and same/different-scope state checks. Vendor servicing status and valid software licensing remain separate requirements. See [verification notes](VERIFICATION.md) and [security guidance](../SECURITY.md).

Official sources checked: 2026-10-26. These commands match this batch's actual CLI. Interpret the individual check scope rather than turning one aggregate status into a claim that every capability is verified.
