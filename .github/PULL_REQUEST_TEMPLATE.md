# Description

_Please include a summary of the change and which issue is fixed. Please also include relevant motivation and context. List any dependencies that are required for this change._

[GitHub issue](https://github.com/armbian/build/labels/Task%2FTo-Do) reference: 
[Jira](https://armbian.atlassian.net/jira) reference number [AR-9999]

# Documentation summary for feature / change

_Please delete this section if entry to main documentation is not needed._

If documentation entry is predicted, please provide key elements for further implementation [into main documentation](https://docs.armbian.com) and set label to "Needs Documentation". You are welcome to open a PR to documentation or you can leave following information for technical writer:

- [ ] short description (copy / paste of PR title)
- [ ] summary (description relevant for end users)
- [ ] example of usage (how to see this in function)

# How Has This Been Tested?

_Please describe the tests that you ran to verify your changes. Please also note any relevant details for your test configuration._

- [ ] Test A
- [ ] Test B

# Checklist:

_Please delete options that are not relevant._

- [ ] My code follows the style guidelines of this project
- [ ] I have performed a self-review of my own code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] My changes generate no new warnings
- [ ] Any dependent changes have been merged and published in downstream modules

## DShanPI 交付门禁（必填）

遵守 [三仓统一交付门禁](../DELIVERY_POLICY.md)，说明变更适用的产品、发行类型及关联仓库。

- [ ] 已运行政策门禁和适用的源码/包/镜像测试，共享变更覆盖全部受影响板型。
- [ ] DEB 版本、精确依赖元包、源码锁及哈希记录完整；历史已发布内容保持不可变。
- [ ] Overlay、驱动或软件更新进入 DEB/APT 路径；镜像预装工具、profile、签名源及精确包集。
- [ ] 完整系统发行有自动 GitHub Release 和公开下载证据；包维护发行明确不生成新镜像。
- [ ] 升级/回滚及实板验证分别记录，未完成自动化/硬件项明确列出，不以单板热修复代替交付。

相关仓库/PR：
验证证据与剩余项：

## G13 源码归属与交接

- [ ] 说明所属组件、职责边界、关联仓库及受影响板型；板卡差异由 profile 表达。
- [ ] 实现与测试证据分开提交，厂商来源和补丁可追溯，历史 lock/包/tag 不变。
- [ ] 已检查暂存文件并运行 hygiene 门禁；未包含缓存、构建产物或凭据。
- [ ] skills、开发记录及新服务器复现入口已同步，未完成项如实标明。

归属与跨仓依赖：
新环境复现入口：
