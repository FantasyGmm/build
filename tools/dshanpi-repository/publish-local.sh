#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<- 'EOF'
	Usage:
	  REPO_GPG_KEYID=<fingerprint> publish-local.sh publish <testing|stable> <incoming-dir> [repo-root]
	  publish-local.sh promote [repo-root]
	  publish-local.sh serve [repo-root] [port]

	The incoming directory must contain a curated set of .deb files. Publication
	fails if a package is outside the allowlist, duplicated with
	different content, or no usable secret signing key is available.
	EOF
}

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
workspace=$(cd "${script_dir}/../.." && pwd)
allowlist="${script_dir}/package-allowlist.txt"
command_name=${1:-}

validate_repo_root() {
	local candidate=$1
	[[ -n "$candidate" && "$candidate" != "/" && "$candidate" != "$HOME" ]] || {
		echo "Refusing unsafe repository root: $candidate" >&2
		exit 2
	}
}

package_allowed() {
	local package=$1 pattern
	while IFS= read -r pattern; do
		[[ -z "$pattern" || "$pattern" == \#* ]] && continue
		[[ "$package" =~ $pattern ]] && return 0
	done < "$allowlist"
	return 1
}

publish_channel() {
	local channel=$1 incoming=$2 repo_root=$3
	[[ "$channel" == "testing" || "$channel" == "stable" ]] || {
		echo "Channel must be testing or stable" >&2
		exit 2
	}
	[[ -d "$incoming" ]] || { echo "Missing incoming directory: $incoming" >&2; exit 2; }
	validate_repo_root "$repo_root"
	: "${REPO_GPG_KEYID:?Set REPO_GPG_KEYID to the signing key fingerprint}"
	gpg --batch --list-secret-keys "$REPO_GPG_KEYID" >/dev/null 2>&1 || {
		echo "Secret signing key not available: $REPO_GPG_KEYID" >&2
		exit 2
	}

	local parent stage target backup deb package version arch identity digest old_digest
	parent=$(dirname "$repo_root")
	mkdir -p "$parent" "$repo_root"
	stage=$(mktemp -d "${parent}/.dshanpi-repo-${channel}.XXXXXX")
	target="${repo_root}/${channel}"
	backup="${repo_root}/.${channel}.previous"
	trap 'rm -rf -- "$stage"' RETURN
	mkdir -p "$stage/pool/main" "$stage/dists/noble/main/binary-arm64" "$stage/dists/noble/main/binary-all"

	declare -A seen=()
	shopt -s nullglob
	for deb in "$incoming"/*.deb; do
		package=$(dpkg-deb -f "$deb" Package)
		version=$(dpkg-deb -f "$deb" Version)
		arch=$(dpkg-deb -f "$deb" Architecture)
		package_allowed "$package" || { echo "Package not allowlisted: $package" >&2; exit 1; }
		[[ "$arch" == "arm64" || "$arch" == "all" ]] || { echo "Unsupported architecture: $package/$arch" >&2; exit 1; }
		identity="${package}_${version}_${arch}"
		digest=$(sha256sum "$deb" | awk '{print $1}')
		old_digest=${seen[$identity]:-}
		[[ -z "$old_digest" || "$old_digest" == "$digest" ]] || {
			echo "Conflicting duplicate package: $identity" >&2
			exit 1
		}
		seen[$identity]=$digest
		cp -a "$deb" "$stage/pool/main/"
	done
	((${#seen[@]} > 0)) || { echo "No .deb packages found in $incoming" >&2; exit 1; }

	# Do not pass --arch here: Armbian package filenames append a build hash
	# after the architecture (for example arm64__<hash>.deb), which makes
	# dpkg-scanpackages' filename-based architecture filter skip valid packages.
	(cd "$stage" && dpkg-scanpackages --multiversion pool/main /dev/null) > "$stage/Packages.all"
	for arch in arm64 all; do
		local binary_dir="$stage/dists/noble/main/binary-${arch}"
		awk -v wanted="$arch" '
			BEGIN { RS = ""; ORS = "\n\n"; FS = "\n" }
			{
				for (i = 1; i <= NF; i++) {
					if ($i == "Architecture: " wanted ||
					    (wanted == "arm64" && $i == "Architecture: all")) {
						print
						next
					}
				}
			}
		' "$stage/Packages.all" > "$binary_dir/Packages"
		gzip -9n -c "$binary_dir/Packages" > "$binary_dir/Packages.gz"
		xz -9e -c "$binary_dir/Packages" > "$binary_dir/Packages.xz"
	done
	rm "$stage/Packages.all"

	cat > "$stage/apt-ftparchive.conf" <<- EOF
	APT::FTPArchive::Release::Origin "DShanPI";
	APT::FTPArchive::Release::Label "DShanPI Official Systems";
	APT::FTPArchive::Release::Suite "noble";
	APT::FTPArchive::Release::Codename "noble";
	APT::FTPArchive::Release::Architectures "arm64 all";
	APT::FTPArchive::Release::Components "main";
	APT::FTPArchive::Release::Description "DShanPI A1 and A1 CM5 Ubuntu 24.04 updates (${channel})";
	EOF
	(cd "$stage" && apt-ftparchive -c apt-ftparchive.conf release dists/noble) > "$stage/dists/noble/Release"
	rm "$stage/apt-ftparchive.conf"
	gpg --batch --yes --local-user "$REPO_GPG_KEYID" --clearsign \
		--output "$stage/dists/noble/InRelease" "$stage/dists/noble/Release"
	gpg --batch --yes --local-user "$REPO_GPG_KEYID" --armor --detach-sign \
		--output "$stage/dists/noble/Release.gpg" "$stage/dists/noble/Release"
	(cd "$stage" && find dists pool -type f -print0 | sort -z | xargs -0 sha256sum) > "$stage/SHA256SUMS"

	[[ ! -e "$backup" ]] || rm -rf -- "$backup"
	[[ ! -e "$target" ]] || mv "$target" "$backup"
	mv "$stage" "$target"
	trap - RETURN
	[[ ! -e "$backup" ]] || rm -rf -- "$backup"
	echo "Published $channel at $target"
}

promote_testing() {
	local repo_root=$1 source target stage backup parent
	validate_repo_root "$repo_root"
	source="${repo_root}/testing"
	target="${repo_root}/stable"
	[[ -f "$source/dists/noble/InRelease" ]] || { echo "No signed testing snapshot" >&2; exit 2; }
	parent=$(dirname "$repo_root")
	stage=$(mktemp -d "${parent}/.dshanpi-promote.XXXXXX")
	backup="${repo_root}/.stable.previous"
	cp -a "$source/." "$stage/"
	[[ ! -e "$backup" ]] || rm -rf -- "$backup"
	[[ ! -e "$target" ]] || mv "$target" "$backup"
	mv "$stage" "$target"
	[[ ! -e "$backup" ]] || rm -rf -- "$backup"
	echo "Promoted the exact testing snapshot to stable"
}

case "$command_name" in
	publish)
		[[ $# -ge 3 ]] || { usage; exit 2; }
		publish_channel "$2" "$(realpath "$3")" "${4:-${workspace}/output/dshanpi-repository}"
		;;
	promote)
		promote_testing "${2:-${workspace}/output/dshanpi-repository}"
		;;
	serve)
		repo_root=${2:-${workspace}/output/dshanpi-repository}
		validate_repo_root "$repo_root"
		exec python3 -m http.server "${3:-8080}" --directory "$repo_root"
		;;
	*) usage; exit 2 ;;
esac
