#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat >&2 <<- 'EOF'
	Usage: repack-camera-engine.sh [source-deb] [output-dir] [version]

	Repackage the reviewed RKAIQ vendor binary with safe filesystem modes,
	clean runtime metadata, payload checksums, and no build-host RPATH.
	EOF
	exit 2
}

[[ $# -le 3 ]] || usage

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
workspace=$(cd "${script_dir}/../.." && pwd)
source_deb=${1:-${workspace}/debs/camera/camera_engine_rkaiq_rk3576_arm64.deb}
output_dir=${2:-${workspace}/output/dshanpi-packages}
version=${3:-6.6.3+dshanpi1}
expected_source_sha256="3b5e8ca9c5e84940fee4661675e5d4854bf8ce1c441a0ef87da9ff3ea92d16b7"
source_date_epoch="1687086060"

[[ -f "$source_deb" ]] || { echo "Missing camera package: $source_deb" >&2; exit 2; }
[[ "$version" =~ ^[0-9] ]] || { echo "Package version must begin with a digit: $version" >&2; exit 2; }
dpkg --validate-version "$version" 2> /dev/null || { echo "Invalid Debian package version: $version" >&2; exit 2; }
command -v patchelf >/dev/null || { echo "patchelf is required" >&2; exit 2; }

actual_source_sha256=$(sha256sum "$source_deb" | awk '{print $1}')
[[ "$actual_source_sha256" == "$expected_source_sha256" ]] || {
	echo "Unexpected camera package SHA-256: $actual_source_sha256" >&2
	exit 1
}
[[ "$(dpkg-deb -f "$source_deb" Package)" == "camera-engine-rkaiq" ]] || {
	echo "Unexpected source package name" >&2
	exit 1
}
[[ "$(dpkg-deb -f "$source_deb" Version)" == "6.6.3" ]] || {
	echo "Unexpected source package version" >&2
	exit 1
}
[[ "$(dpkg-deb -f "$source_deb" Architecture)" == "arm64" ]] || {
	echo "Unexpected source package architecture" >&2
	exit 1
}

mkdir -p "$output_dir"
work_dir=$(mktemp -d)
cleanup() {
	[[ -n "${work_dir:-}" && -d "$work_dir" && "$work_dir" == /tmp/* ]] || return 0
	rm -rf -- "$work_dir"
}
trap cleanup EXIT

package_root="$work_dir/package"
mkdir -p "$package_root/DEBIAN"
dpkg-deb --extract "$source_deb" "$package_root"

# The vendor archive ships every directory and nearly every regular file as
# world-writable. Start from conservative package-wide modes, then restore the
# three programs which must be executable.
find "$package_root" -type d -exec chmod 0755 {} +
find "$package_root" -type f -exec chmod 0644 {} +
chmod 0755 \
	"$package_root/etc/init.d/rkaiq_3A.sh" \
	"$package_root/usr/bin/rkaiq_3A_server" \
	"$package_root/usr/bin/rkaiq_tool_server"

# Remove the vendor build machine's /home/... RPATH from all ELF payloads.
while IFS= read -r -d '' payload; do
	if file --brief "$payload" | grep -q '^ELF '; then
		patchelf --remove-rpath "$payload"
		[[ -z "$(patchelf --print-rpath "$payload")" ]] || {
			echo "Failed to remove RPATH from ${payload#${package_root}}" >&2
			exit 1
		}
	fi
done < <(find "$package_root" -type f -print0)

install -d -m 0755 "$package_root/usr/share/doc/camera-engine-rkaiq"
cat > "$package_root/usr/share/doc/camera-engine-rkaiq/copyright" <<- EOF
	Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
	Upstream-Name: camera-engine-rkaiq
	Source: https://github.com/rockchip-linux/camera_engine_rkaiq
	Comment: This package repacks the reviewed DShanPI vendor binary archive.
	 The original archive SHA-256 is ${expected_source_sha256}.
	 The upstream archive does not include complete machine-readable licensing
	 metadata; licensing must be reviewed before a production repository release.
EOF

installed_size=$(du -sk --exclude=DEBIAN "$package_root" | awk '{print $1}')
cat > "$package_root/DEBIAN/control" <<- EOF
	Package: camera-engine-rkaiq
	Source: camera-engine-rkaiq
	Version: ${version}
	Architecture: arm64
	Maintainer: DShanPI <support@dshanpi.com>
	Installed-Size: ${installed_size}
	Depends: libc6, libdrm2, libgcc-s1, libstdc++6, systemd
	Section: libs
	Priority: optional
	Homepage: https://github.com/rockchip-linux/camera_engine_rkaiq
	Description: Rockchip RK3576 RKAIQ camera engine (DShanPI repack)
	 Vendor RKAIQ runtime, development files and camera service for RK3576,
	 repackaged with safe filesystem modes and sanitized runtime metadata.
EOF

(
	cd "$package_root"
	find . -type f ! -path './DEBIAN/*' -print0 |
		sort -z |
		xargs -0 md5sum |
		sed 's#  \./#  #' > DEBIAN/md5sums
)
chmod 0644 "$package_root/DEBIAN/control" "$package_root/DEBIAN/md5sums"

# Keep this derived package byte-for-byte reproducible across builds.
find "$package_root" -exec touch -h -d "@${source_date_epoch}" {} +
export SOURCE_DATE_EPOCH="$source_date_epoch"

output_deb="$output_dir/camera-engine-rkaiq_${version}_arm64.deb"
dpkg-deb --root-owner-group --build "$package_root" "$output_deb" >/dev/null

[[ "$(dpkg-deb -f "$output_deb" Version)" == "$version" ]] || {
	echo "Repacked package version verification failed" >&2
	exit 1
}
if dpkg-deb -c "$output_deb" | awk '
	$1 ~ /^[-d]/ && substr($1, 9, 1) == "w" { found = 1 }
	END { exit(found ? 0 : 1) }
'; then
	echo "Repacked package still contains world-writable payloads" >&2
	exit 1
fi

sha256sum "$output_deb"
