#!/usr/bin/env bash
# Remove build artefacts that must never enter a source upload.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

rm -rf \
	debian/stage \
	debian/tmp \
	debian/tmp-stage \
	debian/cargo-home \
	debian/cargo-home-build \
	debian/cargo-target \
	debian/rustup-home \
	debian/rustup-init \
	debian/files \
	debian/package.tar.gz \
	debian/SHA256SUMS \
	debian/y5-compositor \
	debian/.debhelper \
	cargo-vendor \
	npm-vendor \
	rust-toolchain-dist \
	debian/rustup-home-empty

# Per-crate/workspace Cargo target dirs and node_modules (never vendor/).
find . -type d \( -name target -o -name node_modules \) \
	-not -path './vendor/*' \
	-not -path './.git/*' \
	-prune -exec rm -rf {} + 2>/dev/null || true

# Generated offline cargo configs (restored from .y5-bak if present).
find . -type f -name 'config.toml' -path '*/.cargo/*' \
	-not -path './vendor/*' \
	-not -path './.cargo/config.toml' \
	2>/dev/null | while read -r cfg; do
	if grep -q 'y5-debian-vendor' "$cfg" 2>/dev/null; then
		bak="${cfg}.y5-bak"
		if [ -f "$bak" ]; then
			mv -f "$bak" "$cfg"
		else
			rm -f "$cfg"
		fi
	fi
done

echo "clean-tree: removed build artefacts under $ROOT" >&2
