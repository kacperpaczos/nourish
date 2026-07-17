#!/usr/bin/env bash
# Install the PINNED official Rust toolchain into rust-toolchain-dist/ for
# offline Launchpad builds (Ubuntu's rustc is below this tree's MSRV;
# Bevy needs >= 1.95).
#
# Provenance: the toolchain is downloaded from static.rust-lang.org and
# verified against a pinned SHA-256 — never copied from whatever the
# maintainer's rustup happens to hold. Bump the pin in a reviewed commit
# (update BOTH the version and the checksum, from
# https://static.rust-lang.org/dist/rust-<ver>-<triple>.tar.xz.sha256).
set -euo pipefail

ROOT="$(cd "${1:-$(dirname "${BASH_SOURCE[0]}")/../..}" && pwd)"
DEST="$ROOT/rust-toolchain-dist"

PINNED_RUSTC="1.97.0"
TRIPLE="x86_64-unknown-linux-gnu" # amd64-only for now — see debian/README.source
PINNED_SHA256="1cf17e4905b841d4c8e3f76467ac148d55fb3f54bf213c86f0d287a36471d904"

TARBALL="rust-${PINNED_RUSTC}-${TRIPLE}.tar.xz"
URL="https://static.rust-lang.org/dist/${TARBALL}"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/y5-toolchain"

# Reuse an already-bundled matching toolchain (make-orig --reuse-vendor path).
if [ -x "$DEST/bin/rustc" ] &&
	"$DEST/bin/rustc" --version 2>/dev/null | grep -q "^rustc $PINNED_RUSTC "; then
	echo "bundle-rust-toolchain: $DEST already holds rustc $PINNED_RUSTC — keeping it" >&2
	exit 0
fi

mkdir -p "$CACHE"
if [ ! -f "$CACHE/$TARBALL" ]; then
	echo ">> downloading $URL" >&2
	curl -fL --proto '=https' --tlsv1.2 -o "$CACHE/$TARBALL.part" "$URL"
	mv "$CACHE/$TARBALL.part" "$CACHE/$TARBALL"
fi

echo ">> verifying SHA-256" >&2
echo "$PINNED_SHA256  $CACHE/$TARBALL" | sha256sum -c - >&2

STAGING="$(mktemp -d "${TMPDIR:-/tmp}/y5-toolchain.XXXXXX")"
cleanup() { rm -rf "$STAGING"; }
trap cleanup EXIT

echo ">> unpacking + installing into $DEST" >&2
tar -xJf "$CACHE/$TARBALL" -C "$STAGING"
rm -rf "$DEST"
"$STAGING/rust-${PINNED_RUSTC}-${TRIPLE}/install.sh" \
	--prefix="$DEST" \
	--components=rustc,cargo,rust-std-"$TRIPLE" \
	--disable-ldconfig >/dev/null
# Bulky docs are not needed on a builder.
rm -rf "$DEST/share/doc" "$DEST/share/man"

"$DEST/bin/rustc" --version >&2
"$DEST/bin/cargo" --version >&2
# Auditable record of what was bundled and from where.
{
	echo "bundled: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
	echo "rustc: $("$DEST/bin/rustc" --version)"
	echo "cargo: $("$DEST/bin/cargo" --version)"
	echo "source: $URL"
	echo "sha256: $PINNED_SHA256 (verified)"
	echo "host: $(uname -srm)"
} >"$DEST/BUNDLE-INFO.txt"
du -sh "$DEST" >&2
echo "bundle-rust-toolchain: wrote $DEST" >&2
