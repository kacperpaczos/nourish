#!/usr/bin/env bash
# Split debian/stage into binary package trees under debian/<pkg>/.
# Docs/changelog/copyright are left to dh_installdocs / dh_installchangelogs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STAGE="$ROOT/debian/stage"
SESSION="$ROOT/debian/session"

pkg_root() {
	echo "$ROOT/debian/$1"
}

# --- y5-compositor (core) -------------------------------------------------
CORE="$(pkg_root y5-compositor)"
rm -rf "$CORE"
install -d "$CORE/usr/bin"
install -d "$CORE/usr/libexec/y5-compositor"
install -d "$CORE/usr/lib/systemd/user"
install -d "$CORE/usr/share/wayland-sessions"
install -d "$CORE/etc/pam.d"
install -d "$CORE/etc/xdg/xdg-desktop-portal"
install -m755 "$STAGE/binaries/y5.compositor" "$CORE/usr/bin/y5.compositor"
install -m755 "$SESSION/session" "$CORE/usr/libexec/y5-compositor/session"
install -m644 "$SESSION/y5-compositor.desktop" "$CORE/usr/share/wayland-sessions/y5-compositor.desktop"
install -m644 "$SESSION/y5.service" "$CORE/usr/lib/systemd/user/y5.service"
install -m644 "$SESSION/y5.shutdown.target" "$CORE/usr/lib/systemd/user/y5.shutdown.target"
install -m644 "$SESSION/y5-lock" "$CORE/etc/pam.d/y5-lock"
install -m644 "$SESSION/y5-portals.conf" "$CORE/etc/xdg/xdg-desktop-portal/y5-portals.conf"

# --- y5-compositor-settings -----------------------------------------------
SET="$(pkg_root y5-compositor-settings)"
rm -rf "$SET"
install -d "$SET/usr/bin"
install -m755 "$STAGE/binaries/y5.compositor.settings" "$SET/usr/bin/y5.compositor.settings"

# --- y5-compositor-monitor ------------------------------------------------
MON="$(pkg_root y5-compositor-monitor)"
rm -rf "$MON"
install -d "$MON/usr/bin"
install -d "$MON/usr/share/applications"
install -m755 "$STAGE/binaries/compositor-developer-tool" "$MON/usr/bin/y5.compositor.monitor"
install -m644 "$SESSION/y5.compositor.monitor.desktop" \
	"$MON/usr/share/applications/y5.compositor.monitor.desktop"

# --- y5-polkit-agent ------------------------------------------------------
PK="$(pkg_root y5-polkit-agent)"
rm -rf "$PK"
install -d "$PK/usr/bin"
install -d "$PK/usr/lib/systemd/user"
install -m755 "$STAGE/binaries/y5-polkit-agent" "$PK/usr/bin/y5-polkit-agent"
install -m644 "$SESSION/y5-polkit-agent.service" "$PK/usr/lib/systemd/user/y5-polkit-agent.service"

# --- y5-xwayland-satellite ------------------------------------------------
XW="$(pkg_root y5-xwayland-satellite)"
rm -rf "$XW"
install -d "$XW/usr/bin"
install -d "$XW/usr/lib/systemd/user"
install -m755 "$STAGE/binaries/xwayland-satellite" "$XW/usr/bin/xwayland-satellite"
install -m644 "$SESSION/xwayland.service" "$XW/usr/lib/systemd/user/xwayland.service"

# --- y5-mx-gesture-daemon -------------------------------------------------
MX="$(pkg_root y5-mx-gesture-daemon)"
rm -rf "$MX"
install -d "$MX/usr/bin"
install -d "$MX/usr/lib/systemd/user"
install -d "$MX/usr/lib/udev/rules.d"
install -d "$MX/usr/share/y5-compositor/mx-gesture-daemon"
install -m755 "$STAGE/binaries/mx-gesture-daemon" "$MX/usr/bin/mx-gesture-daemon"
install -m644 "$SESSION/mx-gesture-daemon.service" "$MX/usr/lib/systemd/user/mx-gesture-daemon.service"
install -m644 "$STAGE/templates/mx/42-logitech-hidpp.rules" \
	"$MX/usr/lib/udev/rules.d/42-logitech-hidpp.rules"
install -m644 "$STAGE/templates/mx/config.example.toml" \
	"$MX/usr/share/y5-compositor/mx-gesture-daemon/config.example.toml"

# --- y5-compositor-full (arch: all metapackage — empty payload) ------------
rm -rf "$(pkg_root y5-compositor-full)"
mkdir -p "$(pkg_root y5-compositor-full)"

echo "install-packages: populated debian/y5-* package trees" >&2
