# Distribution tracks

y5 ships through **two independent tracks**. They share source crates and
vendored forks under `vendor/`, but they must **not** share a prebuilt
pipeline or stage directory.

## Track A — Fedora / multiarch tarball (prebuilt)

| Step | Tooling |
|------|---------|
| Build on CI/maintainer host | [`compositor.installer/prepare.sh`](../compositor.installer/prepare.sh) |
| Artifact | `package.tar.gz` + `SHA256SUMS` (extracts to `y5-install/`) |
| End-user install | [`get.sh`](../compositor.installer/get.sh) / [`bootstrap.sh`](../compositor.installer/bootstrap.sh) / `y5-install` |
| Docs | [`compositor.installer/INSTALL.md`](../compositor.installer/INSTALL.md) |

Binaries are compiled **before** the user downloads them. The installer only
pulls runtime shared libraries for the target distro.

CI that produces this track (examples): `ci/scripts/package-installer.sh`,
`.github/workflows/release-rc.yml`, `.github/workflows/multiarch-publish.yml`.

## Track B — Ubuntu PPA (build from source)

| Step | Tooling |
|------|---------|
| Orig + vendors | [`debian/scripts/make-orig.sh`](../debian/scripts/make-orig.sh) |
| Offline compile on Launchpad | [`debian/scripts/build-bundle.sh`](../debian/scripts/build-bundle.sh) via [`debian/rules`](../debian/rules) |
| Artifact | `.deb` packages from `ppa:kacperpaczos/nourish` |
| Docs | [`debian/README.source`](../debian/README.source), [`debian/README.Debian`](../debian/README.Debian) |

Launchpad (or a local Ubuntu 26.04 container) **compiles** from the quilt
source. There is no reuse of Track A tarballs.

## Component inventory (both tracks build these)

| Component | Source path | Staged binary name |
|-----------|-------------|--------------------|
| compositor | `compositor.kernel/kernel.loader` (`y5_compositor`) | `y5.compositor` |
| settings | `compositor.installer/component/settings-editor` | `y5.compositor.settings` |
| monitor (Tauri) | `compositor.developer/.../logs` | `compositor-developer-tool` → `y5.compositor.monitor` |
| polkit agent | `compositor.installer/component/pollkit-agent` | `y5-polkit-agent` |
| xwayland-satellite | `compositor.installer/component/xwayland-satellite/xwayland-fixes` | `xwayland-satellite` |
| mx-gesture-daemon | `compositor.installer/component/mx-gesture-daemon` | `mx-gesture-daemon` |
| installer (Track A only) | `compositor.installer/installer.process` | `y5-install` |

## Hard rules

1. **`debian/` must never call `prepare.sh`.** Packaging uses `build-bundle.sh` only.
2. **Do not upload `debian/stage/`, rustup caches, or Track A `package.tar.gz` inside the Debian source.**
3. **Do not treat Track A tarballs as input to the PPA.** No “build once, publish deb + tarball from the same stage” job.
4. Duplicated build steps between `prepare.sh` and `build-bundle.sh` are intentional until a future shared *compile* driver exists; packaging and tarball assembly stay separate.

## Ubuntu binary packages (Track B)

See `debian/control`. Core session package is `y5-compositor`; the former
monolith bundle is `y5-compositor-full` (Depends on all component packages).
