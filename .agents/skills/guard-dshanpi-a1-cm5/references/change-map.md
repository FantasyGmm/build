# Change map / 修改地图

## 中文

### 边界

已验证的原 A1 基线为 `9a3ce1500ea7d149dabd64247afea21cde920ed9`。以下文件必须保持与该提交一致：

- `config/boards/dshanpi-a1.csc`
- `extensions/dshanpi-camera.sh`
- `patch/u-boot/legacy/u-boot-radxa-rk35xx/board_dshanpi-a1/u-boot-add-dshanpi-a1-rk3576-dts.patch`
- `patch/u-boot/legacy/u-boot-radxa-rk35xx/defconfig/dshanpi-a1-rk3576_defconfig`

已落地的主要提交：`38d6da137`（新增 A1 CM5 板级支持）、`96e43871d` 和 `897e317bb`（早期仓库实验）。APT 构建与发布现已迁往独立的 `dshanpi-build`；本仓库只保留板级源码和镜像构建所需的预制包安装接口。

### CM5 文件职责

| 路径 | 作用 |
|---|---|
| `config/boards/dshanpi-a1-cm5.csc` | 板名、DTB、扩展、独立内核 namespace、临时 U-Boot DT 选择、BSP 配置 |
| `patch/kernel/rk3576-dshanpi-a1-cm5-vendor-6.1/dt/` | 内核 DTS/DTSI 与 carrier 覆盖 |
| `patch/u-boot/.../board_dshanpi-a1-cm5/` | 独立的最小 U-Boot DTS patch |
| `extensions/dshanpi-aic8800.sh` | 固定版本/校验和下载缓存、固件和 DKMS 安装 |
| `extensions/dshanpi-cm5-camera.sh` | 安全重打包 RKAIQ、IQ 校验和安装 |
| `extensions/rockchip-multimedia.sh` | MPP/RGA/GStreamer；共享修改必须保留原 A1 行为 |
| `extensions/dshanpi-dspi-config.sh` | 安装由 `dshanpi-build` 提供的 dspi-config 包 |
| `extensions/dshanpi-repository.sh` | 安装由 `dshanpi-build` 提供的 keyring/source 客户端包 |
| `extensions/dshanpi-release-meta.sh` | 安装由 `dshanpi-build` 提供的系统版本元包 |
| `packages/bsp/dshanpi-a1-cm5/` | dspi-config 板卡清单及相机 vendor 包安全重打包工具 |
| `lib/functions/general/apt-utils.sh` | 仅限 CM5 的 APT metadata fallback |

### 设计决定

- 原 A1 和 A1 CM5 使用不同内核包名，防止升级互相覆盖。
- 共享 U-Boot defconfig 不改；CM5 hook 只修改构建工作树中的 `.config`。
- 相机供应商 deb 会被确定性重打包：修正 world-writable mode、去掉 build-host RPATH、加入校验与版权说明。
- AIC8800 包固定版本和 SHA-256，缓存命中前仍校验；下载使用原子临时文件和低速超时。
- APT 包集、allowlist、签名和 stable/testing 状态由 `dshanpi-build` 维护；U-Boot 与 `linux-libc-dev` 不进入在线升级集合。
- 带 sticky bit 的标准 `1777` 目录合法；普通 world-writable 文件、非 sticky world-writable 目录和 set-id payload 会被拒绝。

### 已知限制

- RKAIQ 供应商包缺少完整机器可读许可信息；生产分发前必须完成人工许可审查。
- `sdio-pwrseq` 的 vendor DTS clock-provider 告警目前是非致命已知项。
- 软件构建和镜像内容可以自动验证；物理接口和升级/回滚仍必须真机确认。

## English

The original A1 baseline and its four protected paths are immutable by default. CM5 owns a separate board file, DTB, kernel package family, kernel patch directory, U-Boot patch directory, camera extension, and AIC8800 extension. Shared framework edits are acceptable only when the A1 behavior remains unchanged and CM5-only fallbacks are explicitly board-guarded.

The repository workflow pins and verifies radio inputs, deterministically sanitizes the vendor camera package, requires a complete release set, rejects U-Boot and `linux-libc-dev`, audits modes and RPATHs, signs testing, and only promotes an identical verified snapshot. Keep generated caches and build outputs out of Git commits. Hardware verification and camera-package licensing review remain external completion gates.
