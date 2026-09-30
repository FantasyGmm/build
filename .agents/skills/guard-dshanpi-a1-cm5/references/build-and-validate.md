# Build and validation / 编译与验证

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

本仓库不生成 Packages/Release/InRelease，不保存签名私钥，也不执行 testing/stable 发布。`dshanpi-build` 收集这里产生的 deb、构建精确版本元包、签名 APT 元数据并上传下载站。stable 晋级必须复用 testing 已验证包的 SHA-256，不能重新编译；U-Boot 和 `linux-libc-dev` 不进入在线升级集合。

2026-09-30 的 overlay 软件门禁记录：内核构建 UUID
`b1690249-a7f9-4a71-b8a8-040b6cba748f`，revision
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

Do not create a GitHub Release until the user approves the exact publication parameters. For an approved release, keep the raw image, compress with `--keep`, verify the checksum, and run the release-mode gate.
