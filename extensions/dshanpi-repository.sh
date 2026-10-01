#!/usr/bin/env bash

# Install the prebuilt keyring and board source packages supplied by
# dshanpi-build. This deliberately runs after Armbian's final apt update so a
# new product release can be built before its repository is published. The
# completed image still ships with the DShanPI source enabled by default.
# ArmBianOS never creates or signs APT repository metadata.
function post_post_debootstrap_tweaks__100_install_dshanpi_repository() {
	local package_dir="${DSHANPI_REPO_CLIENT_PACKAGES_DIR:?DSHANPI_REPO_CLIENT_PACKAGES_DIR is required}"
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
