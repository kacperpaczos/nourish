#!/usr/bin/env bash
# Build source package for Launchpad PPA upload.
# Requires: devscripts, successful binary build (debian/stage/binaries/).
# Upload: dput ppa:kacperpaczos/y5 ../y5-compositor_*_source.changes
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
PARENT="$(cd "$ROOT/.." && pwd)"
NAME="$(basename "$ROOT")"
PPA="${1:-kacperpaczos/y5}"

docker run --rm \
	-v "$PARENT:/build-parent:rw" \
	-w "/build-parent/$NAME" \
	-e DEBIAN_FRONTEND=noninteractive \
	-e DEBUILD_LINTIAN=no \
	ubuntu:26.04 \
	bash -c '
set -euo pipefail
apt-get update -qq
apt-get install -y -qq devscripts debhelper
apt-get clean && rm -rf /var/lib/apt/lists/*
printf "y\n" | debuild --no-conf -us -uc -S -sa -d </dev/null
ls -la ../*_source.changes ../*.dsc ../*.tar.* 2>/dev/null || true
'

if command -v dput >/dev/null 2>&1; then
	CHANGES="$(ls -1 "$PARENT"/y5-compositor_*_source.changes 2>/dev/null | sort -V | tail -1)"
	if [ -n "$CHANGES" ] && gpg --list-secret-keys >/dev/null 2>&1; then
		echo "Uploading $CHANGES to ppa:'"$PPA"'"
		dput "ppa:$PPA" "$CHANGES"
	else
		echo "Source package ready. Upload manually when GPG is configured:"
		echo "  dput ppa:$PPA <path-to-source.changes>"
	fi
else
	echo "Source package artifacts are in: $PARENT"
	echo "Install devscripts and run: dput ppa:$PPA <source.changes>"
fi
