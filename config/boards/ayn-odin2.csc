# Generate kernel and rootfs image for Qcom ABL Custom booting
declare -g BOARD_NAME="Ayn Odin2"
declare -g BOARD_MAINTAINER="FantasyGmm"
declare -g BOARDFAMILY="sm8550"
declare -g KERNEL_TARGET="current,edge"
declare -g KERNEL_TEST_TARGET="edge"
declare -g EXTRAWIFI="no"
declare -g BOOTCONFIG="none"
declare -g BOOTFS_TYPE="fat"
declare -g BOOTSIZE="256"
declare -g BOOTIMG_CMDLINE_EXTRA="clk_ignore_unused pd_ignore_unused rw quiet"
declare -g IMAGE_PARTITION_TABLE="gpt"

# Use the full firmware, complete linux-firmware plus Armbian's
declare -g BOARD_FIRMWARE_INSTALL="-full"
declare -g DESKTOP_AUTOLOGIN="yes"

function ayn-odin2_is_userspace_supported() {
	[[ "${RELEASE}" == "jammy" ]] && return 0
	[[ "${RELEASE}" == "trixie" ]] && return 0
	[[ "${RELEASE}" == "noble" ]] && return 0
	return 1
}

function post_family_tweaks_bsp__ayn-odin2_firmware() {
	display_alert "$BOARD" "Install firmwares for ayn odin2" "info"

	# alsa-ucm-conf profile for Ayn Odin2
	mkdir -p $destination/usr/share/alsa/ucm2/conf.d/sm8550
	install -Dm644 $SRC/packages/bsp/ayn-odin2/AYN-Odin2.conf $destination/usr/share/alsa/ucm2/AYN/Odin2/AYN-Odin2.conf
	install -Dm644 $SRC/packages/bsp/ayn-odin2/HiFi.conf $destination/usr/share/alsa/ucm2/AYN/Odin2/HiFi.conf
	ln -sfv ../../AYN/Odin2/AYN-Odin2.conf \
		"$destination/usr/share/alsa/ucm2/conf.d/sm8550/AYN-Odin2.conf"

	# Bluetooth MAC addr setup service
	mkdir -p $destination/usr/local/bin/
	mkdir -p $destination/usr/lib/systemd/system/
	install -Dm655 $SRC/packages/bsp/generate-bt-mac-addr/bt-fixed-mac.sh $destination/usr/local/bin/
	install -Dm644 $SRC/packages/bsp/generate-bt-mac-addr/bt-fixed-mac.service $destination/usr/lib/systemd/system/

	# Kernel postinst script to update abl boot partition
	install -Dm655 $SRC/packages/bsp/ayn-odin2/zz-update-abl-kernel $destination/etc/kernel/postinst.d/

	return 0
}

function post_family_tweaks__enable_services() {
	if ! ayn-odin2_is_userspace_supported; then
		if [[ "${RELEASE}" != "" ]]; then
			display_alert "Missing userspace for ${BOARD}" "${RELEASE} does not have the userspace necessary to support the ${BOARD}" "warn"
		fi
		return 0
	fi

	if [[ "${RELEASE}" == "jammy" ]] || [[ "${RELEASE}" == "noble" ]]; then
		display_alert "Adding Mesa PPA For Ubuntu " "${BOARD}" "info"
		do_with_retries 3 chroot_sdcard add-apt-repository ppa:liujianfeng1994/qcom-mainline --yes --no-update
	fi

	# We need unudhcpd from armbian repo, so enable it
	mv "${SDCARD}"/etc/apt/sources.list.d/armbian.sources.disabled "${SDCARD}"/etc/apt/sources.list.d/armbian.sources

	do_with_retries 3 chroot_sdcard_apt_get_update
	display_alert "$BOARD" "Installing board tweaks" "info"
	do_with_retries 3 chroot_sdcard_apt_get_install alsa-ucm-conf qbootctl qrtr-tools unudhcpd mkbootimg
	# disable armbian repo back
	mv "${SDCARD}"/etc/apt/sources.list.d/armbian.sources "${SDCARD}"/etc/apt/sources.list.d/armbian.sources.disabled
	do_with_retries 3 chroot_sdcard_apt_get_update
	chroot_sdcard systemctl enable qbootctl.service
	chroot_sdcard systemctl enable bt-fixed-mac.service

	# Add Gamepad udev rule
	echo 'SUBSYSTEM=="input", ATTRS{name}=="Ayn Odin2 Gamepad", MODE="0666", ENV{ID_INPUT_JOYSTICK}="1"' > "${SDCARD}"/etc/udev/rules.d/99-ignore-gamepad.rules
	# Not Any driver support suspend mode
	chroot_sdcard systemctl mask suspend.target

	cp $SRC/packages/bsp/ayn-odin2/LinuxLoader.cfg "${SDCARD}"/boot/

	return 0
}

