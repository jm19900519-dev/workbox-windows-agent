# 使用与试用验收

优先后台命令/API，确需桌面才用 VM。同一 VM 所有调用者必须共用配置中的 `leaseFile`。租约仅为显式协作，不是权限隔离或调度器。

先运行 `examples/observe.ps1`，实际打开新 PNG 和 JSON；`completed` 只证明传输/动作返回。核目标内容和可见边界。记事本可用非私密文本 `WorkBox trial 42` 测试，再核新截图和保存文件，不能据此推断别的 App 通过。

多步任务保存为同步 PowerShell 脚本，整段调用一次 `Invoke-WithWorkBoxLease.ps1 -ProjectName ... -LeaseFile <配置路径> -ScriptPath <任务绝对路径> -ArgumentList @(...) -WaitSeconds 30`。从观察、动作、验收一直持有到关闭自己的 browser context；不能嵌套同一锁、不能留未等待后台任务。外部程序非零退出必须检查并抛错。残留租约文件不等于正在占用，不能删除/夺锁。

桌面请求为 UTF-8 JSON：

```json
{"id":"trial-unique-id","session":1,"action":"observe"}
```

示例只是字段结构，`session` 必须取自本次 `Get-WorkBoxState`。每个新动作使用新 ID。窗口动作的 `hwnd`、`pid`、`session` 取自刚才实际看过截图的结果。`activate` 可带相对窗口的已观察 `x`,`y`；`click` 需 `x`,`y`；`type` 需 `text`（最多 4096 个 UTF-16 字符）；`key` 需 `key`，可选 `ctrl`/`alt`。按键：ENTER、ESC、TAB、SPACE、LEFT、UP、RIGHT、DOWN、HOME、END、A、S、O、F4。`close` 只向经核前台目标发送 Alt+F4。`stop` 会停止 worker，不用于普通任务收尾。

默认仅允许记事本、计算器进程，不支持任意 App 或任意应用宿主。检测到安全/权限/锁屏进程时拒绝输入；这不是所有第三方权限弹窗的完整识别器，仍须看画面，不得绕授权。

超时后**不要换 ID 重发动作**。执行 `Get-WorkBoxResult.ps1 -ConfigPath ... -RequestId <原ID> -OutputDirectory <新私有目录>` 核 pending/claimed/result 和实际来宾状态。宿主锁释放不表示来宾动作取消。worker 启动会归档旧请求而非重播；消除不确定性后再发下一请求。

浏览器示例只新建自己的 context，访问公开示例页面、保存本地截图，关闭该 context 后断开客户端，不枚举旧页面、不载入 storage state。`viewport: null` 仍不能替代原生点击前对实际桌面、窗口边界、浏览器边框和对话框可见性的检查。网页截图不证明桌面边缘可见。登录沿本任务正常授权步骤完成，无账户转移或认证绕过。

试用回件记录包 SHA、宿主/来宾系统、配置能力（不含凭据）、每条命令结果、新的脱敏证据、异常，以及完成后另一个项目能否取得租约。原始截图、连接文件和请求正文不外发，仅回脱敏摘要。验收分开覆盖：安装、观察、记事本 Unicode 输入/保存、目标拒绝、超时查询、context 隔离和显示边界。

## 可选按范围复用登录状态

连接已新核、外层已持有整任务租约时使用冻结 helper：

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
  // 仅在自己的 context 内完成正常、已授权的认证。
  await session.settle(); // 只适配自己的新窗口/弹窗至实际来宾显示。
  await session.save();   // 显式保存：私有加密状态，不可作为交付附件外发。
} finally {await session.close()}
```

两个环境变量均填写自己的绝对路径：`WORKBOX_CONFIG` 为宿主配置，`WORKBOX_PWSH` 为 PowerShell 7。项目/用户/站点变化得到不同 state key；匿名会话不借旧状态，状态不存在则新建空 context。父域 cookie 可能跨子域，勿把无关账户并入 scope。DPAPI 绑定宿主当前用户，不是可迁移账户包，也不保证网站永不要求登录。只保存明确授权的状态。忘记某 scope 时，先关闭会话并核 key，再仅删除私有目录里对应加密文件，不批量清别人项目状态。
