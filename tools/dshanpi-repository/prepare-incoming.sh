#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat >&2 <<- 'EOF'
	Usage: prepare-incoming.sh <release-version> <client-package-dir> [incoming-dir]

	Collect one unambiguous copy of every package required for an A1 CM5 release.
	Core Armbian packages must carry <release-version>; base-files must begin with
	that version. Pinned AIC8800 packages are downloaded and checksum-verified.
	EOF
	exit 2
}

[[ $# -ge 2 && $# -le 3 ]] || usage
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
workspace=$(cd "${script_dir}/../.." && pwd)
release_version=$1
client_dir=$(realpath "$2")
incoming_dir=$(realpath -m "${3:-${workspace}/output/dshanpi-repository/incoming/${release_version}}")
package_cache="${workspace}/output/dshanpi-packages"
required_packages="${script_dir}/required-packages.txt"

[[ "$release_version" =~ ^[0-9] ]] || { echo "Invalid release version: $release_version" >&2; exit 2; }
dpkg --validate-version "$release_version" 2> /dev/null || { echo "Invalid release version: $release_version" >&2; exit 2; }
[[ -d "$client_dir" ]] || { echo "Missing client package directory: $client_dir" >&2; exit 2; }
if [[ -d "$incoming_dir" ]] && find "$incoming_dir" -mindepth 1 -print -quit | grep -q .; then
	echo "Incoming directory must be empty: $incoming_dir" >&2
	exit 2
fi
incoming_parent=$(dirname "$incoming_dir")
mkdir -p "$incoming_parent" "$package_cache"
staging_dir=$(mktemp -d "${incoming_parent}/.dshanpi-incoming-${release_version}.XXXXXX")
cleanup() {
	[[ -d "$staging_dir" && "${staging_dir##*/}" == .dshanpi-incoming-* ]] || return 0
	rm -rf -- "$staging_dir"
}
trap cleanup EXIT

aic_version='5.0+git20260123.5f7be68d-8'
aic_base_url="https://github.com/radxa-pkg/aic8800/releases/download/${aic_version}"
download_checked() {
	local name=$1 expected=$2 destination
	destination="${package_cache}/${name}"
	if [[ ! -f "$destination" ]] || ! echo "$expected  $destination" | sha256sum --check --status; then
		curl --fail --location --retry 3 --connect-timeout 30 --output "${destination}.partial" "${aic_base_url}/${name}"
		echo "$expected  ${destination}.partial" | sha256sum --check --status || {
			rm -f -- "${destination}.partial"
			echo "Checksum mismatch: $name" >&2
			exit 1
		}
		mv "${destination}.partial" "$destination"
	fi
}
download_checked "aic8800-sdio-dkms_${aic_version}_all.deb" 'ffe5ffd3ece88ec15b61afebeeda19f35b1024e4975fb14f59734bdbc0df72e9'
download_checked "aic8800-firmware_${aic_version}_all.deb" '5f58bc002f4e43c683e36a40cbd1fb9fb26633bfe998ffee5b1fbd42a0400eb7'

# Build the sanitized camera package from the pinned vendor input before
# selecting candidates so the unsafe original archive can never be chosen.
"${script_dir}/repack-camera-engine.sh" \
	"${workspace}/debs/camera/camera_engine_rkaiq_rk3576_arm64.deb" "$package_cache" >/dev/null

declare -a search_roots=(
	"${workspace}/output/debs"
	"${workspace}/debs/gsteamer"
	"${workspace}/debs/mpp"
	"${workspace}/debs/rga"
	"$package_cache"
	"$client_dir"
)

matches_release() {
	local package=$1 version=$2
	case "$package" in
		base-files) [[ "$version" == "${release_version}-"* ]] ;;
		armbian-bsp-cli-dshanpi-a1-cm5-vendor | armbian-bsp-desktop-dshanpi-a1-cm5-vendor | \
		linux-image-vendor-rk3576-dshanpi-a1-cm5 | linux-dtb-vendor-rk3576-dshanpi-a1-cm5 | \
		linux-headers-vendor-rk3576-dshanpi-a1-cm5) [[ "$version" == "$release_version" ]] ;;
		camera-engine-rkaiq) dpkg --compare-versions "$version" ge '6.6.3+dshanpi1' ;;
		*) return 0 ;;
	esac
}

manifest="$staging_dir/MANIFEST.source"
: > "$manifest"
while read -r required_package required_arch extra; do
	[[ -z "$required_package" || "$required_package" == \#* ]] && continue
	[[ -z "${extra:-}" ]] || { echo "Invalid required package line" >&2; exit 1; }
	declare -a candidates=()
	while IFS= read -r -d '' candidate; do
		[[ "$(dpkg-deb -f "$candidate" Package 2> /dev/null || true)" == "$required_package" ]] || continue
		[[ "$(dpkg-deb -f "$candidate" Architecture)" == "$required_arch" ]] || continue
		candidate_version=$(dpkg-deb -f "$candidate" Version)
		matches_release "$required_package" "$candidate_version" || continue
		candidates+=("$candidate")
	done < <(find "${search_roots[@]}" -type f -name '*.deb' -print0)

	((${#candidates[@]} > 0)) || { echo "No candidate for $required_package/$required_arch" >&2; exit 1; }
	selected=${candidates[0]}
	selected_version=$(dpkg-deb -f "$selected" Version)
	selected_digest=$(sha256sum "$selected" | awk '{print $1}')
	for candidate in "${candidates[@]:1}"; do
		candidate_version=$(dpkg-deb -f "$candidate" Version)
		candidate_digest=$(sha256sum "$candidate" | awk '{print $1}')
		[[ "$candidate_version" == "$selected_version" && "$candidate_digest" == "$selected_digest" ]] || {
			echo "Ambiguous candidates for $required_package/$required_arch:" >&2
			printf '  %s\n' "${candidates[@]}" >&2
			exit 1
		}
	done
	destination="$staging_dir/${required_package}_${selected_version}_${required_arch}.deb"
	cp -a "$selected" "$destination"
	printf '%s  %s  %s\n' "$selected_digest" "${selected#${workspace}/}" "$(basename "$destination")" >> "$manifest"
done < "$required_packages"

[[ ! -d "$incoming_dir" ]] || rmdir "$incoming_dir"
mv "$staging_dir" "$incoming_dir"
trap - EXIT
echo "Prepared $(find "$incoming_dir" -maxdepth 1 -type f -name '*.deb' | wc -l) packages in $incoming_dir"
echo "Review source manifest: $incoming_dir/MANIFEST.source"
