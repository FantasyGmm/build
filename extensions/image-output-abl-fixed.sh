function add_host_dependencies__abl_host_deps() {
	declare -g EXTRA_BUILD_DEPS="${EXTRA_BUILD_DEPS} mkbootimg"
}

function post_build_image__900_convert_to_abl_img() {
	[[ -z $version ]] && exit_with_error "version is not set"

	if [ ! -z "$BOOTFS_TYPE" ]; then
		return 0
	fi

	display_alert "Converting image $version to rootfs" "${EXTENSION}" "info"
	declare -g ROOTFS_IMAGE_FILE="${DESTIMG}/${version}.rootfs.img"
	old_rootfs_image_mount_dir=${DESTIMG}/rootfs-old
	mkdir -p ${old_rootfs_image_mount_dir}
	old_image_loop_device=$(losetup -f -P --show ${DESTIMG}/${version}.img)
	mount ${old_image_loop_device}p1 ${old_rootfs_image_mount_dir}
	rm ${DESTIMG}/${version}.img
	declare -g bootimg_cmdline="${BOOTIMG_CMDLINE_EXTRA} root=PARTLABEL=rootfs slot_suffix=${abl_boot_partition_label#boot}"

	if [ ${#ABL_DTB_LIST[@]} -ne 0 ]; then
		display_alert "Going to create abl kernel boot image" "${EXTENSION}" "info"
		source ${old_rootfs_image_mount_dir}/boot/armbianEnv.txt
		gzip -c ${old_rootfs_image_mount_dir}/boot/vmlinuz-*-* > ${DESTIMG}/Image.gz
		for dtb_name in "${ABL_DTB_LIST[@]}"; do
			display_alert "Creatng abl kernel boot image with dtb ${dtb_name} and cmdline ${bootimg_cmdline} " "${EXTENSION}" "info"
			cat ${DESTIMG}/Image.gz ${old_rootfs_image_mount_dir}/usr/lib/linux-image-*/qcom/${dtb_name}.dtb > ${DESTIMG}/Image.gz-${dtb_name}
			/usr/bin/mkbootimg \
				--kernel ${DESTIMG}/Image.gz-${dtb_name} \
				--ramdisk ${old_rootfs_image_mount_dir}/boot/initrd.img-*-* \
				--base 0x0 \
				--second_offset 0x00f00000 \
				--cmdline "${bootimg_cmdline}" \
				--kernel_offset 0x8000 \
				--ramdisk_offset 0x1000000 \
				--tags_offset 0x100 \
				--pagesize 4096 \
				-o ${DESTIMG}/${version}.boot_${dtb_name}_fixed.img
		done
	fi

	umount ${old_rootfs_image_mount_dir}
	losetup -d ${old_image_loop_device}
	rm -rf ${old_rootfs_image_mount_dir}
	return 0
}
