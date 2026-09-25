# Rockchip RK3576 SoC octa core 4-32GB SoC 2*GBe eMMC USB3 NvME WIFI
BOARD_NAME="100ASK DShanPI A1 CM5"
BOARDFAMILY="rk35xx"
BOARD_MAINTAINER=""
BOOTCONFIG="dshanpi-a1-rk3576_defconfig"
KERNEL_TARGET="vendor"
KERNEL_TEST_TARGET="vendor"
FULL_DESKTOP="yes"
BOOT_LOGO="desktop"
BOOT_FDT_FILE="rockchip/rk3576-100ask-dshanpi-a1-cm5.dtb"
BOOT_SCENARIO="spl-blobs"
DDR_BLOB="rk35/rk3576_ddr_lp4_2112MHz_lp5_2736MHz_v1.09.bin"
BL31_BLOB="rk35/rk3576_bl31_v1.20.elf"
BL32_BLOB="rk35/rk3576_bl32_v1.06.bin"
IMAGE_PARTITION_TABLE="gpt"
DESKTOP_AUTOLOGIN="yes"

# Define initial audio state file
ASOUND_STATE="asound.state.dshanpi-a1"

# Enable Rockchip multimedia packages, DShanPI Camera and AIC8800 SDIO support
ENABLE_EXTENSIONS="rockchip-multimedia,dshanpi-cm5-camera,dshanpi-aic8800"
PACKAGE_LIST_BOARD="rfkill bluetooth bluez bluez-tools"

# Disable official Armbian apt repository to avoid unwanted kernel updates
SKIP_ARMBIAN_REPO="yes"

# Keep the original A1 on the shared rk35xx kernel packages.  CM5 gets its own
# package namespace and an additional patch layer, while reusing the validated
# RK3576 vendor source and common patches.
function post_family_config_branch_vendor__dshanpi_a1_cm5_kernel_namespace() {
	declare -g LINUXFAMILY="rk3576-dshanpi-a1-cm5"
	declare -g LINUXCONFIG="linux-rk35xx-vendor"
	declare -g KERNELPATCHDIR="${KERNELPATCHDIR} rk3576-dshanpi-a1-cm5-vendor-6.1"
}

function custom_kernel_config__dshanpi_a1_cm5_bt_sco() {
	kernel_config_modifying_hashes+=("CONFIG_SND_SOC_BT_SCO=y")
	if [[ -f .config ]]; then
		kernel_config_set_y SND_SOC_BT_SCO
	fi
}

# The legacy RK3576 defconfig is shared as an immutable baseline.  Select the
# CM5-only U-Boot DTS after loading it so the original A1 defconfig is untouched.
function post_config_uboot_target__dshanpi_a1_cm5_dtb() {
	sed -i \
		-e 's/^CONFIG_DEFAULT_DEVICE_TREE=.*/CONFIG_DEFAULT_DEVICE_TREE="rk3576-100ask-dshanpi-a1-cm5"/' \
		-e 's#^CONFIG_ROCKCHIP_EARLY_DISTRO_DTB_PATH=.*#CONFIG_ROCKCHIP_EARLY_DISTRO_DTB_PATH="/boot/dtb/rockchip/rk3576-100ask-dshanpi-a1-cm5.dtb"#' \
		.config
}

function post_family_tweaks__dshanpi-a1-cm5_naming_audios() {
	display_alert "$BOARD" "Renaming dshanpi-a1-cm5 audios" "info"

	mkdir -p $SDCARD/etc/udev/rules.d/
	echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-es8388-sound", ENV{SOUND_DESCRIPTION}="ES8388 Audio"' > $SDCARD/etc/udev/rules.d/90-naming-audios.rules
	echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-hdmi-sound", ENV{SOUND_DESCRIPTION}="HDMI0 Audio"' >> $SDCARD/etc/udev/rules.d/90-naming-audios.rules
	echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-dp0-sound", ENV{SOUND_DESCRIPTION}="DP0 Audio"' >> $SDCARD/etc/udev/rules.d/90-naming-audios.rules
	echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-hdmiin-sound", ENV{SOUND_DESCRIPTION}="HDMI IN Audio"' >> $SDCARD/etc/udev/rules.d/90-naming-audios.rules

	return 0
}

