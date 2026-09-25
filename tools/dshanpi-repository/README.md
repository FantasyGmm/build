# DShanPI local APT repository prototype

This directory creates a signed Ubuntu 24.04 (`noble`) repository for the
DShanPI A1 and A1 CM5. It publishes only packages matching
`package-allowlist.txt` and rejects conflicting package/version/architecture
duplicates.

Build the client packages with the organization's public signing key:

```bash
tools/dshanpi-repository/build-client-packages.sh public.asc \
  http://127.0.0.1:8080 output/dshanpi-repository/incoming
```

Copy one reviewed version of every release package into an incoming directory,
import the generated client packages, and publish a signed testing snapshot:

```bash
export REPO_GPG_KEYID=<full-fingerprint>
tools/dshanpi-repository/publish-local.sh publish testing incoming
tools/dshanpi-repository/publish-local.sh serve
```

After hardware upgrade testing, atomically promote the exact snapshot:

```bash
tools/dshanpi-repository/publish-local.sh promote
```

New production images should install `dshanpi-system-repository` in the final
image-customization stage. Existing systems install the keyring package first,
then the repository package. U-Boot is held by default; an administrator must
explicitly run `apt-mark unhold` before a bootloader upgrade.
