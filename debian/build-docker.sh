#!/usr/bin/env bash
# Build the y5-compositor .deb inside an Ubuntu 26.04 container (offline source).
# Prerequisites: cargo-vendor/ and npm-vendor/ present (from make-orig / vendor-all).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
PARENT="$(cd "$ROOT/.." && pwd)"
NAME="$(basename "$ROOT")"

if [ ! -d "$ROOT/cargo-vendor/compositor" ] || [ ! -f "$ROOT/npm-vendor/logs-node_modules.tar.xz" ]; then
	echo "build-docker: missing cargo-vendor/ or npm-vendor/; run:" >&2
	echo "  debian/scripts/make-orig.sh --allow-dirty" >&2
	echo "  # then extract vendors, or: debian/scripts/vendor-all.sh" >&2
	exit 1
fi

docker run --rm \
	-v "$PARENT:/build-parent:rw" \
	-w "/build-parent/$NAME" \
	-e DEBIAN_FRONTEND=noninteractive \
	-e Y5_SKIP_LINT=1 \
	-e CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-2}" \
	ubuntu:26.04 \
	bash -c '
set -euo pipefail
apt-get update -qq
apt-get install -y -qq devscripts debhelper lintian \
	clang libclang-dev pkg-config git ca-certificates \
	protobuf-compiler libprotobuf-dev libpam0g-dev \
	libdisplay-info-dev libinput-dev libseat-dev libxkbcommon-dev libpixman-1-dev \
	libsystemd-dev libudev-dev libwayland-dev wayland-protocols \
	libegl-dev libgles-dev libgl-dev libgbm-dev libglvnd-dev libvulkan-dev libdrm-dev \
	libavcodec-dev libavformat-dev libavutil-dev libavfilter-dev libavdevice-dev \
	libswscale-dev libswresample-dev libdbus-1-dev libpulse-dev \
	nodejs npm libwebkit2gtk-4.1-dev libsoup-3.0-dev libgtk-3-dev librsvg2-dev \
	libayatana-appindicator3-dev libxcb1-dev libxcb-cursor-dev
apt-get clean && rm -rf /var/lib/apt/lists/*
echo "=== building (offline bundle) ==="
debuild --no-conf -us -uc -b
ls -lah ../*.deb ../*_amd64.buildinfo 2>/dev/null || true
'
