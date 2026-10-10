#!/usr/bin/env bash

# Copy the board-owned dspi-config data interface into the board support
# package. Device-tree binaries remain owned by the kernel DTB package and the
# generic dspi-config program remains owned by its independent source tree.
function post_family_tweaks_bsp__dshanpi_product_profile() {
	local product="${DSHANPI_PRODUCT:-${BOARD:-}}"
	local profile_root="$SRC/packages/bsp/$product"
	local destination_root="${destination}/usr/share/dspi-config/boards/$product"

	[[ "$product" =~ ^[a-z0-9][a-z0-9-]*$ ]] ||
		exit_with_error "Invalid DShanPI product name" "$product"
	[[ "$product" == "$BOARD" ]] ||
		exit_with_error "DShanPI product does not match Armbian board" "$product != $BOARD"
	[[ -f "$profile_root/overlays.tsv" && -f "$profile_root/system.conf" ]] ||
		exit_with_error "DShanPI board profile is incomplete" "$profile_root"

	install -D -m 0644 "$profile_root/overlays.tsv" "$destination_root/overlays.tsv"
	install -D -m 0644 "$profile_root/system.conf" "$destination_root/system.conf"
}

EXTENSION_DESCRIPTION="Install the selected DShanPI board profile into its BSP package"
