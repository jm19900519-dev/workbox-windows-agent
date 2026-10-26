# WorkBox — isolated Windows desktop toolkit

[中文说明](README.zh-CN.md) · [Install](docs/INSTALL.en.md) · [Usage](docs/USAGE.en.md) · [Troubleshooting](docs/TROUBLESHOOTING.en.md) · [Security](SECURITY.md)

WorkBox runs bounded desktop actions inside your own local Hyper-V Windows VM, without moving the host mouse or taking host keyboard focus. A PowerShell Direct queue connects the host to a non-administrator interactive guest worker. A shared file lease serializes whole tasks. An optional Playwright bridge provides a fresh browser context for each task.

This is a **source candidate for private trial**, not a VM image or a verified one-command installation on arbitrary PCs. The portable installer and configuration adapter are new. Historical operation of the original machine does not prove this package works on your machine. See [verification and limits](docs/VERIFICATION.md).

Included capabilities:

- Observe guest desktop; activate, click, type Unicode text, send a bounded key set and close Notepad/Calculator windows.
- Validate VM ID/name, guest name, ordinary worker owner/session, source hash, process creation and boot identity.
- Reject reused request IDs; retrieve the original result after timeout rather than replaying input.
- Optional headed Chromium server with explicit guest bind IP, one host IPv4 firewall scope, local capability generation and private endpoint files.
- Fresh browser contexts with `viewport: null`; view real guest screen evidence before native input. Window cropping is not solved by enlarging an emulated viewport.
- Opt-in login-state reuse scoped to an explicit project, user and exact HTTPS origins, encrypted with Windows DPAPI for the same host user. Anonymous contexts remain the default; real site/session expiry still applies.

Start with [the installation guide](docs/INSTALL.en.md), then run the observation sample under PowerShell 7. All machine IDs, accounts, state paths, guest paths and ports are supplied by the installer/configuration; no original operator configuration is shipped.

Repository layout: `src/host` contains installation and transport; `src/guest` contains the desktop worker; `src/browser` contains the optional server/client; `examples` contains leased tasks; `tools` contains import, validation and allowlisted export. No Windows ISO/VHD, browser binaries, Node runtime, private credentials or historical screenshots are included.

The Windows evaluation is time-limited and licensed separately. Dependencies must be obtained from their official distributors. [Licensing and provenance](docs/LICENSING.md) records the source-review/public-release gate.
