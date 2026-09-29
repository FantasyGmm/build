#!/usr/bin/env bash
set -euo pipefail

usage() {
	echo "Usage: $0 <source|release> [repo] [image.img.gz]" >&2
	exit 2
}

mode=${1:-source}
repo=${2:-}
artifact=${3:-}
baseline=${DSHANPI_A1_BASELINE:-9a3ce1500ea7d149dabd64247afea21cde920ed9}
failures=0

pass() { printf '[PASS] %s\n' "$1"; }
warn() { printf '[WARN] %s\n' "$1" >&2; }
fail() { printf '[FAIL] %s\n' "$1" >&2; failures=$((failures + 1)); }

[[ "$mode" == source || "$mode" == release ]] || usage
if [[ -z "$repo" ]]; then
	repo=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || true)
fi
[[ -n "$repo" ]] || { echo "Run inside the repository or pass its path" >&2; exit 2; }
repo=$(realpath "$repo")
[[ -d "$repo/.git" ]] || { echo "Not a Git checkout: $repo" >&2; exit 2; }
cd "$repo"

if git cat-file -e "${baseline}^{commit}" 2>/dev/null; then
	pass "baseline commit exists: $baseline"
else
	fail "baseline commit is missing: $baseline"
fi

if [[ "$(git merge-base HEAD "$baseline" 2>/dev/null || true)" == "$baseline" ]]; then
	pass "HEAD descends from the known-good A1 baseline"
else
	fail "HEAD is not based on $baseline"
fi

protected=(
	config/boards/dshanpi-a1.csc
	extensions/dshanpi-camera.sh
	patch/u-boot/legacy/u-boot-radxa-rk35xx/board_dshanpi-a1/u-boot-add-dshanpi-a1-rk3576-dts.patch
	patch/u-boot/legacy/u-boot-radxa-rk35xx/defconfig/dshanpi-a1-rk3576_defconfig
)
for path in "${protected[@]}"; do
	if [[ ! -f "$path" ]]; then
		fail "protected A1 file is missing: $path"
	elif [[ "$(git show "$baseline:$path" | sha256sum | awk '{print $1}')" == "$(sha256sum "$path" | awk '{print $1}')" ]]; then
		pass "protected A1 file matches baseline: $path"
	else
		fail "protected A1 file differs from baseline: $path"
	fi
done

require_line() {
	local file=$1 line=$2
	if grep -Fqx "$line" "$file"; then
		pass "$file contains: $line"
	else
		fail "$file is missing required line: $line"
	fi
}

cm5_board=config/boards/dshanpi-a1-cm5.csc
if [[ -f "$cm5_board" ]]; then
	require_line "$cm5_board" 'BOARD_NAME="100ASK DShanPI A1 CM5"'
	require_line "$cm5_board" 'BOOT_FDT_FILE="rockchip/rk3576-100ask-dshanpi-a1-cm5.dtb"'
	require_line "$cm5_board" 'ENABLE_EXTENSIONS="rockchip-multimedia,dshanpi-cm5-camera,dshanpi-aic8800"'
	if rg -q 'LINUXFAMILY="rk3576-dshanpi-a1-cm5"' "$cm5_board" &&
		rg -q 'rk3576-dshanpi-a1-cm5-vendor-6\.1' "$cm5_board"; then
		pass "CM5 kernel family and patch layer are isolated"
	else
		fail "CM5 kernel family or patch layer lost isolation"
	fi
else
	fail "CM5 board definition is missing: $cm5_board"
fi

required_paths=(
	extensions/dshanpi-aic8800.sh
	extensions/dshanpi-cm5-camera.sh
	patch/kernel/rk3576-dshanpi-a1-cm5-vendor-6.1/dt/rk3576-100ask-dshanpi-a1-cm5.dts
	patch/kernel/rk3576-dshanpi-a1-cm5-vendor-6.1/dt/rk3576-100ask-a1-cm5-common.dtsi
	patch/kernel/rk3576-dshanpi-a1-cm5-vendor-6.1/dt/rk3576-100ask-a1-cm5-base-v1.dtsi
	patch/kernel/rk3576-dshanpi-a1-cm5-vendor-6.1/dt/rk3576-100ask-a1-cm5-ov13850-3cam.dtsi
	patch/u-boot/legacy/u-boot-radxa-rk35xx/board_dshanpi-a1-cm5/u-boot-add-dshanpi-a1-rk3576-dts.patch
)
for path in "${required_paths[@]}"; do
	[[ -f "$path" ]] && pass "required CM5 path exists: $path" || fail "required CM5 path is missing: $path"
