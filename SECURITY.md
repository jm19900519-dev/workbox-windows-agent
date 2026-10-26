# Security / 安全

The browser WebSocket URL is a capability secret: anyone who possesses it may control the browser service. Do not print or publish it. Host private state must be ACL-restricted; guest browser configuration/state is restricted to the intended user and administrators. Only one specific host IPv4 is allowed by the created firewall rule. Existing unrelated broad rules, host compromise and guest-admin compromise are outside this package's controls. Browser contexts isolate web state, not OS/network authority. The shared lease is cooperative and can be bypassed by an administrator.

浏览器 WebSocket URL 是能力秘密，持有者可能控制服务，不得打印或公开。宿主私有状态需 ACL 限制，来宾配置/状态只给目标用户与管理员。新防火墙规则只允许一个宿主 IPv4；既有宽泛规则、宿主或来宾管理员失陷不由本包防护。context 隔离网页状态，不隔离 OS/网络权限。租约是协作机制，管理员可绕过。

No credentials, DPAPI XML, capability URLs, cookies/storage state, browsing history, user screenshots, models, private project records, VM disks, operating-system images or third-party commercial binaries belong in a release. The exporter reads only an explicit text allowlist and fails on configured patterns. A clean pattern scan is not proof that no secret exists; independently review the exact archive and diff.

发布包禁止凭据、DPAPI XML、能力 URL、cookie/storage state、浏览历史、用户截图、模型、私有项目记录、虚拟磁盘、系统镜像或第三方商业二进制。导出器只读明确文本白名单，命中模式即拒绝；扫描无命中不等于绝对无秘密，仍须独立审查实际归档和差异。

The ordinary user must not be an administrator. Keep source/config read-only to that user. Execute only within the configured VM; never use guest code on the host. Do not use this tool to bypass permissions, authentication, captchas, paywalls or safety review. Windows/website/application licensing remains separate.

普通操作用户不得是管理员，源码与配置对其只读。代码仅在已配置 VM 执行，不能拿来控制宿主。不得绕权限、本人认证、验证码、付费墙或安全审核；系统/网站/应用许可另行适用。

For a suspected leak, stop sharing the artifact, revoke/rotate the affected credential or browser capability through the owner, preserve minimal private evidence and prepare a sanitized report. Do not paste the secret into a public issue. Private security contact will be established when the repository owner confirms the release destination.

怀疑泄漏时停止分享，由所有者撤销/更换受影响凭据或连接能力，保存最小私有证据，再做脱敏报告，不把秘密贴进 public issue。正式仓库所有者确定后补私人安全联系方式。
