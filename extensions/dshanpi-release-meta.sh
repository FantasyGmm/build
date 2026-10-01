#!/usr/bin/env bash

# Install the exact product release meta-package supplied by dshanpi-build.
# This runs after the final apt update and after the repository client hook,
# so a not-yet-published release can still be assembled without circular APT
# access. It marks the initial image cohort so dspi-config can later upgrade
# or downgrade the complete tested DShanPI platform stack.
function post_post_debootstrap_tweaks__200_install_dshanpi_release_meta() {
	local package_file package package_name
	package_file=$(realpath "${DSHANPI_RELEASE_META_DEB:?DSHANPI_RELEASE_META_DEB is required}")
	[[ -f "$package_file" ]] || exit_with_error "DShanPI release meta-package is missing" "$package_file"
	package=$(dpkg-deb -f "$package_file" Package)
	case "$package" in
		dshanpi-a1-cm5-release-core | dshanpi-a1-cm5-release-desktop) ;;
		*) exit_with_error "Unexpected DShanPI release meta-package" "$package" ;;
	esac
	[[ $(dpkg-deb -f "$package_file" Architecture) == all ]] ||
		exit_with_error "Unexpected release meta-package architecture" "$package_file"
	package_name=$(basename "$package_file")
	cp "$package_file" "$SDCARD/tmp/$package_name"
	use_clean_environment="yes" chroot_sdcard_apt_get_install "/tmp/$package_name"
	chroot_sdcard rm "/tmp/$package_name"
}
