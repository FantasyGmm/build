# 仓库强制工作要求

开始修改、构建、发布或评审前必须读取 [三仓统一交付门禁](DELIVERY_POLICY.md)，并运行
`python3 tools/check-delivery-policy.py`。

本仓库提供板卡、内核、设备树/DTBO、驱动/BSP 和镜像构建引擎。正式发行由 dshanpi-build
固定源码和精确 DEB、签名发布 apt.100ask.net，并编排镜像自动上传 GitHub Releases。
镜像必须预装 dspi-config、本板 profile、签名源/公钥和发行元包，与 APT 包集一致。
后续硬件支持和软件更新必须可通过 DEB/APT 交付；手工复制驱动或 DTBO 不构成正式修复。
每个镜像必须按 G12 同步交付与内核精确匹配、用户可通过 APT 后装的 `linux-headers-*`
DEB；记录对应关系、大小、哈希和安装命令，验证外部模块编译并保留历史包。

涉及 A1/CM5 时必须读取 `.agents/skills/guard-dshanpi-a1-cm5/SKILL.md`，运行其 source 门禁。
保留原 A1 基线 `9a3ce1500ea7d149dabd64247afea21cde920ed9` 及四个受保护路径；
CM5 使用独立板型、DTB 和包命名空间。不得把 CM5 修复泄漏到原 A1。

共享变更需评估四板，板卡专属变更需说明适用范围。提交前执行政策门禁、适用源码/镜像
检查、语法检查及 `git diff --check`；保留构建日志、版本和哈希，区分软件与实板证据。
发布按已授权流水线及固定版本计划执行；临时人工发布遵守相同验证要求。
跨仓政策同步须使用 `--peer` 核对；门禁文件检查不能代替实际自动发布和硬件验收。

# General LLM instructions

Generated prose: keep very brief. Includes code comments, commit messages, pull request text, issue reports, patch cover letters. Reviewers read many. Walls of text waste their time.

State the goal and the expected result. Do not describe how: the code and the diff show that.
Issue reports: include the steps and logs needed to reproduce.
Pull request text: also state which boards were tested.

Clarity register: ASD-STE100 Simplified Technical English. Apply to all generated text:

- One idea per sentence. Max 20 words.
- Active voice. Present tense where true.
- Instructions in imperative: "Run X", not "X should be run".
- One term per concept. No synonym rotation.
- Noun clusters max 3 words.
- Pronoun only with one clear referent. Else repeat the noun.
- Cut fillers. Keep every word that removes ambiguity.
- Brevity conflicts with clarity → clarity wins.
