#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat >&2 <<- 'EOF'
	Usage: sudo inspect-cm5-image.sh [--require-repository] <image.img>

	Attach and mount an uncompressed DShanPI A1 CM5 image read-only, verify its
	boot DTB, package namespace, AIC8800 modules, camera payload and DTS content,
	then always unmount and detach it.
	EOF
	exit 2
}

require_repository=no
if [[ ${1:-} == --require-repository ]]; then
	require_repository=yes
	shift
fi
[[ $# -eq 1 ]] || usage
[[ $EUID -eq 0 ]] || { echo "Run this script with sudo" >&2; exit 2; }

image_path=$(realpath "$1")
[[ -f "$image_path" && "$image_path" == *.img ]] || { echo "Expected an uncompressed .img: $image_path" >&2; exit 2; }
for command in losetup lsblk mount umount mountpoint dtc sha256sum; do
	command -v "$command" >/dev/null || { echo "Required command not found: $command" >&2; exit 2; }
done

mount_dir=$(mktemp -d /tmp/dshanpi-cm5-image.XXXXXX)
dts_file=$(mktemp /tmp/dshanpi-cm5-dtb.XXXXXX.dts)
warning_file=$(mktemp /tmp/dshanpi-cm5-dtc.XXXXXX.log)
loop_device=

cleanup() {
	if mountpoint -q "$mount_dir"; then umount "$mount_dir" || true; fi
	[[ -z "$loop_device" ]] || losetup -d "$loop_device" 2>/dev/null || true
	rm -f -- "$dts_file" "$warning_file"
	rmdir "$mount_dir" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

if [[ -f "${image_path}.sha" ]]; then
	(cd "$(dirname "$image_path")" && sha256sum --check "$(basename "${image_path}.sha")")
fi

loop_device=$(losetup --read-only --partscan --find --show "$image_path")
udevadm settle 2>/dev/null || true
root_partition=$(lsblk -lnpo NAME,FSTYPE "$loop_device" | awk '$2 ~ /^ext[234]$/ {print $1; exit}')
[[ -n "$root_partition" ]] || { echo "No ext root partition found in $image_path" >&2; exit 1; }
mount -o ro,noload "$root_partition" "$mount_dir"

expected_fdt='rockchip/rk3576-100ask-dshanpi-a1-cm5.dtb'
grep -Fqx "fdtfile=${expected_fdt}" "$mount_dir/boot/armbianEnv.txt" || {
	echo "armbianEnv.txt does not select $expected_fdt" >&2
	exit 1
}
dtb_path="$mount_dir/boot/dtb/$expected_fdt"
[[ -f "$dtb_path" ]] || { echo "CM5 DTB missing: $expected_fdt" >&2; exit 1; }

package_installed() {
	local wanted=$1
	awk -v wanted="$wanted" '
		BEGIN { RS = "" }
		$0 ~ "(^|\\n)Package: " wanted "\\n" && $0 ~ "(^|\\n)Status: install ok installed(\\n|$)" { found = 1 }
		END { exit(found ? 0 : 1) }
	' "$mount_dir/var/lib/dpkg/status"
}

required_packages=(
	linux-image-vendor-rk3576-dshanpi-a1-cm5
	linux-dtb-vendor-rk3576-dshanpi-a1-cm5
	linux-headers-vendor-rk3576-dshanpi-a1-cm5
	aic8800-sdio-dkms
	aic8800-firmware
	camera-engine-rkaiq
	gstreamer1.0-rockchip1
)
for package in "${required_packages[@]}"; do
	package_installed "$package" || { echo "Required image package is not installed: $package" >&2; exit 1; }
done

if [[ "$require_repository" == yes ]]; then
	package_installed dshanpi-archive-keyring || { echo "Repository keyring is not installed" >&2; exit 1; }
	package_installed dshanpi-a1-cm5-repository || { echo "Repository client is not installed" >&2; exit 1; }
	source_file="$mount_dir/etc/apt/sources.list.d/dshanpi.sources"
	[[ -f "$source_file" ]] || { echo "DShanPI repository source is missing" >&2; exit 1; }
	grep -Eq '^URIs: https://.+/dshanpi-a1-cm5/stable$' "$source_file" || {
		echo "Repository source is not an HTTPS A1 CM5 stable URL" >&2
		exit 1
	}
fi

kernel_release=$(find "$mount_dir/lib/modules" -mindepth 1 -maxdepth 1 -type d -name '*rk3576-dshanpi-a1-cm5*' -printf '%f\n' | head -n 1)
[[ -n "$kernel_release" ]] || { echo "CM5 kernel module directory is missing" >&2; exit 1; }
for module in aic8800_bsp_sdio aic8800_btlpm_sdio aic8800_fdrv_sdio; do
	find "$mount_dir/lib/modules/$kernel_release" -type f -name "${module}.ko*" -print -quit | grep -q . || {
		echo "AIC8800 module is missing: $module" >&2
		exit 1
	}
done

iq_name='ov13850_ZC-OV13850R2A-V1_Largan-50064B31.json'
iq_path=$(find "$mount_dir/etc" -type f -name "$iq_name" -print -quit)
[[ -n "$iq_path" ]] || { echo "Camera IQ file is missing: $iq_name" >&2; exit 1; }
echo '361f854402a0b156eb47c81a75b7d162251d694f82e110ca5500d4d533de9697  '"$iq_path" | sha256sum --check --status || {
	echo "Camera IQ checksum mismatch: $iq_path" >&2
	exit 1
}

dtc -I dtb -O dts "$dtb_path" > "$dts_file" 2> "$warning_file"
camera_count=$(grep -Fc 'compatible = "ovti,ov13850"' "$dts_file")
[[ "$camera_count" -eq 3 ]] || { echo "Expected 3 OV13850 nodes, found $camera_count" >&2; exit 1; }
grep -Fq 'wifi_chip_type = "aic8800"' "$dts_file" || { echo "AIC8800 DTS property is missing" >&2; exit 1; }

printf '[PASS] image: %s\n' "$image_path"
printf '[PASS] root partition mounted read-only: %s\n' "$root_partition"
printf '[PASS] DTB: %s; OV13850 nodes: %s\n' "$expected_fdt" "$camera_count"
printf '[PASS] kernel: %s; AIC8800 modules: 3\n' "$kernel_release"
printf '[PASS] camera IQ SHA-256 verified\n'
[[ "$require_repository" == no ]] || printf '[PASS] signed-repository client configuration present\n'
printf '[INFO] dtc emitted %s warning line(s); review changes against the recorded vendor warning\n' "$(wc -l < "$warning_file")"
