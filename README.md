# WorkBox · Give your AI a Windows desktop of its own

[中文](README.zh-CN.md) · [Installation](docs/INSTALL.en.md) · [Windows compatibility](docs/COMPATIBILITY.en.md) · [Usage](docs/USAGE.en.md) · [Product introduction](docs/INTRODUCTION.en.md)

Run desktop automation in a local virtual machine, and keep your everyday desktop for your own work.

WorkBox is a desktop automation toolkit for a **local Windows Hyper-V virtual machine**. It gives your agent or scripts entry points to observe the screen, operate supported windows, use a visible browser and retrieve results—so tasks that need a real Windows desktop can run in a separate workspace.

WorkBox supplies the desktop execution tools. It is not an AI model or a hosted platform. You choose and connect your own agent or scripts, define the permitted task, and direct execution to the configured VM.

**[Prepare your environment and capture your first guest screenshot →](docs/INSTALL.en.md)**

## Where it helps

- **Developing agents and automation scripts:** try observation, input and result retrieval on a dedicated Windows desktop before letting an experiment operate your everyday workspace.
- **Checking web interactions:** open pages, fill test forms and inspect windows or popups in the guest's visible browser, then save evidence locally.
- **Resuming work with scoped browser state:** explicitly choose a project, user and sites, then opt into encrypted state storage so a later task with the same scope can try to resume that state.

Native window support defaults to Notepad and Calculator. Other applications need separate integration and verification. Prefer commands or APIs when they can complete the task.

## What makes it useful

| Capability | Practical benefit |
| --- | --- |
| Actions target the guest desktop | The normal background execution route keeps mouse and keyboard actions inside the VM, reducing contention with host work. Opening the console yourself remains a visible interaction. |
| One shared lease for a whole task | Cooperating callers take turns on the same VM, helping prevent two tasks from clicking the same desktop at once. |
| Native desktop actions use requests and receipts | Inspect a fresh screenshot and result. After a timeout, look up the original request instead of guessing and repeating input. |
| Page viewports follow their windows | The session helper fits its own new windows and popups, rather than hiding display boundaries behind a fixed page size. |
| Explicit, scoped state storage | Encrypt state locally for a specific project, user and set of HTTPS origins, reducing repeated setup where that state can be reused. Fresh anonymous sessions remain the default. |

## From setup to a checked result

1. **Prepare a dedicated desktop:** follow the installation guide to configure a licensed Windows VM, an ordinary guest user and local paths.
2. **Run a bounded task:** use an example or connect your own script. Hold the VM's shared lease for the entire task.
3. **Inspect the outcome:** check the fresh screen and actual output, close your own browser session, then release the lease.

After installation, run this from the repository root in PowerShell 7 to capture your first guest screenshot:

```powershell
./examples/observe.ps1 -ConfigPath '<absolute-path-to-your-private-config>' -EvidenceDirectory '<absolute-path-for-this-task-evidence>'
```

Then try the [visible browser example](examples/browser.ps1), or follow the [usage guide](docs/USAGE.en.md) for Notepad input, timeout recovery and scoped state storage. Configure the optional browser dependencies first.

## Current stage and evidence

**WorkBox is in a prerelease, private-trial stage.** The original local implementation has evidence for selected desktop/web actions, window and popup fitting, synthetic cookie/localStorage restoration within a scope, and isolation across projects/users. Its original console entry was also observed opening one existing guest session with a complete desktop. The portable candidate passed source checks, bounded local tests, privacy scanning, archive consistency checks and independent review.

That does not establish acceptance on another machine. Cross-machine installation, real window opening through the portable entry, production website login, cold boot and login after logout remain unverified. Read-only preflight and synthetic version-matrix tests do not replace that acceptance. Websites can expire sessions; saved state neither guarantees persistent login nor bypasses authentication.

The target environment is Windows Hyper-V. The [compatibility matrix](docs/COMPATIBILITY.en.md) separates host, guest, desktop and optional browser conditions. Windows 10 remains a conditional desktop candidate; do not exclude that path by applying the browser's Windows 11+ baseline to it. Runtime evidence comes from the original local machine, not every Windows version.

Read the full [verification and limits](docs/VERIFICATION.md), [security notes](SECURITY.md) and [troubleshooting guide](docs/TROUBLESHOOTING.en.md). A fresh browser context is not a permission sandbox, and network access remains subject to the task's authorization.

## Source and licensing

`src/host` contains host installation and invocation tools, `src/guest` the desktop worker, and `src/browser` the optional browser and session tools. `examples` provides tasks; `tools` provides checks and allowlisted export.

Under the authorization to open-source the project, the maintainer selected [MIT](LICENSE) for its own source and documentation. Obtain Windows, Node.js, Playwright and browser dependencies separately under their own licenses. This repository includes no OS images, virtual disks, runtime binaries, real credentials or private screenshots. See [NOTICE](NOTICE.md) and [licensing details](docs/LICENSING.md).
