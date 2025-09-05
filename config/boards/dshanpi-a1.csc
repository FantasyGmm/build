# Rockchip RK3576 SoC octa core 4-32GB SoC 2*GBe eMMC USB3 NvME WIFI
BOARD_NAME="100ASK DShanPI A1"
BOARD_VENDOR="dongshanpi"
BOARDFAMILY="rk35xx"
BOARD_MAINTAINER=""
INTRODUCED="2025"
BOOTCONFIG="dshanpi-a1-rk3576_defconfig"
KERNEL_TARGET="vendor"
KERNEL_TEST_TARGET="vendor"
FULL_DESKTOP="yes"
BOOT_LOGO="desktop"
BOOT_FDT_FILE="rockchip/rk3576-100ask-dshanpi-a1.dtb"
BOOT_SCENARIO="spl-blobs"
IMAGE_PARTITION_TABLE="gpt"

# Enable Rockchip multimedia packages (MPP, RGA, GStreamer)
ENABLE_EXTENSIONS="rockchip-multimedia"

function post_family_tweaks__dshanpi-a1_naming_audios() {
	display_alert "$BOARD" "Renaming dshanpi-a1 audios" "info"

	mkdir -p $SDCARD/etc/udev/rules.d/
	echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-hdmi0-sound", ENV{SOUND_DESCRIPTION}="HDMI0 Audio"' > $SDCARD/etc/udev/rules.d/90-naming-audios.rules
	echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-dp0-sound", ENV{SOUND_DESCRIPTION}="DP0 Audio"' >> $SDCARD/etc/udev/rules.d/90-naming-audios.rules
	echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-es8388-sound", ENV{SOUND_DESCRIPTION}="ES8388 Audio"' >> $SDCARD/etc/udev/rules.d/90-naming-audios.rules

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
