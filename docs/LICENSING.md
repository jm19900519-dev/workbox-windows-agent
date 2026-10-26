# Licensing and provenance / 许可与来源

This private candidate contains locally developed WorkBox orchestration code and newly written portable adapters. The reviewed import process records SHA-256 for the source worker, lease and frozen session/DPAPI helper outside the release. It does not copy source repositories, third-party SDK code, private state or assets. Provenance identifies the imported files; it does not by itself establish legal ownership.

当前私有候选含本地开发的 WorkBox 编排源码及新写便携适配。导入过程在包外记录 worker、租约、冻结会话/DPAPI helper 的 SHA-256；不复制整仓、第三方 SDK、私有状态或资产。来源可追溯不自动证明法律权属。

Under the user's authorization to open-source this project, the maintainer selected MIT for the project's own written/generated source and documentation, with the notice `WorkBox contributors`. The selected local files have no identified copied third-party SDK implementation or conflicting license notice. This review does not prove all possible copyright claims are absent. [LICENSE](../LICENSE) applies only to WorkBox-owned material; [NOTICE](../NOTICE.md) preserves the separate dependency boundaries. The private trial is not a completed public release.

依据用户本次开源授权，维护者为本项目自有源码选用 MIT；自有文档采用相同许可，署名 `WorkBox contributors`。所选本地文件未发现复制第三方 SDK 实现或冲突许可标注；这不等于证明不存在任何潜在权利主张。`LICENSE` 只覆盖 WorkBox 自有材料，`NOTICE` 保留依赖边界；私有试用不等于公开发布完成。

Third-party prerequisites are acquired separately:

| Dependency | Official source | Boundary |
| --- | --- | --- |
| Windows Enterprise evaluation | [Microsoft Evaluation Center](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-11-enterprise) | 90-day evaluation; separate terms; no ISO/VHD redistribution in this package. |
| Hyper-V / PowerShell Direct | [Microsoft requirements](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/host-hardware-requirements), [PSDirect](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/powershell-direct) | Supported Windows hardware/edition and valid guest credentials; no Windows license supplied. |
| PowerShell | [Official installation](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows), [source license](https://github.com/PowerShell/PowerShell/blob/master/LICENSE.txt) | Obtain runtime separately; no binaries bundled. |
| Node.js | [Official download](https://nodejs.org/en/download), [license](https://github.com/nodejs/node/blob/main/LICENSE) | Runtime and included components retain their licenses; no binary bundled. |
| Playwright | [Official repository license](https://github.com/microsoft/playwright/blob/main/LICENSE), [npm package](https://www.npmjs.com/package/playwright) | Apache-2.0; dependency lock records exact package integrity; installed separately. |
| Chromium | [Playwright browser installation](https://playwright.dev/docs/browsers), [Chromium licensing](https://www.chromium.org/chromium-os/licenses/) | Download separately; retains its own and bundled-component notices; no browser binary bundled. |

官方来源核查日期：2026-10-26。These links establish dependency terms and requirements, not WorkBox source ownership. 用户自装应用、网站账户及其内容不获本项目许可证授权。
