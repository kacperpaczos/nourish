#!/usr/bin/env bash
# Install built binaries and packaged session/config files into the debian/tmp tree.
set -euo pipefail

DEST="${1:?usage: install-from-stage.sh <destdir>}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGE="$ROOT/debian/stage"
SESSION="$ROOT/debian/session"

install -d "$DEST/usr/bin"
install -d "$DEST/usr/lib/systemd/user"
install -d "$DEST/usr/share/wayland-sessions"
install -d "$DEST/usr/share/applications"
install -d "$DEST/etc/pam.d"
install -d "$DEST/etc/udev/rules.d"
install -d "$DEST/etc/xdg/xdg-desktop-portal"
install -d "$DEST/usr/share/y5-compositor/mx-gesture-daemon"
install -d "$DEST/usr/share/doc/y5-compositor"

# Binaries from prepare.sh stage.
install -m755 "$STAGE/binaries/y5.compositor" "$DEST/usr/bin/y5.compositor"
install -m755 "$STAGE/binaries/y5.compositor.dev" "$DEST/usr/bin/y5.compositor.dev"
install -m755 "$STAGE/binaries/y5.compositor.settings" "$DEST/usr/bin/y5.compositor.settings"
install -m755 "$STAGE/binaries/compositor-developer-tool" "$DEST/usr/bin/y5.compositor.monitor"
install -m755 "$STAGE/binaries/y5-polkit-agent" "$DEST/usr/bin/y5-polkit-agent"
install -m755 "$STAGE/binaries/mx-gesture-daemon" "$DEST/usr/bin/mx-gesture-daemon"
install -m755 "$STAGE/binaries/xwayland-satellite" "$DEST/usr/bin/xwayland-satellite"

# Session wrapper and display-manager entry.
install -m755 "$SESSION/y5.compositor.desktop" "$DEST/usr/bin/y5.compositor.desktop"
install -m644 "$SESSION/y5-compositor.desktop" "$DEST/usr/share/wayland-sessions/y5-compositor.desktop"
install -m644 "$SESSION/y5.compositor.monitor.desktop" "$DEST/usr/share/applications/y5.compositor.monitor.desktop"

# systemd user units (system-wide, available to every user).
for unit in y5.service y5.shutdown.target y5-polkit-agent.service xwayland.service mx-gesture-daemon.service; do
	install -m644 "$SESSION/$unit" "$DEST/usr/lib/systemd/user/$unit"
done

# System configuration.
install -m644 "$SESSION/y5-lock" "$DEST/etc/pam.d/y5-lock"
install -m644 "$STAGE/templates/mx/42-logitech-hidpp.rules" "$DEST/etc/udev/rules.d/42-logitech-hidpp.rules"
install -m644 "$SESSION/y5-portals.conf" "$DEST/etc/xdg/xdg-desktop-portal/y5-portals.conf"
install -m644 "$STAGE/templates/mx/config.example.toml" "$DEST/usr/share/y5-compositor/mx-gesture-daemon/config.example.toml"

# Documentation.
install -m644 "$ROOT/debian/README.Debian" "$DEST/usr/share/doc/y5-compositor/README.Debian"
