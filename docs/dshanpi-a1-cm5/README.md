# DShanPI A1 CM5 adaptation / DShanPI A1 CM5 适配说明

本目录说明 A1 CM5 的设备树结构、配置、编译、镜像验证与受控更新流程。面向自动化代理的可执行维护规范位于 [仓库 skill](../../.agents/skills/guard-dshanpi-a1-cm5/SKILL.md)。

This guide describes the A1 CM5 device-tree layout, configuration, build, image validation, and controlled-update workflow. The executable maintenance policy for coding agents is in the [repository skill](../../.agents/skills/guard-dshanpi-a1-cm5/SKILL.md).

## 中文

### 适配结构

- 板配置：[config/boards/dshanpi-a1-cm5.csc](../../config/boards/dshanpi-a1-cm5.csc)
- 内核设备树入口：`patch/kernel/rk3576-dshanpi-a1-cm5-vendor-6.1/dt/rk3576-100ask-dshanpi-a1-cm5.dts`
- U-Boot 设备树补丁：`patch/u-boot/legacy/u-boot-radxa-rk35xx/board_dshanpi-a1-cm5/`
- 无线、相机、多媒体扩展：`extensions/dshanpi-aic8800.sh`、`dshanpi-cm5-camera.sh`、`rockchip-multimedia.sh`
- 受控 APT 工具：[tools/dshanpi-repository/README.md](../../tools/dshanpi-repository/README.md)

内核 DTS 按 `rk3576.dtsi` → CM5 common → 三摄 → MIPI 屏 → base-v1 覆盖的顺序组成。base-v1 根据 CM5 底板原理图修正触摸、SDIO/HDMI GPIO 冲突、USB/PCIe 复用和音频。输出 DTB 固定为 `rockchip/rk3576-100ask-dshanpi-a1-cm5.dtb`。

原 A1 保持在共享 `rk35xx` 包体系；CM5 使用独立 `rk3576-dshanpi-a1-cm5` 内核、DTB、headers 和补丁层。共享 U-Boot defconfig 不修改，CM5 板 hook 只在临时构建 `.config` 中切换默认设备树。

更详细的节点和修改原则见 [设备树参考](../../.agents/skills/guard-dshanpi-a1-cm5/references/device-tree.md)，文件职责和安全边界见 [修改地图](../../.agents/skills/guard-dshanpi-a1-cm5/references/change-map.md)。

### 编译

```bash
.agents/skills/guard-dshanpi-a1-cm5/scripts/a1_cm5_gate.sh source "$PWD"

./compile.sh build BOARD=dshanpi-a1-cm5 BRANCH=vendor \
  BUILD_DESKTOP=yes DESKTOP_APPGROUPS_SELECTED= \
  DESKTOP_ENVIRONMENT=gnome DESKTOP_ENVIRONMENT_CONFIG_NAME=config_base \
  KERNEL_CONFIGURE=no PREFER_DOCKER=no RELEASE=noble
```

发布用包必须增加唯一、单调递增的 `REVISION`。若镜像需要预装受控 APT 源，再显式加入：

```bash
REVISION=25.11.0-trunk.20260929.1
./compile.sh build BOARD=dshanpi-a1-cm5 BRANCH=vendor \
  BUILD_DESKTOP=yes DESKTOP_APPGROUPS_SELECTED= \
  DESKTOP_ENVIRONMENT=gnome DESKTOP_ENVIRONMENT_CONFIG_NAME=config_base \
  KERNEL_CONFIGURE=no PREFER_DOCKER=no RELEASE=noble REVISION="$REVISION" \
  DSHANPI_INSTALL_REPOSITORY=yes \
  DSHANPI_REPO_CLIENT_PACKAGES_DIR=/absolute/path/to/client-packages
```

### 验证

```bash
(cd output/images && sha256sum -c <image>.img.sha)
sudo .agents/skills/guard-dshanpi-a1-cm5/scripts/inspect-cm5-image.sh \
  --require-repository "$PWD/output/images/<image>.img"
```

自动检查包括正确 FDT、独立内核包、AIC8800 DKMS/固件、相机包/IQ、三路 OV13850 和可选仓库配置。仍需在真机验证启动、显示/触摸、双网口、USB/PCIe、音频、Wi-Fi/蓝牙、三摄并发、风扇，以及更新/重启/回滚。

完整命令和发布顺序见 [编译与验证参考](../../.agents/skills/guard-dshanpi-a1-cm5/references/build-and-validate.md)。

### 当前软件验证记录（2026-09-29）

- Revision：`25.11.0-trunk.20260929.1`
- Build UUID：`ac3a9d65-53fd-4fde-95a5-eecb5cffc41b`
- 日志：`output/logs/log-build-ac3a9d65-53fd-4fde-95a5-eecb5cffc41b.log`
- 镜像：`Armbian-unofficial_25.11.0-trunk.20260929.1_Dshanpi-a1-cm5_noble_vendor_6.1.115_gnome_desktop.img`
- 已通过：完整镜像构建、镜像 SHA-256、只读挂载检查、3 个 AIC8800 模块、3 路 OV13850、相机 IQ、18 包 signed testing、testing→stable 逐字节一致、缺包与 U-Boot 拒绝测试。
- 尚未通过：物理板完整测试矩阵；这仍是发布到生产 stable 或新 GitHub Release 前的硬门槛。

## English

The CM5 port is intentionally isolated from the original A1. Its board file selects a CM5-specific DTB, kernel package family, kernel patch layer, and U-Boot patch layer. The kernel DTS combines the RK3576 SoC, common module/carrier hardware, three OV13850 pipelines, the MIPI panel, and final base-v1 schematic overrides. The shared A1 U-Boot defconfig remains unchanged; a CM5-only hook updates the temporary build configuration.

Run the source gate before editing, build with `BOARD=dshanpi-a1-cm5 BRANCH=vendor RELEASE=noble`, and use a unique `REVISION` for publishable packages. The repository client is opt-in. Verify the checksum and inspect the raw image read-only with `inspect-cm5-image.sh`; then complete the physical-board test matrix. See the linked skill references for device-tree rules, exact release commands, package publication, and file ownership.

The 2026-09-29 software baseline (`25.11.0-trunk.20260929.1`, build UUID `ac3a9d65-53fd-4fde-95a5-eecb5cffc41b`) passed the complete image build, checksum/read-only image audit, radio/camera payload checks, signed 18-package testing publication, exact promotion, and negative completeness/allowlist tests. Physical-board validation remains outstanding.
