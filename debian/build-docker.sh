#!/usr/bin/env bash
# Build the y5-compositor .deb inside an Ubuntu 26.04 container.
# Usage: debian/build-docker.sh
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
PARENT="$(cd "$ROOT/.." && pwd)"
NAME="$(basename "$ROOT")"

docker run --rm \
	-v "$PARENT:/build-parent:rw" \
	-w "/build-parent/$NAME" \
	-e DEBIAN_FRONTEND=noninteractive \
	-e DEBUILD_LINTIAN=no \
	-e Y5_SKIP_LINT=1 \
	-e CARGO_BUILD_JOBS=2 \
	ubuntu:26.04 \
	bash -c '
set -euo pipefail
apt-get update -qq
apt-get install -y -qq devscripts debhelper build-essential equivs git curl ca-certificates \
	clang libclang-dev pkg-config protobuf-compiler libprotobuf-dev libpam0g-dev \
	libdisplay-info-dev libinput-dev libseat-dev libxkbcommon-dev libpixman-1-dev \
	libsystemd-dev libudev-dev libwayland-dev wayland-protocols \
	libegl-dev libgles-dev libgl-dev libgbm-dev libglvnd-dev libvulkan-dev libdrm-dev \
	libavcodec-dev libavformat-dev libavutil-dev libavfilter-dev libavdevice-dev \
	libswscale-dev libswresample-dev libdbus-1-dev libpulse-dev \
	nodejs npm libwebkit2gtk-4.1-dev libsoup-3.0-dev libgtk-3-dev librsvg2-dev \
	libayatana-appindicator3-dev libxcb1-dev libxcb-cursor-dev
apt-get clean && rm -rf /var/lib/apt/lists/*
if [ ! -f debian/stage/binaries/y5.compositor ]; then
	echo "=== building binaries (prepare.sh) ==="
	debian/rules build
fi
echo "=== packaging (.deb) ==="
debuild --no-conf -us -uc -b -d
ls -la ../*.deb ../*_amd64.buildinfo 2>/dev/null || true
'
