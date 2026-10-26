# Windows 兼容性与验证边界

[English](COMPATIBILITY.en.md) · [安装](INSTALL.zh-CN.md) · [使用](USAGE.zh-CN.md) · [排障](TROUBLESHOOTING.zh-CN.md)

WorkBox 分为**宿主调用工具、来宾桌面 worker、可选浏览器通道**。一个环境可以满足桌面候选条件，却不满足浏览器条件；宿主的 Hyper-V 版本限制也不能直接套到来宾上。以下是本候选的范围和检查依据，不是“这些系统全部已实测”的承诺。

## 如何读状态

- **本机有限已验**：有特定环境和场景证据，只覆盖记录中的动作。
- **条件候选／待测**：在版本基线内，还必须满足组件、权限、用户会话、策略和实际运行检查。
- **不支持**：不在本候选的实现或依赖范围内，不通过自动改策略、降级依赖或放宽安全门来强行运行。

预检项的 `pass` 仅表示该项已满足；`block` 表示已知条件不满足；`unknown` 表示未取得足够证据。`unknown` 不能当作成功，对它依赖的安装或运行步骤应暂停，补足实际证据后再继续。预检通过仍不代替新截图、目标产物和真实流程验收。

## 实际预检入口

在仓库根目录用原生64位 PowerShell 7 执行。只查宿主时不访问来宾：

```powershell
pwsh -NoProfile -File ./src/host/Test-WorkBoxCompatibility.ps1
pwsh -NoProfile -File ./src/host/Test-WorkBoxCompatibility.ps1 -Browser
```

已有私有配置后，来宾检查须整段持有该 VM 原共享租约。以下示例不启动、安装或重启 VM：

```powershell
$cfg='<私有配置的绝对路径>'
$c=Get-Content -LiteralPath $cfg -Raw -Encoding UTF8 | ConvertFrom-Json
$shell=(Get-Process -Id $PID).Path
$entry=(Resolve-Path ./src/host/Test-WorkBoxCompatibility.ps1).Path
./src/host/Invoke-WithWorkBoxLease.ps1 -ProjectName 'compatibility-check' -LeaseFile $c.leaseFile -WaitSeconds 30 -ScriptBlock {
    param($shell,$entry,$cfg)
    & $shell -NoProfile -NonInteractive -File $entry -ConfigPath $cfg -IncludeGuest
    if($LASTEXITCODE -ne 0){throw '预检未通过；查看此前JSON，不执行安装。'}
} -ArgumentList @($shell,$entry,$cfg)
```

要检查来宾浏览器安装前提，在上述租约内的 `$shell` 命令后补实际参数：`-Browser -GuestNodePath '<来宾node.exe绝对路径>' -GuestNpmPath '<来宾npm.cmd绝对路径>'`。不要把宿主路径误当来宾路径。该CLI自身不自动取得租约。

| 输出 | 含义 |
| --- | --- |
| 顶层 `status` | `pass` / `block` / `unknown`，CLI退出码分别为0 / 2 / 3；读取、解析等执行错误为其他非零错误 |
| `host` / `guest` 的 `desktopStatus` | 该角色的桌面先决条件；`guestProbe` 说明是否成功取得来宾事实 |
| `browserRequested` / `browserStatus` | 未选 `-Browser` 时浏览器状态为 `null`，不是通过 |
| `browserScope` | 宿主仅核浏览器OS先决条件，**未核宿主Node或客户端包**；来宾仅核安装前提，**未核已安装Playwright身份或浏览器就绪** |
| `readiness` | 固定为 `not-assessed`，不能将整体 `pass` 读成服务已就绪 |
| `checks` | 分项 `id`、`component`、`status`、`reason`，用于定位具体阻断或缺证 |

安装器复用同一判断门，在写文件、下载或注册任务前拒绝 `block` 和 `unknown`。`-WhatIf` 只显示安装计划，可能在来宾事实采集前返回，不能替代上面的只读CLI。保存预检JSON时放私有证据目录，不将本机身份、路径或用户事实附进公开仓库。

## 宿主矩阵

所有候选宿主都要求 **x64 Windows、原生64位调用链、已可用的 Hyper-V 和 PowerShell Direct、适当宿主管理权限**。宿主脚本按 **PowerShell 7** 使用；来宾要求单列如下。

显式打开控制台的 CMD 引导器使用系统 Windows PowerShell 5.1 做内联预检，这是控制台入口的单独实现，不替代宿主 PS1 工具的 PowerShell 7 要求。

| 宿主环境 | 桌面通道 | 可选浏览器客户端 | 证据状态 |
| --- | --- | --- | --- |
| Windows 11 Pro / Enterprise，build 22000+ | 条件候选 | 条件候选，还须满足 Node/Playwright 条件 | 当前宿主为 Pro build 26100 x64、PowerShell 7.6.5；仅这一机器有有限实证 |
| Windows 11 Education，build 22000+ | 按实际 Hyper-V/PSDirect 能力判定，不只按版本名称排除 | 条件候选 | 未跨版本实测 |
| Windows 10 Pro / Enterprise / 具备相应能力的 Education，1607 / build 14393+ | 条件候选 | 当前候选不支持此浏览器路径 | 未跨版本实测；不能因此把桌面通道一并判为不支持 |
| Windows Home（作为宿主） | 不支持：缺少本工具所需的官方 Hyper-V 宿主功能 | 不提供独立绕过宿主条件的 WorkBox 路径 | 不是对 Home 来宾的排除 |
| Windows Server 2016+ Desktop Experience | 条件候选 | Server 2019+ 才进入浏览器条件候选；2016 不支持此浏览器路径 | 服务器环境未实测 |
| Server Core、低于上述基线、x86、ARM64或非 Windows | 本候选桌面流程不支持 | 不纳入本候选浏览器组合 | 这是 WorkBox 候选范围，不是断言平台永远不能实现 |

