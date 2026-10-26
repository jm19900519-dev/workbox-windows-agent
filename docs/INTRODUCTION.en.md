# Introducing WorkBox

[中文](INTRODUCTION.zh-CN.md) · [Project home](../README.md)

WorkBox is presented as the **v0.1.0-preview.1 open-source preview** for inspection, learning and bounded trials. It is not a stable release and has not completed cross-machine acceptance. [View the source](https://github.com/jm19900519-dev/workbox-windows-agent) · [Downloads and releases](https://github.com/jm19900519-dev/workbox-windows-agent/releases)

## One sentence

WorkBox gives your AI a Windows desktop of its own: run supported desktop and web actions in a local Hyper-V VM and inspect the results. Currently an open-source preview.

## Short paragraph

When an agent needs a real desktop, its experiments do not have to operate directly on your everyday workspace. WorkBox is a local Windows Hyper-V desktop automation toolkit that lets your own agent or scripts observe the screen, operate supported windows, use a visible browser and retrieve screenshots and receipts. A shared lease lets cooperating tasks take turns; optional encrypted state, scoped by project, user and sites, supports later work within that same scope. WorkBox is an open-source preview, with cross-machine installation and production website login still to be verified.

## Announcement copy

### Give your AI a Windows desktop of its own

Some automation tasks need real windows: enter text, handle a web popup, then inspect what actually happened. WorkBox puts those tasks inside a local Windows Hyper-V virtual machine and gives your own agent or scripts a set of desktop execution tools. It is not an AI model or a hosted service. You choose the model and define what the task is allowed to do.

On the normal background execution route, actions stay on the guest desktop, reducing contention with everyday work on the host. Cooperating tasks sharing that desktop use one lease to take turns through an entire task. Native desktop requests have receipts; after a timeout, the caller checks the original result instead of blindly repeating input. Start with a screenshot, try Notepad or Calculator, or use the optional visible browser to check pages and forms.

The browser session helper lets page viewports follow their windows and fits its own new windows and popups. For later tasks within the same scope, you can explicitly save encrypted state for a project, user and set of HTTPS origins. Anonymous sessions remain the default. Saved state does not promise permanent login: website authentication and session expiry still apply.

WorkBox is currently an open-source preview. The original local implementation has evidence for selected desktop, web, display-fitting and synthetic state-isolation scenarios; the portable candidate passed independent review. Installation on a new machine, production website login and cold-boot scenarios still need real trials. Opening the source does not change those evidence boundaries. It is intended for developers and technical teams willing to configure a local Windows VM and evaluate desktop automation.

The target environment is Windows Hyper-V. The [compatibility matrix](COMPATIBILITY.en.md) distinguishes host, guest and desktop/browser paths. Existing runtime evidence comes from the original local machine, not every Windows version.

Follow the [installation guide](INSTALL.en.md), then run the [observation example](../examples/observe.ps1) to capture your first guest screenshot. Consult the [usage guide](USAGE.en.md), [verification notes](VERIFICATION.md) and [security guidance](../SECURITY.md) for capabilities and boundaries.
