#!/usr/bin/env bash
# Offline Debian/PPA build into debian/stage (Track B — see document/DISTRIBUTION.md).
# Must NOT call compositor.installer/prepare.sh or consume Track A package.tar.gz.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

# Refuse Fedora/tarball installer env so Track A stage is never reused as a PPA input.
if [ -n "${Y5_INSTALL_STAGE:-}" ]; then
	echo "build-bundle: refusing Y5_INSTALL_STAGE=${Y5_INSTALL_STAGE}" >&2
	echo "build-bundle: Debian packaging must compile via this script (see document/DISTRIBUTION.md)" >&2
	exit 1
fi
if [ -n "${Y5_REUSE_PREBUILT:-}" ] || [ -n "${Y5_USE_PREPARE_STAGE:-}" ]; then
	echo "build-bundle: prebuilt-reuse flags are not supported on the Debian track" >&2
	exit 1
fi
case "${Y5_DEBIAN_STAGE:-}" in
	*compositor.installer/dist*|*y5-install*)
		echo "build-bundle: Y5_DEBIAN_STAGE looks like a Track A installer path; refusing" >&2
		exit 1
		;;
esac

SCRIPTS="$ROOT/debian/scripts"
STAGE="${Y5_DEBIAN_STAGE:-$ROOT/debian/stage}"
BIN="$STAGE/binaries"
TPL="$STAGE/templates"
TARGET_DIR="${Y5_TARGET_DIR:-$ROOT/debian/cargo-target}"
LOGS_DIR="$ROOT/compositor.developer/developer.tool/developer.tool.window/logs"

export CARGO_NET_OFFLINE=true
export CARGO_HOME="${CARGO_HOME:-$ROOT/debian/cargo-home-build}"
export Y5_SKIP_LINT="${Y5_SKIP_LINT:-1}"
export Y5_TARGET_DIR="$TARGET_DIR"
# Cap parallelism (linking Bevy/wgpu binaries is memory-hungry; uncapped
# cargo OOMs small builders). debian/rules passes DEB_BUILD_OPTIONS through.
export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-2}"
# Link hardening for the Rust binaries. NOTE: a RUSTFLAGS env var replaces
# the repo-root .cargo/config.toml rustflags wholesale, so it must repeat
# the "-A warnings" from there. This is deliberate and packaging-only.
export RUSTFLAGS="-A warnings -C link-arg=-Wl,-z,relro -C link-arg=-Wl,-z,now"
# Always rebuild stage for packaging (never skip when binaries already exist).
rm -rf "$STAGE"
mkdir -p "$CARGO_HOME" "$TARGET_DIR" "$BIN" "$TPL/pam" "$TPL/mx" "$TPL/xwayland"

if [ ! -d "$ROOT/cargo-vendor/compositor" ]; then
	echo "build-bundle: cargo-vendor/ missing — run debian/scripts/make-orig.sh or vendor-all.sh" >&2
	exit 1
fi
if [ ! -x "$ROOT/rust-toolchain-dist/bin/rustc" ] || [ ! -x "$ROOT/rust-toolchain-dist/bin/cargo" ]; then
	echo "build-bundle: rust-toolchain-dist/ missing — run debian/scripts/bundle-rust-toolchain.sh" >&2
	exit 1
fi
# Prefer the bundled toolchain (MSRV); ignore rustup overrides from rust-toolchain.toml.
export PATH="$ROOT/rust-toolchain-dist/bin:$PATH"
unset RUSTUP_TOOLCHAIN
export RUSTC="$ROOT/rust-toolchain-dist/bin/rustc"
export CARGO="$ROOT/rust-toolchain-dist/bin/cargo"
# Prevent rustup from intercepting if installed on the builder.
export RUSTUP_HOME="${RUSTUP_HOME:-$ROOT/debian/rustup-home-empty}"
mkdir -p "$RUSTUP_HOME"
rustc --version >&2
cargo --version >&2

setup() { "$SCRIPTS/setup-cargo-vendor.sh" "$1" "$2"; }

log() { printf '\n>> %s\n' "$1" >&2; }

log "link.all.sh"
./link.all.sh

# 1) Compositor (udev / native release)
log "compositor (backend-native release)"
LOADER="$(dirname "$(grep -rl --include=Cargo.toml --exclude-dir=target --exclude-dir=node_modules \
	'name *= *"y5_compositor"' "$ROOT"/compositor* | head -n1)")"
setup compositor "$LOADER"
(
	cd "$LOADER"
	"$CARGO" build --release --frozen --offline \
		--no-default-features --features backend-native \
		--target-dir="$TARGET_DIR"
)
install -m755 "$TARGET_DIR/release/y5_compositor" "$BIN/y5.compositor"

# 2) Developer tool (Tauri bare binary)
log "developer tool (tauri --no-bundle)"
setup tauri "$LOGS_DIR/src-tauri"
if [ ! -d "$LOGS_DIR/node_modules" ]; then
	[ -f "$ROOT/npm-vendor/logs-node_modules.tar.xz" ] \
		|| { echo "build-bundle: missing npm-vendor/logs-node_modules.tar.xz" >&2; exit 1; }
	tar -xJf "$ROOT/npm-vendor/logs-node_modules.tar.xz" -C "$LOGS_DIR"
fi
(
	cd "$LOGS_DIR"
	# node_modules + cargo-vendor/tauri make this offline when CARGO_NET_OFFLINE=true
	npm run tauri build -- --no-bundle
)
# Tauri may not forward cargo flags; ensure offline via config + env above.
install -m755 \
	"$LOGS_DIR/src-tauri/target/release/compositor-developer-tool" \
	"$BIN/compositor-developer-tool"

# 3) Polkit agent
log "polkit agent"
POLKIT="$ROOT/compositor.installer/component/pollkit-agent"
setup polkit "$POLKIT"
(
	cd "$POLKIT"
	"$CARGO" build --release --frozen --offline --target-dir="$TARGET_DIR"
)
install -m755 "$TARGET_DIR/release/iced_polkit_agent" "$BIN/y5-polkit-agent"

# 4) MX gesture daemon
log "mx-gesture-daemon"
MX="$ROOT/compositor.installer/component/mx-gesture-daemon"
setup mx "$MX"
(
	cd "$MX"
	"$CARGO" build --release --frozen --offline --target-dir="$TARGET_DIR"
)
install -m755 "$TARGET_DIR/release/mx-gesture-daemon" "$BIN/mx-gesture-daemon"
install -m644 "$MX/42-logitech-hidpp.rules" "$TPL/mx/42-logitech-hidpp.rules"
install -m644 "$MX/config.example.toml" "$TPL/mx/config.example.toml"

# 5) xwayland-satellite
log "xwayland-satellite"
XW="$ROOT/compositor.installer/component/xwayland-satellite/xwayland-fixes"
setup xwayland "$XW"
(
	cd "$XW"
	"$CARGO" build --release --frozen --offline --target-dir="$TARGET_DIR"
)
install -m755 "$TARGET_DIR/release/xwayland-satellite" "$BIN/xwayland-satellite"

# 6) Settings tool
log "settings tool"
SET="$ROOT/compositor.installer/component/settings-editor"
setup settings "$SET"
(
	cd "$SET"
	"$CARGO" build --release --frozen --offline --target-dir="$TARGET_DIR"
)
install -m755 "$TARGET_DIR/release/y5-compositor-settings" "$BIN/y5.compositor.settings"

log "stage ready at $STAGE"
