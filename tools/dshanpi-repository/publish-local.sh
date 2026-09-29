#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat <<- 'EOF'
	Usage:
	  REPO_GPG_KEYID=<fingerprint> publish-local.sh publish <release-version> <incoming-dir> [repo-root]
	  REPO_GPG_KEYID=<fingerprint> publish-local.sh promote [repo-root]
	  publish-local.sh serve [web-root] [port]

	Only a complete, reviewed A1 CM5 package set can be published to testing.
	Stable is created only by promoting the exact signed testing snapshot.
	EOF
}

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
workspace=$(cd "${script_dir}/../.." && pwd)
allowlist="${script_dir}/package-allowlist.txt"
required_packages="${script_dir}/required-packages.txt"
default_repo_root="${workspace}/output/dshanpi-repository/dshanpi-a1-cm5"
default_web_root="${workspace}/output/dshanpi-repository"
command_name=${1:-}
declare -a cleanup_paths=()

cleanup() {
	local path basename
	for path in "${cleanup_paths[@]}"; do
		[[ -n "$path" && -d "$path" ]] || continue
		basename=${path##*/}
		if [[ "$path" == /tmp/tmp.* || "$basename" == .dshanpi-a1-cm5-* ]]; then
			rm -rf -- "$path"
		fi
	done
}
trap cleanup EXIT

die() {
	echo "$*" >&2
	exit 1
}

validate_repo_root() {
	local candidate=$1
	[[ -n "$candidate" && "$candidate" != "/" && "$candidate" != "$HOME" && "$candidate" != "$workspace" ]] || {
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

audit_deb() {
	local deb=$1 package=$2 audit_dir payload rpath

	if dpkg-deb --contents "$deb" | awk '
		$1 ~ /^-/ && substr($1, 9, 1) == "w" { bad = 1 }
		$1 ~ /^d/ && substr($1, 9, 1) == "w" && substr($1, 10, 1) !~ /[tT]/ { bad = 1 }
		$1 ~ /^-/ && (substr($1, 4, 1) ~ /[sS]/ || substr($1, 7, 1) ~ /[sS]/) { bad = 1 }
		END { exit(bad ? 0 : 1) }
	'; then
		die "Unsafe writable or set-id payload mode in $deb"
	fi

	audit_dir=$(mktemp -d)
	cleanup_paths+=("$audit_dir")
	dpkg-deb --extract "$deb" "$audit_dir"
	while IFS=$'\t' read -r payload description; do
		description=${description#"${description%%[![:space:]]*}"}
		[[ "$description" == ELF\ * ]] || continue
		rpath=$(patchelf --print-rpath "$payload" 2> /dev/null || true)
		if [[ "$rpath" =~ (^|:)/(home|tmp|build)(/|:|$) ]]; then
			rm -rf -- "$audit_dir"
			die "Build-host RPATH in ${package}:${payload#${audit_dir}}: $rpath"
		fi
	done < <(find "$audit_dir" -type f -exec file --no-pad --separator $'\t' {} +)
	rm -rf -- "$audit_dir"
}

validate_release_package_version() {
	local package=$1 version=$2 release_version=$3
	case "$package" in
		armbian-bsp-cli-dshanpi-a1-cm5-vendor | armbian-bsp-desktop-dshanpi-a1-cm5-vendor | \
		linux-image-vendor-rk3576-dshanpi-a1-cm5 | linux-dtb-vendor-rk3576-dshanpi-a1-cm5 | \
		linux-headers-vendor-rk3576-dshanpi-a1-cm5)
			[[ "$version" == "$release_version" ]] ||
				die "$package must use release version $release_version (found $version)"
			;;
		base-files)
			[[ "$version" == "${release_version}-"* ]] ||
				die "base-files must start with ${release_version}- (found $version)"
			;;
		camera-engine-rkaiq)
			dpkg --compare-versions "$version" ge '6.6.3+dshanpi1' ||
				die "Unsafe camera-engine-rkaiq version: $version"
			;;
	esac
}

archive_target() {
	local target=$1 channel=$2 repo_root=$3 stamp snapshot
	[[ -e "$target" ]] || return 0
	stamp=$(date -u +%Y%m%dT%H%M%SZ)
	mkdir -p "$repo_root/snapshots"
	snapshot="$repo_root/snapshots/${channel}-${stamp}-${BASHPID}"
	mv "$target" "$snapshot"
	echo "Archived previous $channel snapshot at $snapshot"
}

publish_testing() {
	local release_version=$1 incoming=$2 repo_root=$3
	local parent stage target stable_pool deb package version arch pair identity digest destination
	local previous_version required_package required_arch extra binary_dir stable_release

	[[ "$release_version" =~ ^[0-9] ]] || die "Release version must begin with a digit: $release_version"
	dpkg --validate-version "$release_version" 2> /dev/null || die "Invalid Debian release version: $release_version"
	dpkg --compare-versions "$release_version" gt '25.11.0-trunk' ||
		die "Release version must be newer than the already published 25.11.0-trunk: $release_version"
	[[ -d "$incoming" ]] || die "Missing incoming directory: $incoming"
	validate_repo_root "$repo_root"
	if [[ -f "$repo_root/stable/RELEASE_VERSION" ]]; then
		stable_release=$(< "$repo_root/stable/RELEASE_VERSION")
		dpkg --validate-version "$stable_release" 2> /dev/null || die "Stable has an invalid release version: $stable_release"
		dpkg --compare-versions "$release_version" gt "$stable_release" ||
			die "Release version $release_version must be newer than stable $stable_release"
	fi
	: "${REPO_GPG_KEYID:?Set REPO_GPG_KEYID to the full signing-key fingerprint}"
	gpg --batch --list-secret-keys "$REPO_GPG_KEYID" >/dev/null 2>&1 ||
		die "Secret signing key not available: $REPO_GPG_KEYID"
	for command in apt-ftparchive dpkg-scanpackages file gpg patchelf xz; do
		command -v "$command" >/dev/null || die "Required command not found: $command"
	done

	parent=$(dirname "$repo_root")
	mkdir -p "$parent" "$repo_root"
	stage=$(mktemp -d "${parent}/.dshanpi-a1-cm5-testing.XXXXXX")
	cleanup_paths+=("$stage")
	target="${repo_root}/testing"
	stable_pool="${repo_root}/stable/pool/main"
	mkdir -p "$stage/pool/main" "$stage/dists/noble/main/binary-arm64" "$stage/dists/noble/main/binary-all"
	[[ ! -d "$stable_pool" ]] || cp -a "$stable_pool/." "$stage/pool/main/"

	declare -A staged_digest=()
	declare -A staged_version=()
	declare -A incoming_pair=()
	declare -A required_seen=()

	shopt -s nullglob
	for deb in "$stage/pool/main"/*.deb; do
		package=$(dpkg-deb -f "$deb" Package)
		version=$(dpkg-deb -f "$deb" Version)
		arch=$(dpkg-deb -f "$deb" Architecture)
		package_allowed "$package" || die "Disallowed package already present in stable: $package"
		identity="${package}|${version}|${arch}"
		pair="${package}|${arch}"
		digest=$(sha256sum "$deb" | awk '{print $1}')
		[[ -z "${staged_digest[$identity]:-}" || "${staged_digest[$identity]}" == "$digest" ]] ||
			die "Stable contains conflicting copies of $package $version $arch"
		staged_digest[$identity]=$digest
		previous_version=${staged_version[$pair]:-}
		if [[ -z "$previous_version" ]] || dpkg --compare-versions "$version" gt "$previous_version"; then
			staged_version[$pair]=$version
		fi
	done

	for deb in "$incoming"/*.deb; do
		package=$(dpkg-deb -f "$deb" Package)
		version=$(dpkg-deb -f "$deb" Version)
		arch=$(dpkg-deb -f "$deb" Architecture)
		package_allowed "$package" || die "Package not allowlisted: $package"
		[[ "$arch" == "arm64" || "$arch" == "all" ]] || die "Unsupported architecture: $package/$arch"
		pair="${package}|${arch}"
		[[ -z "${incoming_pair[$pair]:-}" ]] || die "Incoming contains more than one version of $package/$arch"
		incoming_pair[$pair]=$version
		required_seen[$pair]=1
		validate_release_package_version "$package" "$version" "$release_version"
		audit_deb "$deb" "$package"

		previous_version=${staged_version[$pair]:-}
		[[ -z "$previous_version" ]] || dpkg --compare-versions "$version" ge "$previous_version" ||
			die "Version regression for $package/$arch: $version is older than stable $previous_version"
		identity="${package}|${version}|${arch}"
		digest=$(sha256sum "$deb" | awk '{print $1}')
		[[ -z "${staged_digest[$identity]:-}" || "${staged_digest[$identity]}" == "$digest" ]] ||
			die "Same package identity has different content: $package $version $arch"
		if [[ -z "${staged_digest[$identity]:-}" ]]; then
			destination="$stage/pool/main/${package}_${version}_${arch}.deb"
			[[ ! -e "$destination" ]] || die "Pool filename collision: $destination"
			cp -a "$deb" "$destination"
			staged_digest[$identity]=$digest
		fi
	done
	((${#incoming_pair[@]} > 0)) || die "No .deb packages found in $incoming"

	while read -r required_package required_arch extra; do
		[[ -z "$required_package" || "$required_package" == \#* ]] && continue
		[[ -z "${extra:-}" ]] || die "Invalid required-packages entry: $required_package $required_arch $extra"
		[[ -n "${required_seen[${required_package}|${required_arch}]:-}" ]] ||
			die "Required package missing from incoming: $required_package/$required_arch"
	done < "$required_packages"

	(cd "$stage" && dpkg-scanpackages --multiversion pool/main /dev/null) > "$stage/Packages.all"
	for arch in arm64 all; do
		binary_dir="$stage/dists/noble/main/binary-${arch}"
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
	printf '%s\n' "$release_version" > "$stage/RELEASE_VERSION"
	cat > "$stage/apt-ftparchive.conf" <<- EOF
	APT::FTPArchive::Release::Origin "DShanPI";
	APT::FTPArchive::Release::Label "DShanPI A1 CM5";
	APT::FTPArchive::Release::Suite "noble";
	APT::FTPArchive::Release::Codename "noble";
	APT::FTPArchive::Release::Architectures "arm64 all";
	APT::FTPArchive::Release::Components "main";
	APT::FTPArchive::Release::Description "DShanPI A1 CM5 controlled updates (${release_version})";
	APT::FTPArchive::Release::NotAutomatic "yes";
	APT::FTPArchive::Release::ButAutomaticUpgrades "no";
	EOF
	(cd "$stage" && apt-ftparchive -c apt-ftparchive.conf release dists/noble) > "$stage/dists/noble/Release"
	rm "$stage/apt-ftparchive.conf"
	# apt-ftparchive omits boolean fields whose value is "no". Keep the policy
	# explicit in the signed Release file instead of relying on APT's default.
	grep -q '^ButAutomaticUpgrades:' "$stage/dists/noble/Release" ||
		printf 'ButAutomaticUpgrades: no\n' >> "$stage/dists/noble/Release"
	grep -qx 'NotAutomatic: yes' "$stage/dists/noble/Release" || die "Release is missing NotAutomatic: yes"
	grep -qx 'ButAutomaticUpgrades: no' "$stage/dists/noble/Release" || die "Release is missing ButAutomaticUpgrades: no"
	gpg --batch --yes --local-user "$REPO_GPG_KEYID" --clearsign \
		--output "$stage/dists/noble/InRelease" "$stage/dists/noble/Release"
	gpg --batch --yes --local-user "$REPO_GPG_KEYID" --armor --detach-sign \
		--output "$stage/dists/noble/Release.gpg" "$stage/dists/noble/Release"
	(cd "$stage" && find RELEASE_VERSION dists pool -type f -print0 | sort -z | xargs -0 sha256sum) > "$stage/SHA256SUMS"

	archive_target "$target" testing "$repo_root"
	mv "$stage" "$target"
	echo "Published signed A1 CM5 testing release $release_version at $target"
}

promote_testing() {
	local repo_root=$1 source target stage parent valid_fingerprints
	validate_repo_root "$repo_root"
	: "${REPO_GPG_KEYID:?Set REPO_GPG_KEYID to the full signing-key fingerprint}"
	source="${repo_root}/testing"
	target="${repo_root}/stable"
	[[ -f "$source/dists/noble/InRelease" && -f "$source/SHA256SUMS" && -f "$source/RELEASE_VERSION" ]] ||
		die "No complete signed testing snapshot to promote"
	(cd "$source" && sha256sum --check --strict SHA256SUMS >/dev/null) || die "Testing snapshot checksum verification failed"
	# VALIDSIG identifies the signing subkey first and, when present, its primary
	# key last. Accept either so a normal offline-primary/signing-subkey layout
	# can still be verified against the configured full fingerprint.
	valid_fingerprints=$(gpg --batch --status-fd 1 --verify "$source/dists/noble/InRelease" 2> /dev/null |
		awk '$2 == "VALIDSIG" { print $3; if (NF >= 13) print $NF }')
	grep -Fqx "$REPO_GPG_KEYID" <<< "$valid_fingerprints" || die "Testing signature is not from $REPO_GPG_KEYID"
	if [[ -f "$target/SHA256SUMS" ]] && cmp -s "$source/SHA256SUMS" "$target/SHA256SUMS"; then
		echo "Stable already contains exact A1 CM5 release $(cat "$target/RELEASE_VERSION")"
		return 0
	fi
	parent=$(dirname "$repo_root")
	mkdir -p "$parent"
	stage=$(mktemp -d "${parent}/.dshanpi-a1-cm5-promote.XXXXXX")
	cleanup_paths+=("$stage")
	cp -a "$source/." "$stage/"
	archive_target "$target" stable "$repo_root"
	mv "$stage" "$target"
	echo "Promoted exact A1 CM5 release $(cat "$target/RELEASE_VERSION") from testing to stable"
}

case "$command_name" in
	publish)
		[[ $# -ge 3 && $# -le 4 ]] || { usage; exit 2; }
		publish_testing "$2" "$(realpath "$3")" "${4:-$default_repo_root}"
		;;
	promote)
		[[ $# -le 2 ]] || { usage; exit 2; }
		promote_testing "${2:-$default_repo_root}"
		;;
	serve)
		[[ $# -le 3 ]] || { usage; exit 2; }
		web_root=${2:-$default_web_root}
		validate_repo_root "$web_root"
		exec python3 -m http.server "${3:-8080}" --directory "$web_root"
		;;
	*) usage; exit 2 ;;
esac
