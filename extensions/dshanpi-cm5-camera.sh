#!/usr/bin/env bash

# Install the DShanPI camera engine first, then add the CM5-specific OV13850
# calibration pinned to the same SDK revision used for the device tree.
function post_repo_customize_image__z_dshanpi_cm5_camera_install() {
	display_alert "$BOARD" "Installing DShanPI CM5 Camera Engine" "info"

	local camera_version="6.6.3+dshanpi1"
	local camera_output_dir="$SRC/output/dshanpi-packages"
	local deb_file="$camera_output_dir/camera-engine-rkaiq_${camera_version}_arm64.deb"
	local iq_name="ov13850_ZC-OV13850R2A-V1_Largan-50064B31.json"
	local iq_url="https://raw.githubusercontent.com/dshanpi/DshanPi-A1_CM5-BuildrootSDK/4f45e4fca8f41aad5919a371d7c8e6dc6d907d73/external/camera_engine_rkaiq/rkaiq/iqfiles/isp39/${iq_name}"
	local iq_sha256="361f854402a0b156eb47c81a75b7d162251d694f82e110ca5500d4d533de9697"
	local iq_cache="$SRC/cache/${iq_name}"

	display_alert "Repacking reviewed camera engine package" "$camera_version" "info"
	"$SRC/tools/dshanpi-repository/repack-camera-engine.sh" \
		"$SRC/debs/camera/camera_engine_rkaiq_rk3576_arm64.deb" \
		"$camera_output_dir" "$camera_version"

	cp "$deb_file" "$SDCARD/tmp/"
	use_clean_environment="yes" chroot_sdcard_apt_get_install "/tmp/$(basename "$deb_file")"

	if [[ ! -f "$iq_cache" ]] || ! echo "$iq_sha256  $iq_cache" | sha256sum --check --status; then
		curl --fail --location --retry 3 --output "$iq_cache" "$iq_url"
	fi
	echo "$iq_sha256  $iq_cache" | sha256sum --check --status || return 1
	install -D -m 0644 "$iq_cache" "$SDCARD/etc/iqfiles/$iq_name"

	chroot_sdcard rm "/tmp/$(basename "$deb_file")"
}
