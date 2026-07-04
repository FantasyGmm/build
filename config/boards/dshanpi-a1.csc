# Rockchip RK3576 SoC octa core 4-32GB SoC 2*GBe eMMC USB3 NvME WIFI
BOARD_NAME="100ASK DShanPI A1"
BOARDFAMILY="rk35xx"
BOARD_MAINTAINER=""
BOOTCONFIG="dshanpi-a1-rk3576_defconfig"
KERNEL_TARGET="vendor"
KERNEL_TEST_TARGET="vendor"
FULL_DESKTOP="yes"
BOOT_LOGO="desktop"
BOOT_FDT_FILE="rockchip/rk3576-100ask-dshanpi-a1.dtb"
BOOT_SCENARIO="spl-blobs"
DDR_BLOB="rk35/rk3576_ddr_lp4_2112MHz_lp5_2736MHz_v1.09.bin"
BL31_BLOB="rk35/rk3576_bl31_v1.20.elf"
BL32_BLOB="rk35/rk3576_bl32_v1.06.bin"
IMAGE_PARTITION_TABLE="gpt"
DESKTOP_AUTOLOGIN="yes"

# Define initial audio state file
ASOUND_STATE="asound.state.dshanpi-a1"

# Enable Rockchip multimedia packages (MPP, RGA, GStreamer) and DShanPI Camera
ENABLE_EXTENSIONS="rockchip-multimedia,dshanpi-camera"

# Disable official Armbian apt repository to avoid unwanted kernel updates
SKIP_ARMBIAN_REPO="yes"

function post_family_tweaks__dshanpi-a1_naming_audios() {
	display_alert "$BOARD" "Renaming dshanpi-a1 audios" "info"

	mkdir -p $SDCARD/etc/udev/rules.d/
	echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-es8388-sound", ENV{SOUND_DESCRIPTION}="ES8388 Audio"' > $SDCARD/etc/udev/rules.d/90-naming-audios.rules
	echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-hdmi-sound", ENV{SOUND_DESCRIPTION}="HDMI0 Audio"' >> $SDCARD/etc/udev/rules.d/90-naming-audios.rules
	echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-dp0-sound", ENV{SOUND_DESCRIPTION}="DP0 Audio"' >> $SDCARD/etc/udev/rules.d/90-naming-audios.rules
	echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-hdmiin-sound", ENV{SOUND_DESCRIPTION}="HDMI IN Audio"' >> $SDCARD/etc/udev/rules.d/90-naming-audios.rules

	return 0
}

function post_family_tweaks__dshanpi-a1_custom_udev() {
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

function post_family_tweaks__dshanpi-a1_create_gpio_group() {
	display_alert "$BOARD" "Creating gpio group for dshanpi-a1" "info"

	# Create gpio group if it doesn't exist
	chroot_sdcard groupadd -f gpio

	# Modify armbian-firstlogin to add gpio group to user creation
	if [[ -f $SDCARD/usr/lib/armbian/armbian-firstlogin ]]; then
		sed -i 's/for additionalgroup in sudo netdev audio video disk tty users games dialout plugdev input bluetooth systemd-journal ssh render; do/for additionalgroup in sudo netdev audio video disk tty users games dialout plugdev input bluetooth systemd-journal ssh render gpio; do/' $SDCARD/usr/lib/armbian/armbian-firstlogin
	fi

	return 0
}

function post_family_tweaks__dshanpi-a1_pulseaudio_config() {
	# Fix PulseAudio input source for ES8388 using modular config
	# This is cleaner than editing default.pa and avoids conflicts
	display_alert "$BOARD" "Installing PulseAudio config for ES8388" "info"
	mkdir -p $SDCARD/etc/pulse/default.pa.d/
	cat > $SDCARD/etc/pulse/default.pa.d/rockchip-es8388.pa << EOF
load-module module-alsa-source device=hw:rockchipes8388 source_name=es8388_input source_properties=device.description='ES8388 Analog Input'
EOF

	return 0
}
