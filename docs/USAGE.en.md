# Use and trial acceptance

Use the background command/API route first; use the VM only when a real desktop is needed. Every operator of one VM must coordinate through its same `leaseFile`. The lease is cooperation, not a security boundary or a scheduler.

Run `examples/observe.ps1` first. Open the fresh PNG and JSON yourself: an action's `completed` status proves only transport/action completion. Check target content and visible bounds. A Notepad task can be tested with non-private text such as `WorkBox trial 42`, then compare a new image and the resulting saved file. Do not infer another app is supported from that test.

For a multi-step task, save a synchronous PowerShell script and invoke it once through `Invoke-WithWorkBoxLease.ps1 -ProjectName ... -LeaseFile <configured-path> -ScriptPath <absolute-task-path> -ArgumentList @(...) -WaitSeconds 30`. Keep the lease through observation, all actions, result verification and cleanup of only your own browser context. Do not nest the same lease or launch un-awaited background work. Check external-program exit codes and throw on failure. A leftover lease file does not prove a lock is held; never delete/steal a live lease.

Each desktop request is UTF-8 JSON:

```json
{"id":"trial-unique-id","session":1,"action":"observe"}
```

`session` must come from `Get-WorkBoxState`; the sample above is a shape example, not a usable captured identity. Generate a new ID for every new action. For actions on a window, use `hwnd`, `pid` and `session` from the immediately preceding observed result, after actually viewing its image. `activate` may include an observed `x`,`y` point relative to that window. `click` requires `x`,`y`; `type` requires `text` (maximum 4096 UTF-16 characters); `key` uses `key` and optional `ctrl`/`alt` booleans. Keys: ENTER, ESC, TAB, SPACE, LEFT, UP, RIGHT, DOWN, HOME, END, A, S, O, F4. `close` sends Alt+F4 only to the verified foreground target. `stop` stops the worker and is not a normal task-completion action.

Only Notepad and Calculator process names are allowed by default. Arbitrary application/window hosting is not supported. Input is rejected for secure/permission/locked desktop processes. This does not recognize every third-party permission dialog; review the screen and do not use the toolkit to bypass authorization.

When an action times out, **do not send the action again with a new ID**. Use `Get-WorkBoxResult.ps1 -ConfigPath ... -RequestId <original-id> -OutputDirectory <new-private-directory>`; inspect pending/claimed/result and the actual guest. Releasing the host lease does not cancel guest work. Stale requests are archived on worker startup and not replayed. Resolve uncertainty before the next action.

The browser sample creates only a new context, visits the public example page, captures a local screenshot, closes that context and disconnects its client. It never enumerates existing pages or loads storage state. It uses `viewport: null`, but the caller must still verify the actual guest desktop, window bounds, browser chrome and dialog visibility before native clicks. A page screenshot alone does not prove desktop edges are visible. If a task needs a browser login, authenticate in that task's context through normal authorized steps; no account transfer or login bypass is included.

Trial report: record package SHA, host/guest OS, configured capabilities (not credentials), each command's outcome, the fresh redacted evidence, unexpected behavior and whether another project could acquire the shared lease afterward. Keep raw screenshots, endpoint files and request text private. Send only a sanitized summary to the maintainer. A successful trial must separately cover setup, observation, Notepad Unicode input/save, denied targets, timeout lookup, browser context isolation and display edges.

## Optional scoped login-state reuse

After the host connection is freshly verified, use the frozen helper inside a task already holding the shared lease:

```javascript
const {openSession}=require('./src/browser/WorkBox-BrowserSession.cjs');
const session=await openSession({
  configPath:process.env.WORKBOX_CONFIG,
  pwshPath:process.env.WORKBOX_PWSH,
  scope:{project:'my-project',user:'my-user',origins:['https://example.com']},
  restore:true
});
try {
  const page=await session.newPage();
  await page.goto('https://example.com');
  // Complete only normal authorized authentication in this own context, if needed.
  await session.settle(); // Own new windows/popups are fitted to the actual guest display.
  await session.save();   // Explicit opt-in; encrypted private storage, never an artifact to share.
} finally {await session.close()}
```

Set both environment variables to your own absolute local paths; `WORKBOX_CONFIG` points to the host config and `WORKBOX_PWSH` to PowerShell 7. Changing project/user/origins yields a separate state key; anonymous sessions never borrow saved state. Missing state simply opens a fresh context. Cookie parent domains can span allowed subdomains, so do not mix unrelated accounts in a scope. DPAPI binds the state to this host user; it is not an exportable account or a guarantee that all sites avoid re-login. Only explicitly authorized state is saved. To forget a scope, close its session and delete its specific encrypted file in the private state directory after confirming the scope key; do not bulk-delete another project's state.
