# WorkBox — 独立 Windows 桌面工具包

[English](README.md) · [安装](docs/INSTALL.zh-CN.md) · [使用](docs/USAGE.zh-CN.md) · [排障](docs/TROUBLESHOOTING.zh-CN.md) · [安全](SECURITY.md)

WorkBox 在你自己的本地 Hyper-V Windows 虚拟机内执行有边界的桌面操作，不移动宿主鼠标、不抢宿主键盘焦点。宿主通过 PowerShell Direct 将请求交给来宾普通用户的交互 worker；整段任务由同一文件租约串行执行。可选 Playwright 通道为每个任务创建独立浏览器 context。

当前为**定向试用源码候选**，不是虚拟机镜像，也未宣称任何电脑均可一键安装。便携安装器和配置适配是新增代码；原机器历史运行通过不能证明本包跨机通过。[验证与限制](docs/VERIFICATION.md)列明证据边界。

已实现的源码能力：

- 观察来宾桌面；对记事本、计算器执行激活、点击、Unicode 输入、受限按键和关闭。
- 核对 VM ID/名称、来宾名称、普通用户/session、worker 源哈希、进程创建时间和启动身份。
- 拒绝复用请求 ID；超时后取回原 ID 回执，不重播输入。
- 可选有界面 Chromium：明确来宾绑定 IP、单一宿主 IPv4 防火墙范围、本机随机生成连接能力秘密、私有连接文件。
- 新建 context 使用 `viewport: null`，原生输入前看真实来宾屏幕；不靠扩大模拟 viewport 掩盖窗口裁剪。
- 可显式启用按项目、用户、精确 HTTPS 站点隔离的登录状态复用，使用宿主当前用户的 Windows DPAPI 加密。默认仍匿名；网站自身的登录到期规则仍适用。

先按[安装指南](docs/INSTALL.zh-CN.md)准备现有合法 VM，再用 PowerShell 7 运行观察示例。机器 ID、账户、状态路径、来宾路径和端口均显式配置，不附带原操作者配置。

目录：`src/host` 为安装与传输；`src/guest` 为桌面 worker；`src/browser` 为可选浏览器服务和客户端；`examples` 为持有租约的示例；`tools` 为导入、解析与白名单导出。包内不含 Windows ISO/VHD、浏览器或 Node 二进制、凭据和历史截图。

Windows 评估版有期限且另受微软许可约束；原生依赖从官方取得。[许可与来源](docs/LICENSING.md)说明公开发布前的源码归属核验门。