实际运行预检和宿主 PowerShell 必须为原生64位。32位父进程不是对整台 x64 机器的否定；若入口将调用转换到原生64位后再检查，可继续按实际能力判定，不能直接在未转换的 WOW64 PowerShell 中运行宿主工具。

Hyper-V 需要硬件虚拟化、SLAT及足够资源；是否安装了管理命令不等于虚拟化角色已可用。[微软宿主要求](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/host-hardware-requirements)

## 来宾矩阵

来宾需为 **x64、有交互桌面的 Windows**，提供 **Windows PowerShell 5.1、WinForms/System.Drawing、LocalAccounts、ScheduledTasks 等实际所需组件**，以及已配置的普通用户交互会话。宿主装了 PowerShell 7 不会替来宾安装或证明这些条件。

| 来宾环境 | 桌面 worker | 可选有界面浏览器 | 证据状态 |
| --- | --- | --- | --- |
| Windows 11，build 22000+，含满足来宾条件的 Home | 条件候选 | 条件候选 | 本轮只读核到 EnterpriseEval build 26300 x64 / WinPS 5.1；普通用户策略 Restricted 阻止便携新装，并非全部流程通过 |
| Windows 10 1607 / build 14393+，含满足来宾条件的 Home | 条件候选 | 当前候选不支持此浏览器路径 | 未跨版本实测 |
| Windows Server 2016+ Desktop Experience | 条件候选 | Server 2019+ 条件候选；2016 不支持此浏览器路径 | 未实测 |
| Server Core、没有交互桌面、旧版本、x86或ARM64 | 本候选不支持 | 不纳入本候选组合 | 不通过放宽目标检查来补齐桌面能力 |

Home 不能充当本工具的 Hyper-V **宿主**，不代表 Home 不能是已有合法 Hyper-V VM 的**来宾**。来宾仍须逐项满足 PSDirect、组件、普通用户、会话和策略要求。

微软给出的 PSDirect 起点是宿主与来宾 Windows 10 / Server 2016 或更新系统，持久会话要求 build 14280+。WorkBox 使用持久 PSDirect、文件传输和来宾 WinPS 5.1，将 Windows 10 候选起点收在 1607 / build 14393+；这是项目基线，不把官方最低版本等同于本包验收。[微软 PSDirect 文档](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/powershell-direct)

## 浏览器另有版本条件

核查时，Playwright 当前官方要求列出 Windows 11+ / Windows Server 2019+ 和 Node.js 22、24、26。[官方系统要求](https://playwright.dev/docs/intro#system-requirements) 这用于限定可选浏览器候选范围，不改变上表桌面通道的较低候选基线。

本包仍锁定 `src/browser/package.json` 中的 `1.63.0-alpha-2026-08-31`，**本批不升级该依赖**。当前官网支持范围不是这个历史 alpha 与所有系统组合已验的证明。两端须使用相同精确版本，核 Node 版本/架构、实际浏览器缓存和启动结果；优先选仍受支持的 Node LTS。预发布依赖不可用或不符组织政策时，另做迁移与验收，不静默改锁文件。

当前来宾预检核 Node 主版本与架构，不核该版本线是否已经装到最新安全补丁，也不证明所锁定 Playwright 的实际启动结果。宿主 Node/客户端还须另外检查。

## 策略与普通用户会话

worker 由普通来宾用户的交互计划任务运行。管理员 PSDirect 能执行命令，**不能证明目标普通用户的有效执行策略、语言模式或登录会话满足要求**。`Restricted`、`AllSigned`、组织策略、文件签名/来源限制可能使计划任务注册成功而脚本不能运行。

本工具不自动修改执行策略、不加策略绕过、不替用户登录、不重启来宾。目标用户策略无法确认时保留 `unknown`，通过该用户的真实上下文与任务结果补证；不能拿管理员上下文或主观确认当作已验。版本/系统升级后也需重新检查相关项。

## 已有证据和下一次试用

现有证据来自一套本机环境：宿主 Windows 11 Pro build 26100 x64 / PowerShell 7.6.5；本轮只读预检重新核到来宾 EnterpriseEval build 26300 x64 / Windows PowerShell 5.1，目标普通账户存在、启用、非管理员且有交互会话。目标用户策略为 `Restricted`，因此便携新安装路径应阻断；这不表示现存 worker 已失效，也不是新安装已通过。

既有选定桌面/网页操作、窗口适配、合成浏览器状态隔离及一次进入既有来宾会话的证据仍单独保留。只读预检没有执行新安装，没有完成所有 Windows 版本的部署或回归。本次 Node 22/x64 检查通过，但给定 npm 路径不存在；已知 Node 父目录的4个标准入口也未发现。这只是有界路径检查，不能写成全来宾缺 npm 或要求立即新装。

新机器先分开核宿主、来宾和所选通道；再完成普通用户观察、Unicode输入/文件结果、拒绝错误目标、原ID超时查询及任务清理。浏览器另外验证窗口显示、版本匹配和同/异 scope 状态。系统处于软件厂商维护期、许可证有效等要求仍单独适用。完整能力边界见[验证说明](VERIFICATION.md)与[安全说明](../SECURITY.md)。

官方资料核查：2026-10-26。上述命令对应本批实际CLI；其检查边界以分项输出为准，不能由一个总状态扩展为所有能力已验。
