# Build and validation / 编译与验证

所有流程必须同时遵守 [三仓统一交付门禁](../../../../DELIVERY_POLICY.md)。正式镜像由
dshanpi-build 使用与 APT 相同的精确包集组装，并自动上传 dshanpi/ArmBianOS Releases；
公开索引与下载文件验证完成前不能标记完整交付。包维护发行可以只更新 DEB 与版本元包。

## 中文流程

### 1. 源码门禁

```bash
.agents/skills/guard-dshanpi-a1-cm5/scripts/a1_cm5_gate.sh source "$PWD"
git status --short
git diff --check
```

门禁保护原 A1 基线 `9a3ce1500ea7d149dabd64247afea21cde920ed9`，并检查 CM5 独立命名、关键文件、shell 语法和未误提交的 `__pycache__`。

### 2. 普通开发镜像

```bash
./compile.sh build BOARD=dshanpi-a1-cm5 BRANCH=vendor \
  BUILD_DESKTOP=yes DESKTOP_APPGROUPS_SELECTED= \
  DESKTOP_ENVIRONMENT=gnome DESKTOP_ENVIRONMENT_CONFIG_NAME=config_base \
  KERNEL_CONFIGURE=no PREFER_DOCKER=no RELEASE=noble
```

常用变体：只编译内核可使用 Armbian 的 `kernel` target；需要调整内核配置时显式设置 `KERNEL_CONFIGURE=yes`。不要把 CM5 包重新命名成原 A1 的 `rk35xx` 包。

### 3. 由 dshanpi-build 编排的发布镜像

每次内容变化必须使用唯一且单调递增的 Debian revision。APT 客户端、dspi-config 和系统版本元包均由外部 `dshanpi-build` 仓库预先制作，本仓库只安装传入的精确文件：

```bash
./compile.sh build BOARD=dshanpi-a1-cm5 BRANCH=vendor \
  BUILD_DESKTOP=yes DESKTOP_APPGROUPS_SELECTED= \
  DESKTOP_ENVIRONMENT=gnome DESKTOP_ENVIRONMENT_CONFIG_NAME=config_base \
  KERNEL_CONFIGURE=no PREFER_DOCKER=no RELEASE=noble \
  REVISION=25.11.0-trunk.20260930.1 \
  DSHANPI_DSPI_CONFIG_DEB=/absolute/path/to/dspi-config.deb \
  DSHANPI_REPO_CLIENT_PACKAGES_DIR=/absolute/path/to/client-packages \
  DSHANPI_RELEASE_META_DEB=/absolute/path/to/release-meta.deb
```

三项路径均为 opt-in；普通开发镜像不依赖外部发行产物。不要在 Debian maintainer script 内嵌套运行 `apt-mark`/`dpkg`。

### 4. 软件验证

```bash
(cd output/images && sha256sum -c <image>.img.sha)
sudo .agents/skills/guard-dshanpi-a1-cm5/scripts/inspect-cm5-image.sh \
  --require-repository "$PWD/output/images/<image>.img"
```

检查脚本以 read-only loop 和 `ro,noload` 挂载，验证 FDT、独立内核包、AIC8800 三个模块、相机包/IQ、三路 OV13850 和可选仓库客户端，并始终卸载 loop。

普通开发镜像不带仓库客户端时省略 `--require-repository`。若改动了触摸、摄像头以外的总线或 GPIO，必须再用 `dtc`/`fdtget` 针对最终 DTB 核对相关节点；通用检查脚本不会替代任务专属的 binding/引脚验证。供应商 schema 完整时可增加目标 DTB 的 `dtbs_check`，但不能把缺失 schema 导致的结果当作真机验证。

### 5. APT 发布边界

按 DELIVERY_POLICY.md 的 G12，每个镜像都要关联并发布可后装的内核 headers DEB。
从实际镜像内核及包版本确定 headers，核对 kernel release、生成头文件、Module.symvers
和 build 链接；验证匹配架构环境中的外部模块编译及 vermagic。发布记录包含镜像与
headers 的哈希、版本、下载大小、Installed-Size、APT 安装命令和公开下载链接。
同一内核的 CLI/桌面变体可共用一个包；历史 headers 随旧镜像保留。是否预装另由镜像方案决定。

大小参考（2026-10-09 原版 A1 实测，不代表其他内核版本）：
`linux-headers-vendor-rk35xx=25.11.0-trunk.20261008.4` 对应
`6.1.115-vendor-rk35xx`，DEB 为 14,008,176 字节（14.01 MB / 13.36 MiB），
`Installed-Size` 为 74,410 KiB（72.7 MiB）；实板头文件目录 `du -sk` 为
137,076 KiB（133.9 MiB，含文件系统分配开销及安装后生成内容）。gcc/make 等依赖另计。
包压缩大小、声明安装大小和实际磁盘占用应分别说明，不混用。

本仓库不生成 Packages/Release/InRelease，不保存签名私钥，也不执行 testing/stable 发布。`dshanpi-build` 收集这里产生的 deb、构建精确版本元包、签名 APT 元数据并上传下载站。stable 晋级必须复用 testing 已验证包的 SHA-256，不能重新编译；U-Boot 和 `linux-libc-dev` 不进入在线升级集合。

2026-09-30 的 overlay 软件门禁记录：内核构建 UUID
`f6ef3b63-5ffe-43b2-a6da-14dab11cc986`，revision
`25.11.0-trunk.20260930.1`。从生成的 DTB deb 解包后，主 DTB 与
`dshanpi-a1-cm5-pcie1.dtbo` 可由 `fdtoverlay` 成功合并；目标 USB1 节点为
`disabled`，Combo PHY1 与 PCIe1 为 `okay`。该结果不替代真机链路验证。

### 6. 真机矩阵

- 串口和冷/热启动；正确 DTB 与内核。
- HDMI/DP、1024×768 MIPI 屏、背光和 GT911。
- 双网口、USB2/USB3/Type-C；PCIe0，以及可选 PCIe1 与 USB1 的互斥性。
- ES8388 播放/录音/耳机检测、BT SCO。
- Wi-Fi 扫描/吞吐/休眠恢复，Bluetooth 配对/音频。
- 三路相机逐路和并发采集、IQ、长时间稳定性。
- PWM 风扇与温控、UFS/eMMC/SD。
- testing 升级、DKMS 重建、重启、stable promotion 和 rollback。

## English workflow

Run the source gate before and after edits. Build the Noble/vendor image with `BOARD=dshanpi-a1-cm5`; use a unique monotonic `REVISION` for publishable packages. Official releases are orchestrated by `dshanpi-build`, which passes exact local dspi-config, repository-client, and release-meta packages into this build.

Verify the image checksum and run `inspect-cm5-image.sh` read-only. Package-set validation, APT signing, testing publication, and stable promotion live in `dshanpi-build`, not ArmBianOS. Software validation does not substitute for boot, I/O, camera, radio, upgrade, reboot, and rollback testing on the board.

Follow the authorized, version-controlled publication plan. An authorized automated pipeline does not need repeated per-asset confirmation; ad hoc publication outside existing authorization still needs approval. Keep the raw image, compress with `--keep`, verify checksums, and verify public assets after upload. The existing release-mode shell gate is the manual CM5 adapter; automated delivery must validate the pinned remote commit and the complete shared policy. Missing automation must be reported explicitly.
