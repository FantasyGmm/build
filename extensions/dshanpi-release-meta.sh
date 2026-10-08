#!/usr/bin/env bash

# Install the exact product release meta-package supplied by dshanpi-build.
# This runs after the final apt update and after the repository client hook,
# so a not-yet-published release can still be assembled without circular APT
# access. It marks the initial image cohort so dspi-config can later upgrade
# or downgrade the complete tested DShanPI platform stack.
function post_post_debootstrap_tweaks__200_install_dshanpi_release_meta() {
	local package_file package package_name
	local product="${DSHANPI_PRODUCT:-${BOARD:-}}"
	[[ "$product" =~ ^[a-z0-9][a-z0-9-]*$ ]] ||
		exit_with_error "Invalid DShanPI product name" "$product"
	package_file=$(realpath "${DSHANPI_RELEASE_META_DEB:?DSHANPI_RELEASE_META_DEB is required}")
	[[ -f "$package_file" ]] || exit_with_error "DShanPI release meta-package is missing" "$package_file"
	package=$(dpkg-deb -f "$package_file" Package)
	case "$package" in
		"${product}-release-core" | "${product}-release-desktop") ;;
		*) exit_with_error "Unexpected DShanPI release meta-package" "$package" ;;
	esac
	[[ $(dpkg-deb -f "$package_file" Architecture) == all ]] ||
		exit_with_error "Unexpected release meta-package architecture" "$package_file"
	package_name=$(basename "$package_file")
	# A candidate is built before publication. Supply the exact local dependency
	# cohort so apt never needs to fetch unpublished platform packages.
	if [[ -n "${DSHANPI_RELEASE_PACKAGES_DIR:-}" ]]; then
		local cohort_dir cohort_deb dependency dependency_version selected dependency_list
		local -a install_files=("/tmp/$package_name")
		cohort_dir=$(realpath "${DSHANPI_RELEASE_PACKAGES_DIR}")
		[[ -d "$cohort_dir" ]] || exit_with_error "Missing release package directory" "$cohort_dir"
		dependency_list=$(dpkg-deb -f "$package_file" Depends | python3 -c '
import re, sys
for item in sys.stdin.read().strip().split(","):
    match = re.fullmatch(r"\s*([a-z0-9][a-z0-9+.-]*) \(= ([^\s()]+)\)\s*", item)
    if not match:
        raise SystemExit("release dependencies must pin exact versions")
    print(*match.groups(), sep="\t")
') || exit_with_error "Invalid release dependency list" "$package_file"
		while IFS=$'\t' read -r dependency dependency_version; do
			selected=
			while IFS= read -r -d '' cohort_deb; do
				[[ $(dpkg-deb -f "$cohort_deb" Package) == "$dependency" ]] || continue
				[[ $(dpkg-deb -f "$cohort_deb" Version) == "$dependency_version" ]] || continue
				[[ -z "$selected" ]] || exit_with_error "Duplicate release dependency" "$dependency"
				selected=$cohort_deb
			done < <(find "$cohort_dir" -maxdepth 1 -type f -name '*.deb' -print0)
			[[ -n "$selected" ]] || exit_with_error "Missing exact release dependency" "$dependency=$dependency_version"
			cp "$selected" "$SDCARD/tmp/"
			install_files+=("/tmp/$(basename "$selected")")
		done <<< "$dependency_list"
		cp "$package_file" "$SDCARD/tmp/$package_name"
		use_clean_environment="yes" chroot_sdcard_apt_get_install "${install_files[@]}"
		chroot_sdcard rm "${install_files[@]}"
		return
	fi
	cp "$package_file" "$SDCARD/tmp/$package_name"
	use_clean_environment="yes" chroot_sdcard_apt_get_install "/tmp/$package_name"
	chroot_sdcard rm "/tmp/$package_name"
}
