# Proposed dependency: omarchy-touchbar

> Historical native-only packaging notes. The [main integration PR](https://github.com/omacom/omarchy/pull/17826) supersedes the source-build setup below with one prebuilt daemon/plugin package. Installation and updates never compile; recipes are for release builders only. See the [current README](https://github.com/guirossibrum/omarchy-touchbar#readme).

Apple Silicon Touch Bars need a native renderer as well as desktop integration. This proposal packages the community tiny-dfr fork as `omarchy-touchbar`, providing the existing `tiny-dfr` executable/service interface while adding generic vector animation, cancellable tap/hold actions, text alignment and event-driven desktop-font reloads.

The Arch package declares `provides=('tiny-dfr=0.3.8')` and `conflicts=('tiny-dfr')`. Pacman installs one daemon provider at a time. The package owns its executable, original udev rules/assets, compatibility symlink and service; user layout stays under `/etc/tiny-dfr/config.toml`. The Omarchy plugin owns logo geometry, menu and dictation bindings, and font-change hooks.

The proposed Omarchy integration is a package dependency and optional plugin setup. It does not require upstream tiny-dfr acceptance or vendoring its Rust source into Omarchy core. It does require Omarchy maintainers to agree to own/support the fork and publish builds. The current package is a community build, not an official Omarchy dependency.

Source and Rust dependencies are pinned. The native test suite, plugin regression tests, package build/check phase, live startup and font-hook integration are the relevant validation. aarch64 is tested locally on an M1 MacBook Pro; x86_64 needs build/hardware validation before that architecture is published.

For review, font reload is an isolated native commit; packaging and user-session hooks are separate from the previously developed animation and tap/hold commits. Maintainers can review those boundaries individually rather than adopting an undifferentiated change.
