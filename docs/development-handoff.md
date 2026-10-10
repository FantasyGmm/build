# ArmBianOS 开发交接

维护约束以 [DELIVERY_POLICY.md](../DELIVERY_POLICY.md) 为准。仓库内
[guard skill](../.agents/skills/guard-dshanpi-a1-cm5/SKILL.md) 为唯一维护入口，
无需复制原服务器的全局 Codex 配置或个人凭据。

## 已有变更

原 A1 基线为 `9a3ce1500ea7d149dabd64247afea21cde920ed9`。CM5 独立 board、DTB、
内核包命名空间及相机/无线扩展见 [变更地图](../.agents/skills/guard-dshanpi-a1-cm5/references/change-map.md)。
原 A1 四个受保护路径必须保持一致。共享扩展加载、多媒体识别和 headers 打包修复需独立评估影响。
历史 CM5 构建与最初 Release 记录已从本机技能归档到
[historical-handoff](../.agents/skills/guard-dshanpi-a1-cm5/references/historical-handoff.md)，其中版本与路径仅描述当时状态。

[BTF ABI 修复说明](kernel-headers-btf-abi.md) 记录了 pahole 缺失导致安装后 headers 改变配置、
外部模块结构大小错误的根因。源码已修复，不代表新版 headers DEB 已发布。
当前已测 A1 使用 vendor 6.1.115 内核，不应因为发行名为 Armbian 就宣称是 upstream mainline。

## 新环境与验证

三仓下载、主机依赖、签名配置和完整构建入口统一见
[dshanpi-build 新服务器手册](https://github.com/dshanpi/dshanpi-build/blob/main/docs/new-server.md)。
源码下载保留 Git 历史，不能用源码 ZIP 代替需要基线检查的 checkout。
从本仓库根执行：

```bash
python3 tools/check-delivery-policy.py
python3 tools/check-repository-hygiene.py
bash .agents/skills/guard-dshanpi-a1-cm5/scripts/a1_cm5_gate.sh source "$PWD"
python3 tools/test-kernel-headers-btf.py
git diff --check
```

完整系统由 dshanpi-build 固定三仓输入和精确包集，再调用本仓库构建。
新增内核/headers 内容必须提高发行版本，验证干净安装、外部模块 ABI 和匹配实板。
镜像自动 GitHub Release 流水线、各板完整硬件验收与新版 headers 发布仍分别追踪，
本次 main 合并和源码检查不替代这些验收。
