#!/usr/bin/env bash
# Copy a usable Rust sysroot into rust-toolchain-dist/ for offline Launchpad builds.
# Ubuntu resolute's rustc (1.93) is below this tree's MSRV (Bevy needs >= 1.95).
set -euo pipefail

ROOT="$(cd "${1:-$(dirname "${BASH_SOURCE[0]}")/../..}" && pwd)"
DEST="$ROOT/rust-toolchain-dist"
SYSROOT="$(rustc --print sysroot)"

if [ ! -x "$SYSROOT/bin/rustc" ] || [ ! -x "$SYSROOT/bin/cargo" ]; then
	echo "bundle-rust-toolchain: need a working rustc/cargo (rustup stable is fine)" >&2
	exit 1
fi

VER="$("$SYSROOT/bin/rustc" --version)"
echo ">> bundling $VER from $SYSROOT" >&2
rm -rf "$DEST"
mkdir -p "$DEST"
# Copy the sysroot; exclude bulky docs if present.
rsync -a --delete \
	--exclude='share/doc' \
	--exclude='share/man' \
	"$SYSROOT/" "$DEST/"

"$DEST/bin/rustc" --version >&2
"$DEST/bin/cargo" --version >&2
du -sh "$DEST" >&2
echo "bundle-rust-toolchain: wrote $DEST" >&2
