> Historical handoff evidence. Current delivery requirements are in [the shared policy](../../../../DELIVERY_POLICY.md) and the checkout root DELIVERY_POLICY.md.

# DShanPI A1 CM5 handoff record

## Immutable baseline

- Historical checkout: `/home/ubuntu/armbian/ArmBianOS` (provenance only; use the current repository root)
- Remote: `ssh://git@ssh.github.com:443/dshanpi/ArmBianOS.git`
- Known-good original A1 commit: `9a3ce1500ea7d149dabd64247afea21cde920ed9`
- Baseline subject: `Update rkbin v1.09 version.`

Protected paths and their baseline SHA-256 values:

| Path | SHA-256 |
|---|---|
| `config/boards/dshanpi-a1.csc` | `0efe23903d2f15cf74a5ea9e73cfcb249fd13fe4ce2e01027417cc11730fc230` |
| `extensions/dshanpi-camera.sh` | `77c620a7b760d3d8cccb41047f522134c05b1d0f5a7bda0fa65bd1807bfbb722` |
| `patch/u-boot/legacy/u-boot-radxa-rk35xx/board_dshanpi-a1/u-boot-add-dshanpi-a1-rk3576-dts.patch` | `d5a5b413fb51538f38d9bd6d5f93b2d23ea69cf653e510644544c752d397f077` |
| `patch/u-boot/legacy/u-boot-radxa-rk35xx/defconfig/dshanpi-a1-rk3576_defconfig` | `9b4bf56b98b0a4faf0d3f47e670b7405fda3505c2b09e319ac68d258fc2a1044` |

## Published CM5 work

- Branch: `feature/dshanpi-a1-cm5`
- Board-support commit: `38d6da137` — `board: add DShanPi A1 CM5 support`
- Repository-tools commit: `96e43871d` — `tools: add signed DShanPi package repository workflow`
- Remote branch head: `96e43871d1d742571cf538fbbc1228eb580b80ea`
- Original A1 protected files were byte-identical to the baseline after both commits.

CM5 isolation:

- Board: `config/boards/dshanpi-a1-cm5.csc`
- DTB: `rockchip/rk3576-100ask-dshanpi-a1-cm5.dtb`
- Kernel family/package namespace: `rk3576-dshanpi-a1-cm5`
- Kernel patch layer: `patch/kernel/rk3576-dshanpi-a1-cm5-vendor-6.1/`
- U-Boot patch layer: `patch/u-boot/legacy/u-boot-radxa-rk35xx/board_dshanpi-a1-cm5/`
- Extensions: `dshanpi-cm5-camera`, `dshanpi-aic8800`

Shared files changed intentionally:

- `extensions/rockchip-multimedia.sh`: also recognizes `BOARDFAMILY=rk35xx`; original A1 behavior is unchanged.
- `lib/functions/general/apt-utils.sh`: repository-index fallback is guarded by `BOARD=dshanpi-a1-cm5`.

## Build and validation

Successful build command:

```bash
./compile.sh build BOARD=dshanpi-a1-cm5 BRANCH=vendor BUILD_DESKTOP=yes \
  DESKTOP_APPGROUPS_SELECTED= DESKTOP_ENVIRONMENT=gnome \
  DESKTOP_ENVIRONMENT_CONFIG_NAME=config_base KERNEL_CONFIGURE=no \
  PREFER_DOCKER=no RELEASE=noble
```

- Build UUID: `e3c3a3eb-c3f8-4519-947d-b8153dc3ab7b`
- Log: `output/logs/log-build-e3c3a3eb-c3f8-4519-947d-b8153dc3ab7b.log`
- Kernel: `6.1.115-vendor-rk3576-dshanpi-a1-cm5`
- AIC8800 package version: `5.0+git20260123.5f7be68d-8`
- DKMS modules verified: `aic8800_bsp_sdio.ko`, `aic8800_btlpm_sdio.ko`, `aic8800_fdrv_sdio.ko`
- DTB verified with three `ovti,ov13850` nodes and `wifi_chip_type = "aic8800"`.
- Camera IQ SHA-256: `361f854402a0b156eb47c81a75b7d162251d694f82e110ca5500d4d533de9697`
- Signed repository smoke test, GPG verification, and testing-to-stable snapshot comparison passed.

## Release

- Tag: `v25.11.0-trunk-dshanpi-a1-cm5`
- Tag commit: `96e43871d1d742571cf538fbbc1228eb580b80ea`
- Release: `https://github.com/dshanpi/ArmBianOS/releases/tag/v25.11.0-trunk-dshanpi-a1-cm5`
- State: published prerelease, not a draft
- Image asset: `Armbian-unofficial_25.11.0-trunk_Dshanpi-a1-cm5_noble_vendor_6.1.115_gnome_desktop.img.gz`
- Asset size: `1564655193` bytes
- Asset SHA-256: `0c77afa32ede94e0b75a02e564fbc574accde19303971988a5f12a1218a0d4b6`
- Additional assets: `.img.gz.sha` and `.img.txt`

## Remaining state and limits

- Local worktree had only `lib/tools/common/__pycache__/` untracked after publication; it was intentionally left untouched.
- Software build, package contents, image checksum, signed repository, and GitHub assets were verified.
- Physical-board boot, Wi-Fi/Bluetooth operation, display, and three-camera streaming still require hardware validation.
- A vendor-DTS warning around the SDIO power-sequence clock provider was non-fatal; do not change it without hardware evidence.
