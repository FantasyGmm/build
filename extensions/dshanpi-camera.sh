#!/bin/bash
#
# Extension for installing DShanPI Camera Engine packages
#

function post_repo_customize_image__z_dshanpi_camera_install() {
	display_alert "$BOARD" "Installing DShanPI Camera Engine (after rockchip-multimedia)" "info"

	# Check if we are on a supported board/family if necessary, or just run
	# Since this extension is manually enabled in dshanpi-a1.csc, we assume it's desired.

	local deb_file="$SRC/debs/camera/camera_engine_rkaiq_rk3576_arm64.deb"

	if [[ -f "$deb_file" ]]; then
		# Copy deb to chroot
		cp "$deb_file" "$SDCARD/tmp/"
		
		# Install deb
		# Using chroot_sdcard wrapper for consistency
		chroot_sdcard dpkg -i "/tmp/camera_engine_rkaiq_rk3576_arm64.deb"
		
		# Fix potential missing dependencies
		chroot_sdcard_apt_get install -f
		
		# Cleanup
		chroot_sdcard rm "/tmp/camera_engine_rkaiq_rk3576_arm64.deb"
		
		display_alert "$BOARD" "DShanPI Camera Engine installation complete" "info"
	else
		display_alert "$BOARD" "Camera engine deb not found at $deb_file" "wrn"
	fi

	return 0
}
