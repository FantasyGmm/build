#!/usr/bin/env bash

# Opt-in extension for release builds.  Keep it out of board defaults so the
# immutable A1 board definition and developer images do not depend on a local
# signing environment.  CI enables it with ENABLE_EXTENSIONS and provides the
# two packages produced by tools/dshanpi-repository/build-client-packages.sh.
function post_repo_customize_image__install_dshanpi_repository() {
	local package_dir="${DSHANPI_REPO_CLIENT_PACKAGES_DIR:-${SRC}/output/dshanpi-repository/client-packages}"
	local keyring repository
	[[ -d "$package_dir" ]] ||
		exit_with_error "DShanPI repository client package directory is missing" "$package_dir"
	keyring=$(find "$package_dir" -maxdepth 1 -type f -name 'dshanpi-archive-keyring_*_all.deb' -print -quit 2> /dev/null)
	repository=$(find "$package_dir" -maxdepth 1 -type f -name 'dshanpi-system-repository_*_all.deb' -print -quit 2> /dev/null)
	[[ -n "$keyring" && -n "$repository" ]] ||
		exit_with_error "DShanPI repository client packages are missing" "$package_dir"

	display_alert "Installing DShanPI official update source" "$package_dir" "info"
	cp "$keyring" "$repository" "$SDCARD/tmp/"
	chroot_sdcard dpkg -i "/tmp/$(basename "$keyring")" "/tmp/$(basename "$repository")"
	chroot_sdcard rm "/tmp/$(basename "$keyring")" "/tmp/$(basename "$repository")"
}