function post_family_tweaks__dshanpi-a1-cm5_custom_udev() {
	display_alert "$BOARD" "Installing custom udev rules for MPP and GPIO" "info"

	# Create udev rules directory
	mkdir -p $SDCARD/etc/udev/rules.d/

	# MPP service and DMA heap permissions
	echo 'KERNEL=="mpp_service", MODE="0660", GROUP="video"' > $SDCARD/etc/udev/rules.d/99-rk-perm.rules
	echo 'KERNEL=="rga", MODE="0660", GROUP="video"' >> $SDCARD/etc/udev/rules.d/99-rk-perm.rules
	echo 'SUBSYSTEM=="dma_heap", KERNEL=="system|system-uncached|reserved", MODE="0660", GROUP="video"' >> $SDCARD/etc/udev/rules.d/99-rk-perm.rules

	# GPIO permissions
	echo 'SUBSYSTEM=="gpio", KERNEL=="gpiochip*", GROUP="gpio", MODE="0660"' > $SDCARD/etc/udev/rules.d/99-gpio.rules

	return 0
}

function post_family_tweaks__dshanpi-a1-cm5_create_gpio_group() {
	display_alert "$BOARD" "Creating gpio group for dshanpi-a1-cm5" "info"

	# Create gpio group if it doesn't exist
	chroot_sdcard groupadd -f gpio

	# Modify armbian-firstlogin to add gpio group to user creation
	if [[ -f $SDCARD/usr/lib/armbian/armbian-firstlogin ]]; then
		sed -i 's/for additionalgroup in sudo netdev audio video disk tty users games dialout plugdev input bluetooth systemd-journal ssh render; do/for additionalgroup in sudo netdev audio video disk tty users games dialout plugdev input bluetooth systemd-journal ssh render gpio; do/' $SDCARD/usr/lib/armbian/armbian-firstlogin
	fi

	return 0
}

function post_family_tweaks__dshanpi-a1-cm5_pulseaudio_config() {
	# Fix PulseAudio input source for ES8388 using modular config
	# This is cleaner than editing default.pa and avoids conflicts
	display_alert "$BOARD" "Installing PulseAudio config for ES8388" "info"
	mkdir -p $SDCARD/etc/pulse/default.pa.d/
	cat > $SDCARD/etc/pulse/default.pa.d/rockchip-es8388.pa << EOF
load-module module-alsa-source device=hw:rockchipes8388 source_name=es8388_input source_properties=device.description='ES8388 Analog Input'
EOF

	return 0
}

function post_family_tweaks_bsp__dshanpi-a1-cm5_aic8800() {
	display_alert "$BOARD" "Installing AIC8800D80 Wi-Fi and Bluetooth configuration" "info"

	mkdir -p "${destination}"/etc/modprobe.d
	mkdir -p "${destination}"/etc/modules-load.d
	mkdir -p "${destination}"/etc/systemd/system
	mkdir -p "${destination}"/usr/bin

	cat > "${destination}"/etc/modprobe.d/aic8800-wireless.conf <<- EOF
	options aic8800_fdrv_sdio aicwf_dbg_level=0 custregd=0 ps_on=0
	options aic8800_bsp_sdio aic_fw_path=/lib/firmware/aic8800_fw/SDIO/aic8800D80
	EOF

	cat > "${destination}"/etc/modules-load.d/aic8800.conf <<- EOF
	aic8800_bsp_sdio
	aic8800_fdrv_sdio
	aic8800_btlpm_sdio
	EOF

	install -m 755 "$SRC/packages/bsp/aic8800/aic-bluetooth" \
		"${destination}"/usr/bin/aic-bluetooth
	sed -i 's#/dev/ttyS1#/dev/ttyS7#g' "${destination}"/usr/bin/aic-bluetooth
	install -m 644 "$SRC/packages/bsp/aic8800/aic-bluetooth.service" \
		"${destination}"/etc/systemd/system/aic-bluetooth.service
}

function post_family_tweaks__dshanpi-a1-cm5_enable_aic8800_bluetooth() {
	chroot_sdcard systemctl --no-reload enable aic-bluetooth.service
}
