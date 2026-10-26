# Troubleshooting

| Symptom | Check and bounded next action |
| --- | --- |
| PowerShell script blocked | Follow normal policy/signing and review downloaded files; do not weaken machine policy automatically. |
| PowerShell Direct cannot connect | Check exact VM ID/name/running state, host Hyper-V rights and guest administrator credentials. Do not rebuild/restart to guess. |
| No `ready.json` / stale identity | Check ordinary guest session, scheduled task last result, source hash and whether a prior worker is alive. A scheduled-task start return is not readiness. |
| Install says root/task exists | Stop. Review the existing deployment; the installer intentionally does not overwrite it. Partial install requires specific cleanup of its own files/task by an administrator before retry. |
| Lease busy | Wait at most the configured bound; stop this attempt. Never kill the owner or delete the lock. |
| Request timeout / pending | Retrieve the original ID. Do not resend input. Confirm worker and original result before another action. |
| Native click refused | Re-observe and inspect the current guest screenshot. Check foreground, exact target identity, occlusion and bounds. Do not widen the allowlist to make a permission dialog clickable. |
| Browser will not launch | Check exact Node/Playwright version, ordinary interactive session, custom browser cache and scheduled-task result. The server sets cache environment before loading Playwright. |
| Browser connection failed after NAT change | Inspect actual host/guest IPs, listener owner and narrow firewall rule. Update exact configuration/rule under administrator authority; never allow all remote IPs. |
| Right/bottom edge clipped | Compare guest screen size, window outer size and page inner size. Use a new context with `viewport: null`; observe/resize/maximize within the actual guest display and check fresh desktop evidence. Larger emulated viewport is not a display repair. |
| Evaluation VM shuts down hourly | Check Windows evaluation activation/expiry against Microsoft terms; acquire a properly licensed installation. No expiry bypass. |

Do not publish raw browser errors, command lines, URLs with capability paths, screenshots, cookies or logs with user content. Keep a minimal local diagnostic with timestamps and pass/fail identities. If one route fails, preserve the task goal and assess command/API, headless and isolated desktop alternatives under the same authorization; a permission denial is not bypass permission.
