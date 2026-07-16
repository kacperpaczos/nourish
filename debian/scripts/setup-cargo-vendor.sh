#!/usr/bin/env bash
# Install a per-project .cargo/config.toml that points at cargo-vendor/<name>.
# Usage: setup-cargo-vendor.sh <name> <project-dir>
set -euo pipefail

NAME="${1:?}"
PROJ="$(cd "${2:?}" && pwd)"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VENDOR="$ROOT/cargo-vendor/$NAME"
CFG="$PROJ/.cargo/config.toml"

[ -d "$VENDOR" ] || { echo "setup-cargo-vendor: missing $VENDOR (run vendor-all / make-orig)" >&2; exit 1; }

mkdir -p "$PROJ/.cargo"
if [ -f "$CFG" ] && ! grep -q 'y5-debian-vendor' "$CFG" 2>/dev/null; then
	cp -a "$CFG" "${CFG}.y5-bak"
fi

{
	echo "# y5-debian-vendor — generated; do not edit"
	if [ -f "${CFG}.y5-bak" ]; then
		# Keep pre-existing settings (e.g. [env]) above the source rewrite.
		cat "${CFG}.y5-bak"
		echo
	fi
	echo "[source.crates-io]"
	echo "replace-with = \"vendored-sources\""
	echo
	echo "[source.vendored-sources]"
	echo "directory = \"$VENDOR\""
} >"$CFG"
