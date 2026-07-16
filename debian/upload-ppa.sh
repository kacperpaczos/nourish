#!/usr/bin/env bash
# Build quilt source package and upload to Launchpad PPA.
# Usage: debian/upload-ppa.sh [ppa-name]
# Default PPA: kacperpaczos/nourish
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
PARENT="$(cd "$ROOT/.." && pwd)"
NAME="$(basename "$ROOT")"
PPA="${1:-kacperpaczos/nourish}"
VERSION="$(tr -d '[:space:]' <"$ROOT/VERSION")"
ORIG="$PARENT/y5-compositor_${VERSION}.orig.tar.xz"

cd "$ROOT"
# Keep cargo-vendor/ for local rebuilds; only strip packaging leftovers that
# must never enter debian.tar.xz.
rm -rf debian/stage debian/tmp debian/tmp-stage debian/cargo-home \
	debian/cargo-home-build debian/cargo-target debian/rustup-home \
	debian/rustup-home-empty debian/.debhelper \
	debian/y5-compositor debian/y5-compositor-settings \
	debian/y5-compositor-monitor debian/y5-polkit-agent \
	debian/y5-xwayland-satellite debian/y5-mx-gesture-daemon \
	debian/y5-compositor-full \
	debian/files debian/package.tar.gz debian/SHA256SUMS \
	debian/*debhelper* debian/debhelper-build-stamp

if [ ! -f "$ORIG" ]; then
	echo ">> creating orig tarball (needs network for cargo vendor / npm ci)" >&2
	# No --allow-dirty here: a published orig must be reproducible from a commit.
	debian/scripts/make-orig.sh
fi

docker run --rm \
	-v "$PARENT:/build-parent:rw" \
	-w "/build-parent/$NAME" \
	-e DEBIAN_FRONTEND=noninteractive \
	-e HOST_UID="$(id -u)" \
	-e HOST_GID="$(id -g)" \
	ubuntu:26.04 \
	bash -c '
set -euo pipefail
# The build runs as root inside the container; hand artefacts back to the
# invoking user even on failure, or clean-tree/git start needing sudo.
trap "chown -R \"$HOST_UID:$HOST_GID\" \"$PWD\" 2>/dev/null; find .. -maxdepth 1 -type f -exec chown \"$HOST_UID:$HOST_GID\" {} + 2>/dev/null || true" EXIT
apt-get update -qq
apt-get install -y -qq devscripts debhelper lintian
apt-get clean && rm -rf /var/lib/apt/lists/*
# -d: skip Build-Depends on the packager host; Launchpad enforces them.
debuild --no-conf -S -sa -d
ls -lah ../*_source.changes ../*.dsc ../*.tar.* 2>/dev/null || true
'

CHANGES="$(ls -1 "$PARENT"/y5-compositor_*_source.changes 2>/dev/null | sort -V | tail -1)"
if [ -z "$CHANGES" ]; then
	echo "upload-ppa: no *_source.changes produced" >&2
	exit 1
fi

if command -v dput >/dev/null 2>&1 && gpg --list-secret-keys >/dev/null 2>&1; then
	echo "Uploading $CHANGES to ppa:$PPA"
	dput "ppa:$PPA" "$CHANGES"
else
	echo "Source package ready: $CHANGES"
	echo "Sign and upload:"
	echo "  debsign -k <keyid> $CHANGES"
	echo "  dput ppa:$PPA $CHANGES"
fi
