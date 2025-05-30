# Amlogic S805 quad core 1GB RAM SoC GBE
BOARD_NAME="OneCloud"
BOARDFAMILY="meson8b"
BOARD_MAINTAINER="hzyitc"
KERNEL_TARGET="current"
KERNEL_TEST_TARGET="current"
BOOTCONFIG="none"
BOOTSCRIPT="boot-onecloud.cmd:boot.cmd"
BOOTENV_FILE="onecloud.txt"

OFFSET="16"
BOOTSIZE="256"
BOOTFS_TYPE="fat"

# ROOTFS_TYPE="f2fs"
# FIXED_IMAGE_SIZE=7456

BOOT_LOGO=desktop

family_tweaks() {
	cp $SRC/packages/blobs/splash/armbian-u-boot-24.bmp $SDCARD/boot/boot.bmp
}
