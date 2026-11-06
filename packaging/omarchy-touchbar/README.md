# omarchy-touchbar package

An Arch package for the community tiny-dfr fork, built at a full pinned revision.
It uses Omarchy's naming prefix and declares `provides=('tiny-dfr=0.3.8')` and
`conflicts=('tiny-dfr')`: pacman replaces the stock daemon in one transaction.

`/usr/bin/omarchy-touchbar` is the native daemon. `/usr/bin/tiny-dfr` is a
compatibility symlink. The existing `tiny-dfr.service`, udev seat/device rules,
icons and `/usr/share/tiny-dfr/config.toml` interface are retained, so existing
plugins and lid policy continue to work. `/etc/tiny-dfr/config.toml` is user
configuration and is not overwritten or owned by this package.

```bash
makepkg -si
```

Build and tests run as the desktop user; only pacman installation is elevated.
The plugin's `install-native.sh` wraps these steps and migrates its earlier
development service override. It does not install an untracked daemon in
`/usr/local` anymore. The plugin remains separately configured in the user's
Omarchy plugin directory.

For an Omarchy repository proposal, the maintainers would need to agree to own
this fork/package and publish builds for supported architectures. This package
has been built/tested locally on aarch64; x86_64 is declared but must be tested
on x86_64 hardware/build infrastructure before publishing that build.

The source lock and checksum cover the daemon and local setup helper. Cargo's
lockfile pins ttfx and all Rust dependencies. Runtime fonts use a bounded,
user-owned state file under `/run`; one authorized layout apply creates its
tmpfiles rule. Font changes then require no root operation or daemon restart.
