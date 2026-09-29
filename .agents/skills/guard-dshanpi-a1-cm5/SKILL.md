---
name: guard-dshanpi-a1-cm5
description: Safely audit, modify, configure, build, validate, commit, or publish DShanPI A1 CM5 support in this Armbian repository. Use for CM5 kernel or U-Boot device trees, board configuration, camera/AIC8800/multimedia integration, image builds, signed APT repository work, releases, or handoff; preserve the known-good original A1 baseline and CM5 package namespace.
---

# Guard DShanPI A1 CM5

Maintain the CM5 variant without changing the original A1 implementation. Treat builds, pushes, package publication, and Releases as gated operations.

## Start every task

1. Work from the repository root and inspect the current branch, upstream, and `git status`.
2. Run `.agents/skills/guard-dshanpi-a1-cm5/scripts/a1_cm5_gate.sh source <repo>` before editing. Stop and report the invariant if it fails; do not reconstruct a protected A1 file by assumption.
3. Read the reference that matches the task:
   - Device-tree or pin-routing work: [references/device-tree.md](references/device-tree.md)
   - Build, image inspection, package publication, or release work: [references/build-and-validate.md](references/build-and-validate.md)
   - File ownership, rationale, or change history: [references/change-map.md](references/change-map.md)
4. Inspect schematics, DTS bindings, or hardware evidence before changing electrical routing. Do not "fix" the recorded non-fatal SDIO clock-provider warning without such evidence.

## Preserve isolation

- Keep baseline `9a3ce1500ea7d149dabd64247afea21cde920ed9` and the four protected original-A1 paths enforced by the gate unchanged unless the user explicitly expands scope after reviewing the proposed diff.
- Put CM5 behavior under `dshanpi-a1-cm5`, DTB `rk3576-100ask-dshanpi-a1-cm5`, kernel namespace `rk3576-dshanpi-a1-cm5`, and its dedicated kernel/U-Boot patch layers.
- Reuse the shared A1 U-Boot defconfig only through the CM5 board hook that edits the temporary `.config`; never edit the shared defconfig for CM5 selection.
- Guard shared-framework fallbacks with `BOARD=dshanpi-a1-cm5`. Preserve original A1 behavior.
- Keep `lib/tools/common/__pycache__/` and generated `output/`, `.tmp/`, or cache artifacts out of commits.

## Modify and validate

1. Change the narrowest CM5 layer. Preserve include order when an override intentionally replaces a property from an earlier DTSI.
2. Run `bash -n` for changed shell/config files and `git diff --check`.
3. Run `.agents/skills/guard-dshanpi-a1-cm5/scripts/a1_cm5_gate.sh source <repo>` again.
4. Build with the recorded command in `references/build-and-validate.md`. Use a new monotonic `REVISION` for changed release packages.
5. Inspect an image read-only with:

   ```bash
   sudo .agents/skills/guard-dshanpi-a1-cm5/scripts/inspect-cm5-image.sh \
     /absolute/path/to/image.img
   ```

   Add `--require-repository` only for a release image built with `DSHANPI_INSTALL_REPOSITORY=yes`. For a routing change, also inspect the compiled DTB with `dtc`/`fdtget`; the generic inspector cannot prove task-specific pin choices.
6. Treat physical-board boot, display/touch, Ethernet, USB, audio, Wi-Fi/Bluetooth, all three cameras, thermal fan, upgrade, reboot, and rollback tests as distinct from software validation.

## Commit, push, and publish

- Separate board/device-tree changes from optional repository tooling and documentation when practical.
- Before committing or pushing, show the files and explain semantic A1-versus-CM5 impact. Push a feature branch, then confirm the remote ref equals the intended commit.
- Publish packages to `testing` only after the complete-set and signature checks pass. Promote the exact signed testing snapshot; never publish directly to stable.
- Do not create or alter a GitHub Release without explicit approval for the exact tag, target commit, title, prerelease state, and asset list.
- For an approved Release, retain the `.img`, create a `.img.gz` with `--keep`, verify its checksum, set `DSHANPI_RELEASE_APPROVED=yes`, and run `.agents/skills/guard-dshanpi-a1-cm5/scripts/a1_cm5_gate.sh release <repo> <image.img.gz>` before upload.

## Hand off

Report the branch, commits, remote ref, build UUID/log, image path and checksum, validation results, untracked files, and hardware tests still outstanding. Stop all mutation when the user says they are taking over.
