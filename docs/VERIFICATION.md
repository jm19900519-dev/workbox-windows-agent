# Verification and limitations / 验证与限制

Version criteria and host/guest, desktop/browser distinctions are in the [English compatibility matrix](COMPATIBILITY.en.md) / [中文兼容性矩阵](COMPATIBILITY.zh-CN.md). A capability preflight or synthetic version fixture establishes its checked conditions and decision logic, not real deployment on every listed Windows release. 版本预检或合成矩阵用例只证明已检查条件与判断逻辑，不是各Windows版本真实部署验收。

The 2026-10-26 read-only preflight freshly checked the existing guest: EnterpriseEval build 26300 x64, Windows PowerShell 5.1, and an enabled non-administrator target account with an interactive session. Its effective execution policy was `Restricted`, blocking the portable fresh-install path. This is not evidence that the existing worker failed. No new guest installation was performed. The host baseline is Windows 11 Pro build 26100 x64 / PowerShell 7.6.5; these remain one-machine observations.

2026-10-26 的只读预检已重新核现有来宾：EnterpriseEval build 26300 x64、Windows PowerShell 5.1，目标账户启用、非管理员且有交互会话。其有效执行策略为 `Restricted`，便携新安装路径因此阻断；不能据此认定现存 worker 失效，也未执行新来宾安装。宿主基线为 Windows 11 Pro build 26100 x64 / PowerShell 7.6.5，仍只是本机观察。

The compatibility increment passed 40 injected version/condition fixtures plus two error-branch regressions, and seven independent fixtures exercised the actual installers' pre-write blocking and session-cleanup control flow without installing a guest. Affected PowerShell parsing, CLI exit boundaries, UTF-8 DPAPI behavior and native/WOW64 console `-CheckOnly` paths were checked. The 11 changed/new runtime files matched the independently reviewed hash manifest. These are decision, control-flow and local prerequisite checks, not new Windows-image deployment or UI tests.

兼容性增量已通过40项注入版本/条件用例、2项错误分支回归，以及7项独立用例对实际安装器写入前阻断和会话清理控制流的检查，未安装来宾。受影响的PowerShell解析、CLI退出边界、UTF-8 DPAPI和原生/WOW64控制台 `-CheckOnly` 路径已验；11项改动/新增运行文件与独审核定哈希一致。这些证据只覆盖判断、控制流和本机前提，不是新Windows镜像部署或UI实测。

The guest's checked Node was version 22 on x64. The supplied npm path was absent, and a bounded check of four standard entries beside that known Node executable also found none. This blocks the supplied browser-install inputs; it is not a full guest inventory and does not prove that npm must be newly installed. Existing services were not changed. Host browser preflight covers OS prerequisites only; guest browser preflight covers installation prerequisites only, and `readiness` remains `not-assessed`.

本次来宾已核Node为22/x64；指定npm路径不存在，另对已知Node父目录的4个标准入口做了有界检查，未发现。它阻断的是本次浏览器安装输入，不是全来宾软件盘点，不能推出必须新装npm；现有服务未改。宿主浏览器预检仅核OS前提，来宾仅核安装前提，`readiness` 仍是 `not-assessed`。

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
