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

### 3. 带受控 APT 源的发布镜像

每次内容变化必须使用唯一且单调递增的 Debian revision，例如：

```bash
REVISION=25.11.0-trunk.20260929.1
tools/dshanpi-repository/build-client-packages.sh public.asc \
  https://packages.example.com \
  output/dshanpi-repository/client-packages/2026.09.2 \
  1:2026.09.2

./compile.sh build BOARD=dshanpi-a1-cm5 BRANCH=vendor \
  BUILD_DESKTOP=yes DESKTOP_APPGROUPS_SELECTED= \
  DESKTOP_ENVIRONMENT=gnome DESKTOP_ENVIRONMENT_CONFIG_NAME=config_base \
  KERNEL_CONFIGURE=no PREFER_DOCKER=no RELEASE=noble \
  REVISION="$REVISION" DSHANPI_INSTALL_REPOSITORY=yes \
  DSHANPI_REPO_CLIENT_PACKAGES_DIR="$PWD/output/dshanpi-repository/client-packages/2026.09.2"
```

仓库客户端是 opt-in；普通开发镜像不会自动加入。不要在 Debian maintainer script 内嵌套运行 `apt-mark`/`dpkg`。

### 4. 软件验证

```bash
(cd output/images && sha256sum -c <image>.img.sha)
sudo .agents/skills/guard-dshanpi-a1-cm5/scripts/inspect-cm5-image.sh \
  --require-repository "$PWD/output/images/<image>.img"
```

检查脚本以 read-only loop 和 `ro,noload` 挂载，验证 FDT、独立内核包、AIC8800 三个模块、相机包/IQ、三路 OV13850 和可选仓库客户端，并始终卸载 loop。

普通开发镜像不带仓库客户端时省略 `--require-repository`。若改动了触摸、摄像头以外的总线或 GPIO，必须再用 `dtc`/`fdtget` 针对最终 DTB 核对相关节点；通用检查脚本不会替代任务专属的 binding/引脚验证。供应商 schema 完整时可增加目标 DTB 的 `dtbs_check`，但不能把缺失 schema 导致的结果当作真机验证。

### 5. 签名仓库

```bash
tools/dshanpi-repository/prepare-incoming.sh \
  "$REVISION" output/dshanpi-repository/client-packages/2026.09.2

export REPO_GPG_KEYID=<完整指纹>
tools/dshanpi-repository/publish-local.sh publish \
  "$REVISION" "output/dshanpi-repository/incoming/$REVISION"

# 真机升级、重启、回滚全部通过后：
tools/dshanpi-repository/publish-local.sh promote
```

`publish` 只生成 testing，要求 18 个 package/architecture 对齐全，拒绝 U-Boot、`linux-libc-dev`、版本回退、不安全权限和构建机 RPATH。`promote` 验证签名与 SHA-256 后复制完全相同的 snapshot 到 stable。

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

Run the source gate before and after edits. Build the Noble/vendor GNOME image with `BOARD=dshanpi-a1-cm5`; use a unique monotonic `REVISION` for publishable packages. Enable the repository only with `DSHANPI_INSTALL_REPOSITORY=yes` and an exact two-package client directory.

Verify the image checksum and run `inspect-cm5-image.sh` read-only. Prepare exactly one reviewed candidate for each required package/architecture pair, publish only to signed testing, complete the physical-hardware matrix, and promote the byte-identical snapshot to stable. Software validation does not substitute for boot, I/O, camera, radio, upgrade, reboot, and rollback testing on the board.

Do not create a GitHub Release until the user approves the exact publication parameters. For an approved release, keep the raw image, compress with `--keep`, verify the checksum, and run the release-mode gate.
