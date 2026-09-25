#!/usr/bin/env bash

# DShanPi A1 CM5 AIC8800D80 integration.  The binary packages are pinned to a
# reviewed upstream packaging revision; DShanPi-specific module options,
# firmware layout, UART and GPIO wiring live in the CM5 board definition.

function extension_finish_config__dshanpi_aic8800_kernel_headers() {
	if [[ "${KERNEL_HAS_WORKING_HEADERS}" != "yes" ]]; then
		display_alert "Kernel version has no working headers package" \
			"skipping DShanPi AIC8800 DKMS for kernel v${KERNEL_MAJOR_MINOR}" "warn"
		return 0
	fi

	declare -g INSTALL_HEADERS="yes"
	display_alert "Forcing INSTALL_HEADERS=yes; for DShanPi AIC8800 DKMS" \
		"${EXTENSION}" "debug"
}

function post_install_kernel_debs__dshanpi_aic8800_dkms() {
	[[ "${INSTALL_HEADERS}" != "yes" ]] || [[ "${KERNEL_HAS_WORKING_HEADERS}" != "yes" ]] && return 0

	local version="5.0+git20260123.5f7be68d-8"
	local base_url="https://github.com/radxa-pkg/aic8800/releases/download/${version}"
	local dkms_name="aic8800-sdio-dkms_${version}_all.deb"
	local firmware_name="aic8800-firmware_${version}_all.deb"
	local dkms_sha256="ffe5ffd3ece88ec15b61afebeeda19f35b1024e4975fb14f59734bdbc0df72e9"
	local firmware_sha256="5f58bc002f4e43c683e36a40cbd1fb9fb26633bfe998ffee5b1fbd42a0400eb7"

	display_alert "Installing pinned AIC8800D80 SDIO stack" "${version}" "info"
	run_host_command_logged curl --fail --location --retry 3 --connect-timeout 30 \
		--output "${SDCARD}/tmp/${dkms_name}" "${base_url}/${dkms_name}"
	run_host_command_logged curl --fail --location --retry 3 --connect-timeout 30 \
		--output "${SDCARD}/tmp/${firmware_name}" "${base_url}/${firmware_name}"

	echo "${dkms_sha256}  ${SDCARD}/tmp/${dkms_name}" | sha256sum --check --status || return 1
	echo "${firmware_sha256}  ${SDCARD}/tmp/${firmware_name}" | sha256sum --check --status || return 1

	declare -ag if_error_find_files_sdcard=("/var/lib/dkms/aic8800*/*/build/*.log")
	use_clean_environment="yes" chroot_sdcard_apt_get_install \
		"/tmp/${dkms_name} /tmp/${firmware_name}"
	chroot_sdcard rm "/tmp/${dkms_name}" "/tmp/${firmware_name}"
}
