#!/usr/bin/env bash
# Copy a usable Rust sysroot into rust-toolchain-dist/ for offline Launchpad builds.
# Ubuntu resolute's rustc (1.93) is below this tree's MSRV (Bevy needs >= 1.95).
set -euo pipefail

ROOT="$(cd "${1:-$(dirname "${BASH_SOURCE[0]}")/../..}" && pwd)"
DEST="$ROOT/rust-toolchain-dist"
SYSROOT="$(rustc --print sysroot)"

# Pin the bundled toolchain so the orig is not "whatever the maintainer's
# rustup happens to hold". Bump deliberately, in a reviewed commit.
PINNED_RUSTC="1.97.0"

if [ ! -x "$SYSROOT/bin/rustc" ] || [ ! -x "$SYSROOT/bin/cargo" ]; then
	echo "bundle-rust-toolchain: need a working rustc/cargo (rustup stable is fine)" >&2
	exit 1
fi

VER="$("$SYSROOT/bin/rustc" --version)"
case "$VER" in
	"rustc $PINNED_RUSTC "*) ;;
	*)
		echo "bundle-rust-toolchain: local toolchain is '$VER' but the pin is $PINNED_RUSTC." >&2
		echo "bundle-rust-toolchain: install it (rustup toolchain install $PINNED_RUSTC && rustup default $PINNED_RUSTC)" >&2
		echo "bundle-rust-toolchain: or bump PINNED_RUSTC in this script in a reviewed commit." >&2
		exit 1
		;;
esac
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
# Auditable record of what was bundled and from where.
{
	echo "bundled: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
	echo "rustc: $("$DEST/bin/rustc" --version)"
	echo "cargo: $("$DEST/bin/cargo" --version)"
	echo "source sysroot: $SYSROOT"
	echo "host: $(uname -srm)"
} >"$DEST/BUNDLE-INFO.txt"
du -sh "$DEST" >&2
echo "bundle-rust-toolchain: wrote $DEST" >&2