done

if rg -q 'BOARD:-.*dshanpi-a1-cm5' lib/functions/general/apt-utils.sh; then
	pass "APT metadata fallback remains CM5-specific"
else
	fail "APT metadata fallback is not visibly guarded for CM5"
fi
if rg -q 'BOARDFAMILY.*rk35xx' extensions/rockchip-multimedia.sh; then
	pass "Rockchip multimedia recognizes the shared RK35xx board family"
else
	fail "Rockchip multimedia no longer recognizes BOARDFAMILY=rk35xx"
fi

if git diff --check "$baseline"..HEAD && git diff --check && git diff --cached --check; then
	pass "Git whitespace checks passed"
else
	fail "Git whitespace checks failed"
fi

shell_files=(
	config/boards/dshanpi-a1-cm5.csc
	extensions/dshanpi-aic8800.sh
	extensions/dshanpi-cm5-camera.sh
	extensions/dshanpi-repository.sh
	extensions/rockchip-multimedia.sh
	lib/functions/general/apt-utils.sh
	tools/dshanpi-repository/build-client-packages.sh
	tools/dshanpi-repository/prepare-incoming.sh
	tools/dshanpi-repository/publish-local.sh
	tools/dshanpi-repository/repack-camera-engine.sh
	.agents/skills/guard-dshanpi-a1-cm5/scripts/a1_cm5_gate.sh
	.agents/skills/guard-dshanpi-a1-cm5/scripts/inspect-cm5-image.sh
)
existing_shell_files=()
for path in "${shell_files[@]}"; do [[ ! -f "$path" ]] || existing_shell_files+=("$path"); done
if bash -n "${existing_shell_files[@]}"; then
	pass "shell syntax checks passed"
else
	fail "shell syntax checks failed"
fi

if git status --porcelain | rg -q 'lib/tools/common/__pycache__/'; then
	warn "generated __pycache__ is present; keep it out of commits"
fi

if [[ "$mode" == release ]]; then
	[[ "${DSHANPI_RELEASE_APPROVED:-no}" == yes ]] || fail "release approval flag is absent; require explicit user approval"
	branch=$(git branch --show-current)
	[[ "$branch" != main && "$branch" != master && -n "$branch" ]] && pass "release branch is not main/master: $branch" || fail "refusing release from main/master or detached HEAD"
	if [[ -z "$(git status --porcelain --untracked-files=no)" ]]; then pass "tracked worktree is clean"; else fail "tracked worktree is not clean"; fi
	upstream=$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || true)
	if [[ -n "$upstream" && "$(git rev-parse HEAD)" == "$(git rev-parse '@{upstream}')" ]]; then
		pass "local HEAD matches upstream: $upstream"
	else
		fail "local HEAD does not match an upstream ref"
	fi
	if [[ -z "$artifact" ]]; then
		fail "release mode requires an image.img.gz path"
	else
		artifact=$(realpath "$artifact")
		checksum_file="${artifact}.sha"
		[[ -f "$artifact" ]] && pass "release artifact exists: $artifact" || fail "release artifact is missing: $artifact"
		[[ "$(basename "$artifact")" == *Dshanpi-a1-cm5*.img.gz ]] && pass "release artifact name is CM5-specific" || fail "release artifact name is not CM5-specific"
		if [[ -f "$artifact" ]] && gzip --test "$artifact"; then pass "gzip integrity passed"; else fail "gzip integrity failed"; fi
		if [[ -f "$checksum_file" ]] && (cd "$(dirname "$artifact")" && sha256sum -c "$(basename "$checksum_file")"); then
			pass "artifact SHA-256 passed"
		else
			fail "artifact SHA-256 failed or checksum file is missing"
		fi
		if [[ -f "$artifact" && "$(stat -c %s "$artifact")" -le 2147483648 ]]; then pass "artifact is within the 2 GiB GitHub asset limit"; else fail "artifact exceeds the 2 GiB GitHub asset limit"; fi
	fi
fi

if ((failures > 0)); then
	echo "Gate failed with $failures error(s)." >&2
	exit 1
fi
echo "Gate passed: $mode"
