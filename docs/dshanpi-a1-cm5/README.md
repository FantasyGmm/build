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

### 设备树组成与修改位置

A1 CM5 的主内核设备树是：

```text
patch/kernel/rk3576-dshanpi-a1-cm5-vendor-6.1/dt/rk3576-100ask-dshanpi-a1-cm5.dts
```

它按以下顺序包含设备树文件。后包含的 DTSI 可以覆盖前面已经定义的节点或属性，因此不要随意调整顺序：

1. `rk3576.dtsi`：RK3576 SoC 的 CPU、总线、中断控制器和片上外设基础定义。
2. `rk3576-100ask-a1-cm5-common.dtsi`：CM5 通用硬件，包括电源、PMIC、存储、网络、USB、音频和 SDIO 等。
3. `rk3576-100ask-a1-cm5-ov13850-3cam.dtsi`：三路 OV13850 的 I2C、MIPI CSI、RKCIF 和 RKISP 数据链路。
4. `rk3576-100ask-a1-cm5-1024-768-mipi.dtsi`：1024×768 MIPI DSI 屏幕、PWM 背光及旧版触摸描述。
5. `rk3576-100ask-a1-cm5-base-v1.dtsi`：CM5 底板最终覆盖层；触摸、USB/PCIe 复用、音频路由以及底板 GPIO 差异通常在这里修改。

编译生成的内核 DTB 是：

```text
/boot/dtb/rockchip/rk3576-100ask-dshanpi-a1-cm5.dtb
```

板配置 [`config/boards/dshanpi-a1-cm5.csc`](../../config/boards/dshanpi-a1-cm5.csc) 通过下面的配置选择该 DTB：

```bash
BOOT_FDT_FILE="rockchip/rk3576-100ask-dshanpi-a1-cm5.dtb"
```

U-Boot 使用单独的最小设备树补丁：

```text
patch/u-boot/legacy/u-boot-radxa-rk35xx/board_dshanpi-a1-cm5/u-boot-add-dshanpi-a1-rk3576-dts.patch
```

通常修改 CM5 外设、引脚、电源、显示、相机或音频，应修改内核 DTS/DTSI。只有启动阶段确实需要访问的硬件才考虑修改 U-Boot DTS，不要把常规 Linux 外设改动误加到 U-Boot 设备树中。修改前还应确认对应版本的底板原理图、引脚复用、电平和设备树 binding。

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

### Device-tree files and edit locations

The main kernel device tree is `patch/kernel/rk3576-dshanpi-a1-cm5-vendor-6.1/dt/rk3576-100ask-dshanpi-a1-cm5.dts`. It includes `rk3576.dtsi`, the CM5 common hardware layer, the three-OV13850 camera graph, the 1024×768 MIPI panel layer, and finally the base-v1 carrier overrides. Preserve this order because later includes intentionally override earlier definitions.

The resulting DTB is `/boot/dtb/rockchip/rk3576-100ask-dshanpi-a1-cm5.dtb`, selected by `BOOT_FDT_FILE` in `config/boards/dshanpi-a1-cm5.csc`. U-Boot uses the separate minimal patch under `patch/u-boot/legacy/u-boot-radxa-rk35xx/board_dshanpi-a1-cm5/`. Normal Linux peripheral and pin-routing changes belong in the kernel DTS/DTSI; only hardware required during boot should be added to the U-Boot tree.

The CM5 port is intentionally isolated from the original A1. Its board file selects a CM5-specific DTB, kernel package family, kernel patch layer, and U-Boot patch layer. The kernel DTS combines the RK3576 SoC, common module/carrier hardware, three OV13850 pipelines, the MIPI panel, and final base-v1 schematic overrides. The shared A1 U-Boot defconfig remains unchanged; a CM5-only hook updates the temporary build configuration.

Run the source gate before editing, build with `BOARD=dshanpi-a1-cm5 BRANCH=vendor RELEASE=noble`, and use a unique `REVISION` for publishable packages. The repository client is opt-in. Verify the checksum and inspect the raw image read-only with `inspect-cm5-image.sh`; then complete the physical-board test matrix. See the linked skill references for device-tree rules, exact release commands, package publication, and file ownership.

The 2026-09-29 software baseline (`25.11.0-trunk.20260929.1`, build UUID `ac3a9d65-53fd-4fde-95a5-eecb5cffc41b`) passed the complete image build, checksum/read-only image audit, radio/camera payload checks, signed 18-package testing publication, exact promotion, and negative completeness/allowlist tests. Physical-board validation remains outstanding.
