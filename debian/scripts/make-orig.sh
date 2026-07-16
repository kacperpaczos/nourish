#!/usr/bin/env bash
# Build y5-compositor_<version>.orig.tar.xz for a quilt source package.
# The orig contains upstream sources + cargo-vendor/ + npm-vendor/ (no debian/).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PARENT="$(cd "$ROOT/.." && pwd)"
cd "$ROOT"

ALLOW_DIRTY=0
REUSE_VENDOR=0
FROM_TREE=0
for arg in "$@"; do
	case "$arg" in
		--allow-dirty) ALLOW_DIRTY=1 ;;
		--reuse-vendor) REUSE_VENDOR=1 ;;
		--from-tree) FROM_TREE=1; ALLOW_DIRTY=1 ;;
		-h | --help)
			echo "Usage: make-orig.sh [--allow-dirty] [--reuse-vendor] [--from-tree]"
			exit 0
			;;
	esac
done

if [ ! -f VERSION ]; then
	echo "make-orig: VERSION file missing" >&2
	exit 1
fi
VERSION="$(tr -d '[:space:]' <VERSION)"
NAME="y5-compositor"
ORIG_BASE="${NAME}-${VERSION}"
ORIG_TAR="${PARENT}/${NAME}_${VERSION}.orig.tar.xz"

# VERSION and debian/changelog must agree, or dpkg-source rejects the pair
# at upload time — fail here instead.
CHVER="$(sed -n '1s/^[^(]*(\([^)]*\)).*/\1/p' debian/changelog)"
case "$CHVER" in
	"$VERSION-"*) ;;
	*)
		echo "make-orig: VERSION ($VERSION) does not match debian/changelog ($CHVER)" >&2
		echo "make-orig: bump one of them (dch -v ${VERSION}-1ubuntu1 ...) and retry" >&2
		exit 1
		;;
esac

if [ "$ALLOW_DIRTY" -eq 0 ]; then
	if ! git -C "$ROOT" diff --quiet || ! git -C "$ROOT" diff --cached --quiet; then
		echo "make-orig: working tree is dirty; commit/stash or pass --allow-dirty" >&2
		exit 1
	fi
fi

STAGING="$(mktemp -d "${TMPDIR:-/tmp}/y5-orig.XXXXXX")"
cleanup() { rm -rf "$STAGING"; }
trap cleanup EXIT

mkdir -p "$STAGING/$ORIG_BASE"
if [ "$FROM_TREE" -eq 1 ]; then
	echo ">> rsync working tree → $STAGING/$ORIG_BASE" >&2
	rsync -a \
		--exclude='.git/' \
		--exclude='debian/' \
		--exclude='cargo-vendor/' \
		--exclude='npm-vendor/' \
		--exclude='rust-toolchain-dist/' \
		--exclude='**/target/' \
		--exclude='**/node_modules/' \
		--exclude='**/.cache/' \
		"$ROOT"/ "$STAGING/$ORIG_BASE"/
else
	echo ">> git archive → $STAGING/$ORIG_BASE" >&2
	git -C "$ROOT" archive HEAD | tar -x -C "$STAGING/$ORIG_BASE"
	rm -rf "$STAGING/$ORIG_BASE/debian"
fi

# Drop accidental artefacts if present in the archive.
rm -rf \
	"$STAGING/$ORIG_BASE/cargo-vendor" \
	"$STAGING/$ORIG_BASE/npm-vendor" \
	"$STAGING/$ORIG_BASE/rust-toolchain-dist"
find "$STAGING/$ORIG_BASE" -type d \( -name target -o -name node_modules \) -prune -exec rm -rf {} + 2>/dev/null || true

if [ "$REUSE_VENDOR" -eq 1 ] && [ -d "$ROOT/cargo-vendor/compositor" ] && [ -f "$ROOT/npm-vendor/logs-node_modules.tar.xz" ]; then
	echo ">> reusing existing cargo-vendor/ and npm-vendor/" >&2
	cp -a "$ROOT/cargo-vendor" "$STAGING/$ORIG_BASE/"
	cp -a "$ROOT/npm-vendor" "$STAGING/$ORIG_BASE/"
else
	echo ">> vendor-all (network required on the maintainer machine)" >&2
	"$ROOT/debian/scripts/vendor-all.sh" "$STAGING/$ORIG_BASE"
fi

if [ "$REUSE_VENDOR" -eq 1 ] && [ -x "$ROOT/rust-toolchain-dist/bin/rustc" ]; then
	echo ">> reusing existing rust-toolchain-dist/" >&2
	cp -a "$ROOT/rust-toolchain-dist" "$STAGING/$ORIG_BASE/"
else
	echo ">> bundle-rust-toolchain (Ubuntu archive rustc is below MSRV)" >&2
	"$ROOT/debian/scripts/bundle-rust-toolchain.sh" "$STAGING/$ORIG_BASE"
fi

echo ">> packing $ORIG_TAR" >&2
tar --owner=0 --group=0 --numeric-owner -C "$STAGING" -cJf "$ORIG_TAR" "$ORIG_BASE"

ls -lh "$ORIG_TAR" >&2
echo "$ORIG_TAR"
