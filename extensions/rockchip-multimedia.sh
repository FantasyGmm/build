#!/bin/bash
#
# SPDX-License-Identifier: GPL-2.0
#
# Copyright (c) 2013-2023 Igor Pecovnik, igor@armbian.com
#
# This file is a part of the Armbian Build Framework
# https://github.com/armbian/build/
#
# Extension for installing Rockchip multimedia packages (MPP, RGA, GStreamer)
# This extension handles the proper installation order and dependencies

function extension_prepare_config__rockchip_multimedia() {
	display_alert "Preparing Rockchip multimedia extension" "rockchip-multimedia" "info"

	# Only enable for Rockchip families
	if [[ "${LINUXFAMILY}" != "rockchip64" && "${LINUXFAMILY}" != "rk322x" && "${LINUXFAMILY}" != "rk3399" && "${LINUXFAMILY}" != "rockchip" && "${LINUXFAMILY}" != "rk35xx" ]]; then
		display_alert "Rockchip multimedia extension" "Not a Rockchip family, skipping" "info"
		return 0
	fi

	# Check if deb packages exist
	local deb_dir="${SRC}/debs"
	if [[ ! -d "${deb_dir}/mpp" || ! -d "${deb_dir}/rga" || ! -d "${deb_dir}/gsteamer" ]]; then
		display_alert "Rockchip multimedia packages" "Missing deb packages in ${deb_dir}" "wrn"
		return 0
	fi

	display_alert "Rockchip multimedia extension" "Will install MPP, RGA, and GStreamer packages" "info"
}

function post_repo_customize_image__install_rockchip_multimedia() {
	display_alert "Installing Rockchip multimedia packages" "MPP, RGA, GStreamer" "info"

	# Only proceed for Rockchip families
	if [[ "${LINUXFAMILY}" != "rockchip64" && "${LINUXFAMILY}" != "rk322x" && "${LINUXFAMILY}" != "rk3399" && "${LINUXFAMILY}" != "rockchip" && "${LINUXFAMILY}" != "rk35xx" ]]; then
		return 0
	fi

	local deb_dir="${SRC}/debs"

	# Check if packages exist
	if [[ ! -d "${deb_dir}/mpp" || ! -d "${deb_dir}/rga" || ! -d "${deb_dir}/gsteamer" ]]; then
		display_alert "Rockchip multimedia packages" "Missing deb packages, skipping installation" "wrn"
		return 0
	fi

	# Install build dependencies first
	display_alert "Installing build dependencies" "for Rockchip multimedia" "info"
	
	# Install dependencies that are not already in Armbian base
	# Note: build-essential is already included in Armbian CLI packages
	local additional_deps=()
	
	# Check and add dependencies that might not be in base system
	local deps_to_check=("debhelper" "cmake" "dh-exec" "fakeroot" "libdrm-dev" "meson" "pkg-config" "libx11-dev")
	
	for dep in "${deps_to_check[@]}"; do
		if ! chroot_sdcard dpkg -l | grep -q "^ii.*${dep}"; then
			additional_deps+=("${dep}")
		fi
	done
	
	if [[ ${#additional_deps[@]} -gt 0 ]]; then
		display_alert "Installing additional dependencies" "${additional_deps[*]}" "info"
		chroot_sdcard_apt_get_install "${additional_deps[@]}"
	fi

	# Install GStreamer development packages and tools
	display_alert "Installing GStreamer development packages" "libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev gstreamer1.0-tools" "info"
	chroot_sdcard_apt_get_install libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev gstreamer1.0-tools

	# Copy deb packages to chroot
	display_alert "Copying deb packages to chroot" "MPP, RGA, GStreamer" "info"
	cp "${deb_dir}"/mpp/*.deb "${SDCARD}/tmp/"
	cp "${deb_dir}"/rga/*.deb "${SDCARD}/tmp/"
	cp "${deb_dir}"/gsteamer/*.deb "${SDCARD}/tmp/"

	# Install MPP packages in correct order
	display_alert "Installing MPP packages" "librockchip-mpp1, librockchip-vpu0, librockchip-mpp-dev, rockchip-mpp-demos" "info"
	chroot_sdcard dpkg -i /tmp/librockchip-mpp1_1.5.0-1_arm64.deb \
						/tmp/librockchip-vpu0_1.5.0-1_arm64.deb \
						/tmp/librockchip-mpp-dev_1.5.0-1_arm64.deb \
						/tmp/rockchip-mpp-demos_1.5.0-1_arm64.deb

	# Fix any dependency issues after MPP installation
	chroot_sdcard_apt_get install -f

	# Install RGA packages in correct order
	display_alert "Installing RGA packages" "librga2, librga-dev" "info"
	chroot_sdcard dpkg -i /tmp/librga2_2.2.0-1_arm64.deb \
						/tmp/librga-dev_2.2.0-1_arm64.deb

	# Fix any dependency issues after RGA installation
	chroot_sdcard_apt_get install -f

	# Install GStreamer Rockchip plugin (depends on MPP and RGA)
	display_alert "Installing GStreamer Rockchip plugin" "gstreamer1.0-rockchip1" "info"
	chroot_sdcard dpkg -i /tmp/gstreamer1.0-rockchip1_1.14-4_arm64.deb

	# Fix any dependency issues after GStreamer installation
	chroot_sdcard_apt_get install -f

	# Clean up temporary files
	display_alert "Cleaning up" "removing temporary deb files" "info"
	chroot_sdcard rm -f /tmp/*.deb

	# Verify installation
	display_alert "Verifying installation" "checking installed packages" "info"
	if chroot_sdcard dpkg -l | grep -q librockchip-mpp1 && \
	   chroot_sdcard dpkg -l | grep -q librga2 && \
	   chroot_sdcard dpkg -l | grep -q gstreamer1.0-rockchip1; then
		display_alert "Rockchip multimedia installation" "SUCCESS" "info"
	else
		display_alert "Rockchip multimedia installation" "FAILED - some packages missing" "err"
	fi
}

# Extension metadata
EXTENSION_NAME="rockchip-multimedia"
EXTENSION_DESCRIPTION="Install Rockchip multimedia packages (MPP, RGA, GStreamer)"
EXTENSION_MAINTAINER="Armbian Community"
EXTENSION_VERSION="1.0"