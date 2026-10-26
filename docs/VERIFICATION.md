# Verification and limitations / 验证与限制

This candidate is not an independently proven cross-machine installer. Local source parsing, dependency lock resolution, privacy export, fixture tests and deterministic archive checks are recorded separately from live guest/UI tests. Consult the accompanying private handoff for the exact archive SHA and test reports; do not ship operator-specific raw evidence in this repository.

本候选尚未经独立新机安装验收。源码解析、锁文件解析、隐私导出、fixture 与可复现归档检查和真实来宾/UI 测试分开记录。精确归档 SHA 与报告见私有交接，不把操作者原始证据混入仓库。

The original same-machine implementation had bounded native/browser evidence; the frozen session helper has separate same-machine evidence for window fitting and scoped state restore. Portable path/config changes require their own trial. A modified installer cannot inherit the original machine's acceptance. New browser examples and installers have not been exercised on a fresh Windows guest by this packaging task.

原本机实现有有界原生/浏览器证据，冻结会话 helper 有本机窗口适配和 scoped state 恢复证据。便携路径/配置改造仍需单独试用；新安装器不继承原机器验收。本打包任务没有在全新 Windows 来宾执行新安装/浏览器示例。

Required trial before promotion: exact VM binding and non-admin installation; current screenshot/identity; Unicode Notepad input and saved content; rejected wrong session/target; original-ID timeout recovery; full-task lease exclusion; browser own-context cleanup; fresh guest display edges; scope isolation for same/different project/user/site; absence of unintended host input. Test failure is not an invitation to widen access.

晋升前必试：精确 VM 绑定与普通用户安装、新截图/身份、记事本 Unicode 输入与落盘、错误 session/目标拒绝、原 ID 超时恢复、整任务租约互斥、browser 自有 context 清理、实际来宾显示边界、相同/不同项目用户站点 scope 隔离、宿主无误输入。失败不能作为放宽权限理由。

Known limits: Windows Hyper-V only; real interactive guest sign-in required; no automatic VM provisioning/reboot/OOBE; no generic native-app support; no guaranteed captcha/authentication bypass; no cross-user/machine portability of DPAPI state; no distributed lock; no production SLA; no automatic NAT adaptation; no automated destructive uninstall or in-place upgrade. Native security-window checks are a conservative heuristic, not an OS security boundary. Browser contexts and origin-filtered state are not permission sandboxes. Scoped cookie domains may include parent-domain cookies; review each scope before saving.

The original repaired CMD entry was observed opening the existing guest session with the complete desktop/taskbar and no Windows credential prompt. That observation covers one existing session only. The parameterized package's `Open-WorkBoxConsole.cmd` keeps the official CMD `start /max /wait` route, explicit VM binding and visible failure diagnostics; its portable entry has not itself been opened on another host. Basic/enhanced-mode distinctions, cold boot, logout and every host/display size remain unverified. Use `<config-path> -CheckOnly` to check prerequisites without opening a window; an agent must not auto-invoke the visible entry.

原修复 CMD 入口已亲见打开既有来宾会话，完整桌面/任务栏且无 Windows 凭据框；证据仅覆盖这一次已有会话。便携 `Open-WorkBoxConsole.cmd` 保留官方 CMD `start /max /wait`、明确 VM 绑定和可见失败诊断，但尚未在其他宿主真实打开。基本/增强模式区分、冷启、注销和全部显示尺寸仍未验。`<配置路径> -CheckOnly` 只核前提；代理不能自动调用可见入口。

已知限制：仅 Windows Hyper-V；需真实交互登录；不自动建 VM/重启/过 OOBE；不支持任意原生 App；不绕认证；DPAPI state 不跨用户/机器；无分布式锁/生产 SLA/自动 NAT 适配/破坏性卸载或原地升级。安全窗口检查属保守规则，不是 OS 安全边界；context 与 origin 过滤不是权限沙箱；父域 cookie 可能覆盖子域，保存前审 scope。

The portable console PID/early-exit check is implemented but has not been used to open the real VM in this packaging task; inline parsing, preflight rejection and synthetic process-lifecycle cases were executed. 便携控制台 PID/快速退出检查已实现，本打包任务未实开 VM，已执行内联解析、预检拒绝与合成进程生命周期用例。
