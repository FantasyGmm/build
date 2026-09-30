#!/usr/bin/env bash

# Install the dspi-config package supplied by the external dshanpi-build
# orchestrator. ArmBianOS consumes the package but does not build or publish it.
function post_repo_customize_image__install_dshanpi_dspi_config() {
	local package_file package_name
	package_file=$(realpath "${DSHANPI_DSPI_CONFIG_DEB:?DSHANPI_DSPI_CONFIG_DEB is required}")
	[[ -f "$package_file" ]] || exit_with_error "dspi-config package is missing" "$package_file"
	package_name=$(basename "$package_file")

	[[ $(dpkg-deb -f "$package_file" Package) == dspi-config ]] ||
		exit_with_error "Unexpected package supplied for dspi-config" "$package_file"
	[[ $(dpkg-deb -f "$package_file" Architecture) == all ]] ||
		exit_with_error "Unexpected dspi-config architecture" "$package_file"

	cp "$package_file" "$SDCARD/tmp/$package_name"
	use_clean_environment="yes" chroot_sdcard_apt_get_install "/tmp/$package_name"
	chroot_sdcard rm "/tmp/$package_name"
}
