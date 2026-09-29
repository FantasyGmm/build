#!/usr/bin/env bash

# Opt-in extension for release builds.  Keep it out of board defaults so the
# immutable A1 board definition and developer images do not depend on a local
# signing environment.  Release builds set DSHANPI_INSTALL_REPOSITORY=yes and
# provide the two packages produced by
# tools/dshanpi-repository/build-client-packages.sh.
function post_repo_customize_image__install_dshanpi_repository() {
	local package_dir="${DSHANPI_REPO_CLIENT_PACKAGES_DIR:-${SRC}/output/dshanpi-repository/client-packages}"
	local keyring repository
	local -a keyrings repositories
	[[ -d "$package_dir" ]] ||
		exit_with_error "DShanPI repository client package directory is missing" "$package_dir"
	mapfile -t keyrings < <(find "$package_dir" -maxdepth 1 -type f -name 'dshanpi-archive-keyring_*_all.deb' -print 2> /dev/null)
	mapfile -t repositories < <(find "$package_dir" -maxdepth 1 -type f -name 'dshanpi-a1-cm5-repository_*_all.deb' -print 2> /dev/null)
	[[ ${#keyrings[@]} -eq 1 && ${#repositories[@]} -eq 1 ]] ||
		exit_with_error "Expected exactly one keyring and one A1 CM5 repository package" "$package_dir"
	keyring=${keyrings[0]}
	repository=${repositories[0]}

	display_alert "Installing DShanPI official update source" "$package_dir" "info"
	cp "$keyring" "$repository" "$SDCARD/tmp/"
	chroot_sdcard dpkg -i "/tmp/$(basename "$keyring")" "/tmp/$(basename "$repository")"
	chroot_sdcard rm "/tmp/$(basename "$keyring")" "/tmp/$(basename "$repository")"
}
