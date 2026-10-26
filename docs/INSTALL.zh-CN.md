# 安装

## 前提

宿主需支持 Hyper-V、硬件虚拟化及 SLAT，并留足两套系统所需内存与磁盘。微软列出的 Windows 11 客户端版本为 Pro/Enterprise；本包不支持 Home 宿主。按微软正常流程启用 Hyper-V 并完成必要重启。[官方硬件要求](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/host-hardware-requirements)。

使用你有权使用的介质建立或复用本地 Windows VM。本包不创建 VM、不安装 Windows、不绕过初始设置或激活。[官方 Enterprise 评估版](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-11-enterprise)为 90 天专业评估；到期可能每小时关机。以实际介质条款为准，不把 ISO/VHD 当作本项目开源内容分发。

来宾准备一个用于 PowerShell Direct 的管理员，以及另一个普通本地用户；先完成普通用户首次交互登录。试用时保持来宾桌面解锁，避免个人浏览器资料。PSDirect 要求 VM 在本机运行、凭据有效、宿主具有 Hyper-V 管理权限。[微软说明](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/powershell-direct)。

宿主装 [PowerShell 7](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows)；来宾 worker 使用 Windows PowerShell/WinForms。按组织正常策略签名或解除已审本地脚本的下载阻止；安装器不改执行策略、不加 bypass，不操作宿主 GUI。

## 桌面安装

用管理员 PowerShell 7；下列路径为示例，全部替换为你自己的 VM 和目录。状态目录须新建、位于仓库外且不做云同步。同一 VM 的所有项目必须使用同一配置与租约。

```powershell
Get-VM | Select-Object Name,Id,State
$cfg='E:/WorkBoxLocal/workbox.local.json'
$cred=Get-Credential  # 填来宾管理员凭据，不把密码写进源码
./src/host/Initialize-WorkBoxConfig.ps1 -ConfigPath $cfg -VMId '<your-vm-guid>' -VMName 'MyWorkBox' -StateDirectory 'E:/WorkBoxPrivate' -GuestRoot 'D:/WorkBox' -GuestComputerName 'MYWORKBOX' -GuestUser 'DesktopAgent' -GuestAdministratorCredential $cred -BrowserPort 3033
./src/host/Install-WorkBoxGuest.ps1 -ConfigPath $cfg -WhatIf
./src/host/Install-WorkBoxGuest.ps1 -ConfigPath $cfg
./src/host/Get-WorkBoxState.ps1 -ConfigPath $cfg
./examples/observe.ps1 -ConfigPath $cfg -EvidenceDirectory 'E:/WorkBoxTrial/observe-01'
```

来宾目标盘须已存在。已有目录/任务会被拒绝，避免覆盖运行环境。安装器写入普通用户只读的源码/配置、可写的请求回执区和非提权交互任务。安装完成不等于桌面可用，必须看新截图与回执。凭据 XML 由 Windows DPAPI 绑定宿主用户/机器保护，不能随包复制。

## 可选浏览器

本人要查看已运行 VM 时，可双击 `src/host/Open-WorkBoxConsole.cmd` 后输入私有配置绝对路径，或预先设置环境变量 `WORKBOX_CONFIG`。终端用 `Open-WorkBoxConsole.cmd <配置路径> -CheckOnly` 只检查，去掉 `-CheckOnly` 才打开。内联预检不依赖 PS1 执行策略权限、不改策略、不启动/重启 Windows；官方 VMConnect 请求最大化，保留可见诊断窗口及私有 `console-launch.log`。看到控制台前保留诊断窗；零退出码本身不是桌面验收。后台代理不能自动打开此可见入口。

宿主和来宾各装[官方 Node.js LTS](https://nodejs.org/en/download)。`src/browser/package.json` 固定了历史实现使用的 Playwright 精确版本，两端相同。已核该版本在 npm 官方 registry 存在；跨机下载与启动尚待试用。遇不可获取不静默升级；组织禁止预发布版本时，先议定稳定版迁移并重新验收。

提供实际来宾 IPv4 和宿主 NAT 侧 IPv4，不填地址段、不关防火墙。此步需联网下载，体积随依赖变化；重依赖缓存放所选数据/缓存盘。

```powershell
./src/host/Install-WorkBoxBrowser.ps1 -ConfigPath $cfg -GuestNodePath 'D:/Node/node.exe' -GuestNpmPath 'D:/Node/npm.cmd' -GuestCacheDirectory 'D:/WorkBoxCache' -GuestIPv4 '<guest-ipv4>' -HostIPv4 '<host-nat-ipv4>' -WhatIf
# 审阅后去掉 -WhatIf 执行。
$env:npm_config_cache='F:/WorkBoxCache/npm'
$env:PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD='1'
Push-Location ./src/browser
npm ci --ignore-scripts --no-audit --no-fund
if($LASTEXITCODE -ne 0){throw 'npm ci failed'}
Pop-Location
./examples/browser.ps1 -ConfigPath $cfg -NodePath 'D:/Node/node.exe' -EvidenceDirectory 'E:/WorkBoxTrial/browser-01'
```

最后一条 NodePath 是宿主路径。来宾使用 Playwright 官方下载机制取得 Chromium，入站规则限定单一宿主地址。还需核查既有宽泛防火墙规则；本包不能替你证明其他规则安全。NAT 地址变化时由管理员核改原精确规则与配置，无自动扩范围行为。

## 升级与移除

私有证据保留在仓库外。不要向运行 worker 覆盖安装。先完成队列，持有共享租约，按任务名称仅停止自己创建的 WorkBox 任务，私下备份状态。审查新源哈希；退役旧任务后在新的专用来宾目录重新部署。退役时只移除本次两项计划任务及精确的 `WorkBox Browser Host Only` 防火墙规则，不删 VM、不清其他项目数据。候选包无破坏性自动卸载器或迁移器。

控制台入口核新 VMConnect 的父进程、创建时间和配置 VM GUID，并记录实际 PID；进程快速退出或未出现时显式报错。PID 活着仍不能证明桌面可见，须看真实窗口。启动观察超时先核原尝试，不盲目再开。
