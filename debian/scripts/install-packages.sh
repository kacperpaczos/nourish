#!/usr/bin/env bash
# Stage the built tree into debian/tmp with the final FHS layout.
# The split into binary packages is declarative: debian/<pkg>.install files
# consumed by dh_install, with dh_missing --fail-missing as the completeness
# gate (debian/rules). Add new files HERE and in exactly one .install file.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STAGE="$ROOT/debian/stage"
SESSION="$ROOT/debian/session"
TMP="$ROOT/debian/tmp"

rm -rf "$TMP"
install -d \
	"$TMP/usr/bin" \
	"$TMP/usr/libexec/y5-compositor" \
	"$TMP/usr/lib/systemd/user" \
	"$TMP/usr/lib/udev/rules.d" \
	"$TMP/usr/share/wayland-sessions" \
	"$TMP/usr/share/applications" \
	"$TMP/usr/share/y5-compositor/mx-gesture-daemon" \
	"$TMP/etc/pam.d" \
	"$TMP/etc/xdg/xdg-desktop-portal"

# Binaries (stage names → shipped names).
install -m755 "$STAGE/binaries/y5.compositor" "$TMP/usr/bin/y5.compositor"
install -m755 "$STAGE/binaries/y5.compositor.settings" "$TMP/usr/bin/y5.compositor.settings"
install -m755 "$STAGE/binaries/compositor-developer-tool" "$TMP/usr/bin/y5.compositor.monitor"
install -m755 "$STAGE/binaries/y5-polkit-agent" "$TMP/usr/bin/y5-polkit-agent"
install -m755 "$STAGE/binaries/xwayland-satellite" "$TMP/usr/bin/xwayland-satellite"
install -m755 "$STAGE/binaries/mx-gesture-daemon" "$TMP/usr/bin/mx-gesture-daemon"

# Session entry, wrapper, PAM, portal config.
install -m755 "$SESSION/session" "$TMP/usr/libexec/y5-compositor/session"
install -m644 "$SESSION/y5-compositor.desktop" "$TMP/usr/share/wayland-sessions/y5-compositor.desktop"
install -m644 "$SESSION/y5.compositor.monitor.desktop" "$TMP/usr/share/applications/y5.compositor.monitor.desktop"
install -m644 "$SESSION/y5-lock" "$TMP/etc/pam.d/y5-lock"
install -m644 "$SESSION/y5-portals.conf" "$TMP/etc/xdg/xdg-desktop-portal/y5-portals.conf"

# systemd user units.
install -m644 "$SESSION/y5.service" "$TMP/usr/lib/systemd/user/y5.service"
install -m644 "$SESSION/y5.shutdown.target" "$TMP/usr/lib/systemd/user/y5.shutdown.target"
install -m644 "$SESSION/y5-polkit-agent.service" "$TMP/usr/lib/systemd/user/y5-polkit-agent.service"
install -m644 "$SESSION/xwayland.service" "$TMP/usr/lib/systemd/user/xwayland.service"
install -m644 "$SESSION/mx-gesture-daemon.service" "$TMP/usr/lib/systemd/user/mx-gesture-daemon.service"

# MX gesture daemon extras.
install -m644 "$STAGE/templates/mx/42-logitech-hidpp.rules" "$TMP/usr/lib/udev/rules.d/42-logitech-hidpp.rules"
install -m644 "$STAGE/templates/mx/config.example.toml" "$TMP/usr/share/y5-compositor/mx-gesture-daemon/config.example.toml"

echo "install-packages: staged $(find "$TMP" -type f | wc -l) files into debian/tmp" >&2
