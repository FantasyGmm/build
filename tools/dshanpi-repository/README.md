# DShanPI A1 CM5 controlled APT repository

## 中文说明

本工具只发布 A1 CM5 的 Ubuntu 24.04 (`noble`) 受控更新源，与原 A1 包完全隔离。普通镜像默认不安装该源；只有设置 `DSHANPI_INSTALL_REPOSITORY=yes` 并提供由 `build-client-packages.sh` 生成的唯一一对 keyring/repository 包时才启用。

发布流程必须使用新的单调递增 `REVISION`：先用 `prepare-incoming.sh` 收集 `required-packages.txt` 中全部 18 个 package/architecture 对并审查 `MANIFEST.source`，再用完整 GPG 指纹执行 `publish-local.sh publish` 生成 testing。真机完成升级、DKMS、重启、相机/无线/多媒体和回滚测试后，才执行 `promote`；stable 始终是 testing 的逐字节副本。

仓库明确拒绝 U-Boot、`linux-libc-dev`、缺包、重复歧义包、降级、同版本不同内容、不安全权限和构建机 RPATH。Release 设置 `NotAutomatic: yes`、`ButAutomaticUpgrades: no`，安装源本身不会授权无人值守的系统栈切换。详细构建与镜像验证见 [`docs/dshanpi-a1-cm5/README.md`](../../docs/dshanpi-a1-cm5/README.md)。

This tooling publishes an A1 CM5-only Ubuntu 24.04 (`noble`) repository. It is
deliberately separate from the original A1 packages and is disabled in normal
images unless `DSHANPI_INSTALL_REPOSITORY=yes` is set.

The repository is `NotAutomatic: yes` and `ButAutomaticUpgrades: no`. Merely
installing its source therefore does not authorize an unattended kernel, DTB,
BSP, DKMS, camera or multimedia transition. U-Boot and `linux-libc-dev` are not
accepted at all.

## Release version

Never rebuild changed Armbian packages with the existing `25.11.0-trunk`
version. Use a unique, monotonically increasing release revision, for example:

```text
25.11.0-trunk.20260929.1
```

Pass that value as Armbian's `REVISION` when building the image/packages. The
BSP, kernel image, DTB and headers must all have exactly that version, while
the generated `base-files` version must begin with it. Publication enforces
these relationships and rejects a downgrade or a same-version content change.

## 1. Build repository client packages

Export the repository signing public key, then build into an empty directory.
Production URLs must use HTTPS; loopback HTTP is accepted only for tests.

```bash
tools/dshanpi-repository/build-client-packages.sh public.asc \
  https://packages.example.com \
  output/dshanpi-repository/client-packages/2026.09.2 \
  1:2026.09.2
```

The client source points to:

```text
https://packages.example.com/dshanpi-a1-cm5/stable
```

For a release image, opt in explicitly and point the build at that exact
two-package directory:

```bash
REVISION=25.11.0-trunk.20260929.1
./compile.sh build BOARD=dshanpi-a1-cm5 BRANCH=vendor RELEASE=noble \
  REVISION="$REVISION" DSHANPI_INSTALL_REPOSITORY=yes \
  DSHANPI_REPO_CLIENT_PACKAGES_DIR="$PWD/output/dshanpi-repository/client-packages/2026.09.2"
```

Keep the normal board build settings required by the intended image variant.

## 2. Prepare the complete incoming set

After the release build finishes, collect the exact package set:

```bash
tools/dshanpi-repository/prepare-incoming.sh \
  "$REVISION" \
  output/dshanpi-repository/client-packages/2026.09.2
```

This command:

- requires every package/architecture pair in `required-packages.txt`;
- downloads the pinned AIC8800 packages and verifies their SHA-256 values;
- reproducibly repacks the reviewed camera archive with safe permissions and
  removes its build-host RPATH;
- rejects ambiguous package candidates instead of selecting one silently; and
- writes `MANIFEST.source` for human review.

The vendor camera archive lacks complete machine-readable licensing metadata.
Resolve redistribution licensing before publishing it from a production
repository.

## 3. Publish testing and promote

Use the full signing-key fingerprint. Direct publication to stable is not
supported.

```bash
export REPO_GPG_KEYID=<full-fingerprint>
tools/dshanpi-repository/publish-local.sh publish \
  "$REVISION" \
  "output/dshanpi-repository/incoming/$REVISION"
```

Publication audits payload permissions and ELF RPATHs, carries forward old
stable package versions for rollback, creates multiversion indexes, signs the
Release files, and archives the previous testing snapshot.

Serve the parent web root for a local client test:

```bash
tools/dshanpi-repository/publish-local.sh serve
```

After image boot, camera, Wi-Fi/Bluetooth, multimedia, DKMS rebuild, reboot and
rollback tests pass on real A1 CM5 hardware, promote the byte-identical testing
snapshot:

```bash
tools/dshanpi-repository/publish-local.sh promote
```

The previous stable tree is retained under `snapshots/`. Do not prune a
snapshot until its replacement has passed the full hardware and rollback test
matrix and no deployed device still depends on it.
