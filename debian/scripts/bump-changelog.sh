#!/usr/bin/env bash
# Start a new debian/changelog entry with dch, keeping VERSION the single
# source of truth (audit finding H5): entries are never hand-typed, and the
# target version is derived, not invented.
#
# Usage:
#   debian/scripts/bump-changelog.sh            # next -1ubuntuN for VERSION
#   debian/scripts/bump-changelog.sh 1.5.0      # first entry of a new
#                                               # upstream version (also
#                                               # updates the VERSION file)
#
# After running, edit the entry (dch opens $EDITOR unless DEBEMAIL/DEBFULLNAME
# make it non-interactive) and commit VERSION + debian/changelog together.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

command -v dch >/dev/null 2>&1 || {
	echo "bump-changelog: dch not found (install Ubuntu package 'devscripts')" >&2
	exit 1
}

DIST="resolute"
export DEBEMAIL="${DEBEMAIL:-kacperpaczos2024@proton.me}"
export DEBFULLNAME="${DEBFULLNAME:-Kacper Paczos}"

CUR="$(tr -d '[:space:]' <VERSION)"
NEW_UPSTREAM="${1:-}"

if [ -n "$NEW_UPSTREAM" ]; then
	case "$NEW_UPSTREAM" in
		[0-9]*.[0-9]*.[0-9]*) : ;;
		*) echo "bump-changelog: '$NEW_UPSTREAM' is not MAJOR.MINOR.PATCH" >&2; exit 1 ;;
	esac
	TARGET="${NEW_UPSTREAM}-1ubuntu1"
	printf '%s\n' "$NEW_UPSTREAM" >VERSION
	echo ">> VERSION: $CUR -> $NEW_UPSTREAM (remember: a new upstream version needs a new orig)" >&2
else
	TOP="$(dpkg-parsechangelog -SVersion)"
	case "$TOP" in
		"$CUR-"*) : ;;
		*)
			echo "bump-changelog: changelog top ($TOP) does not match VERSION ($CUR)" >&2
			echo "bump-changelog: pass the new upstream version explicitly to move both" >&2
			exit 1
			;;
	esac
	REV="${TOP##*ubuntu}"
	case "$REV" in
		[0-9]*) : ;;
		*) echo "bump-changelog: cannot parse ubuntu revision from '$TOP'" >&2; exit 1 ;;
	esac
	TARGET="${CUR}-1ubuntu$((REV + 1))"
fi

echo ">> new entry: $TARGET ($DIST)" >&2
dch --newversion "$TARGET" --distribution "$DIST" --force-distribution ""
echo "bump-changelog: edit debian/changelog, then commit it (with VERSION if bumped)" >&2
