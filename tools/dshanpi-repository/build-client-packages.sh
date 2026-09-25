#!/usr/bin/env bash
set -euo pipefail

usage() {
	echo "Usage: $0 <public-key.asc|gpg> <repository-base-url> [output-dir] [version]" >&2
	exit 2
}

[[ $# -ge 2 ]] || usage
key_file=$(realpath "$1")
base_url=${2%/}
output_dir=${3:-output/dshanpi-repository/client-packages}
version=${4:-1:2026.09.1}
[[ "$base_url" == https://* || "$base_url" == http://127.0.0.1:* || "$base_url" == http://localhost:* ]] || {
	echo "Repository URL must use HTTPS (localhost HTTP is allowed for tests)" >&2
	exit 2
}
mkdir -p "$output_dir"
work_dir=$(mktemp -d)
trap 'rm -rf -- "$work_dir"' EXIT

mkdir -p "$work_dir/keyring/DEBIAN" "$work_dir/keyring/usr/share/keyrings"
cat > "$work_dir/keyring/DEBIAN/control" <<- EOF
Package: dshanpi-archive-keyring
Version: $version
Architecture: all
Maintainer: DShanPI <support@dshanpi.com>
Section: admin
Priority: optional
Description: DShanPI official APT archive signing key
EOF
if gpg --batch --show-keys "$key_file" >/dev/null 2>&1; then
	gpg --batch --yes --dearmor --output "$work_dir/keyring/usr/share/keyrings/dshanpi-archive-keyring.gpg" "$key_file"
else
	cp "$key_file" "$work_dir/keyring/usr/share/keyrings/dshanpi-archive-keyring.gpg"
fi

mkdir -p "$work_dir/repository/DEBIAN" "$work_dir/repository/etc/apt/sources.list.d"
cat > "$work_dir/repository/DEBIAN/control" <<- EOF
Package: dshanpi-system-repository
Version: $version
Architecture: all
Maintainer: DShanPI <support@dshanpi.com>
Depends: dshanpi-archive-keyring (= $version)
Section: admin
Priority: optional
Description: DShanPI official stable system update repository
EOF
cat > "$work_dir/repository/etc/apt/sources.list.d/dshanpi.sources" <<- EOF
Types: deb
URIs: ${base_url}/stable
Suites: noble
Components: main
Architectures: arm64 all
Signed-By: /usr/share/keyrings/dshanpi-archive-keyring.gpg
EOF
cat > "$work_dir/repository/DEBIAN/postinst" <<- 'EOF'
#!/bin/sh
set -e
for package in linux-u-boot-dshanpi-a1-vendor linux-u-boot-dshanpi-a1-cm5-vendor; do
	if dpkg-query -W -f='${db:Status-Status}' "$package" 2>/dev/null | grep -q '^installed$'; then
		apt-mark hold "$package" >/dev/null
	fi
done
exit 0
EOF
chmod 0755 "$work_dir/repository/DEBIAN/postinst"

dpkg-deb --root-owner-group --build "$work_dir/keyring" "$output_dir/dshanpi-archive-keyring_${version#*:}_all.deb" >/dev/null
dpkg-deb --root-owner-group --build "$work_dir/repository" "$output_dir/dshanpi-system-repository_${version#*:}_all.deb" >/dev/null
sha256sum "$output_dir"/*.deb