function post_family_tweaks__preset_configs() {
	display_alert "$BOARD" "preset configs for rootfs" "info"
	# Set PRESET_NET_CHANGE_DEFAULTS to 1 to apply any network related settings below
	echo "PRESET_NET_CHANGE_DEFAULTS=1" > "${SDCARD}"/root/.not_logged_in_yet

	# Enable WiFi or Ethernet.
	#      NB: If both are enabled, WiFi will take priority and Ethernet will be disabled.
	echo "PRESET_NET_ETHERNET_ENABLED=0" >> "${SDCARD}"/root/.not_logged_in_yet
	echo "PRESET_NET_WIFI_ENABLED=1" >> "${SDCARD}"/root/.not_logged_in_yet

	# Preset user default shell, you can choose bash or zsh
	echo "PRESET_USER_SHELL=zsh" >> "${SDCARD}"/root/.not_logged_in_yet

	# Set PRESET_CONNECT_WIRELESS=y if you want to connect wifi manually at first login
	echo "PRESET_CONNECT_WIRELESS=n" >> "${SDCARD}"/root/.not_logged_in_yet

	# Set SET_LANG_BASED_ON_LOCATION=n if you want to choose "Set user language based on your location?" with "n" at first login
	echo "SET_LANG_BASED_ON_LOCATION=y" >> "${SDCARD}"/root/.not_logged_in_yet

	# Preset default locale
	echo "PRESET_LOCALE=en_US.UTF-8" >> "${SDCARD}"/root/.not_logged_in_yet

	# Preset timezone
	echo "PRESET_TIMEZONE=Etc/UTC" >> "${SDCARD}"/root/.not_logged_in_yet

	# Preset root password
	echo "PRESET_ROOT_PASSWORD=admin" >> "${SDCARD}"/root/.not_logged_in_yet

	# Preset username
	echo "PRESET_USER_NAME=odin" >> "${SDCARD}"/root/.not_logged_in_yet

	# Preset user password
	echo "PRESET_USER_PASSWORD=admin" >> "${SDCARD}"/root/.not_logged_in_yet

	# Preset user default realname
	echo "PRESET_DEFAULT_REALNAME=Odin" >> "${SDCARD}"/root/.not_logged_in_yet
}

function post_family_tweaks_bsp__firmware_in_initrd() {
	display_alert "Adding to bsp-cli" "${BOARD}: firmware in initrd" "info"
	declare file_added_to_bsp_destination # Will be filled in by add_file_from_stdin_to_bsp_destination
	# Using odin2's firmware for now
	add_file_from_stdin_to_bsp_destination "/etc/initramfs-tools/hooks/ayn-odin2-firmware" <<- 'FIRMWARE_HOOK'
		#!/bin/bash
		[[ "$1" == "prereqs" ]] && exit 0
		. /usr/share/initramfs-tools/hook-functions
		for f in /lib/firmware/qcom/sm8550/ayn/odin2portal/* ; do
			add_firmware "${f#/lib/firmware/}"
		done
		add_firmware "qcom/a740_sqe.fw" # Extra one for dpu
		add_firmware "qcom/gmu_gen70200.bin" # Extra one for gpu
		add_firmware "qcom/vpu/vpu30_p4.mbn" # Extra one for vpu
		# Extra one for wifi
		for f in /lib/firmware/ath12k/WCN7850/hw2.0/* ; do
			add_firmware "${f#/lib/firmware/}"
		done
		# Extra one for bt
		for f in /lib/firmware/qca/* ; do
			add_firmware "${f#/lib/firmware/}"
		done
	FIRMWARE_HOOK
	run_host_command_logged chmod -v +x "${file_added_to_bsp_destination}"
}

function pre_umount_final_image__update_ABL_settings() {
	if [ -z "$BOOTFS_TYPE" ]; then
		return 0
	fi
	display_alert "Update ABL settings for " "${BOARD}" "info"
	uuid_line=$(head -n 1 "${SDCARD}"/etc/fstab)
	rootfs_image_uuid=$(echo "${uuid_line}" | awk '{print $1}' | awk -F '=' '{print $2}')
	initrd_name=$(find "${SDCARD}/boot/" -type f -name "config-*" | sed 's/.*config-//')
	sed -i "s/UUID_PLACEHOLDER/${rootfs_image_uuid}/g" "${MOUNT}"/boot/LinuxLoader.cfg
	sed -i "s/INITRD_PLACEHOLDER/${initrd_name}/g" "${MOUNT}"/boot/LinuxLoader.cfg
}
