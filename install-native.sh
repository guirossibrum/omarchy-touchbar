#!/bin/bash
# Compatibility entry point: build/install the managed omarchy-touchbar package.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

run_as_root() {
  if (( EUID == 0 )); then
    "$@"
  elif [[ -t 0 && -t 1 ]]; then
    /usr/bin/sudo "$@"
  else
    /usr/bin/pkexec "$@"
  fi
}

if [[ ${1:-} == --uninstall ]]; then
  /usr/bin/pacman -Si tiny-dfr >/dev/null
  run_as_root /usr/bin/pacman -S --noconfirm --ask 4 tiny-dfr
  rm -f "$HOME/.config/omarchy/hooks/font-set.d/90-touchbar-font" "$HOME/.config/omarchy/hooks/post-boot.d/90-touchbar-font"
  echo 'Restored stock tiny-dfr. The plugin uses its static icon fallback.'
  exit 0
fi
/usr/bin/python3 "$ROOT/hardware.py" || exit 0
if (( $# != 0 || EUID == 0 )); then
  echo 'Usage as your normal user: install-native.sh [--uninstall]' >&2
  exit 1
fi

# Keep makepkg clones/symlinks/artifacts outside the user plugin directory.
BUILD_WORK="${XDG_CACHE_HOME:-$HOME/.cache}/omarchy-touchbar/package-build"
mkdir -p "$BUILD_WORK"
cp "$ROOT/packaging/omarchy-touchbar/PKGBUILD" "$ROOT/packaging/omarchy-touchbar/setup-font-channel" "$ROOT/packaging/omarchy-touchbar/omarchy-touchbar.install" "$BUILD_WORK/"
cd "$BUILD_WORK"
/usr/bin/makepkg --force --log
mapfile -t artifacts < <(/usr/bin/makepkg --packagelist)
package=""
for artifact in "${artifacts[@]}"; do
  if [[ ${artifact##*/} == omarchy-touchbar-[0-9]*.pkg.tar.* ]]; then
    package=$artifact
  fi
done
if [[ ! -f $package ]]; then
  echo 'Built package not found' >&2
  exit 1
fi
run_as_root /usr/bin/bash "$ROOT/native/install-package.sh" "$package"
omarchy hook install font-set "$ROOT/hooks/90-touchbar-font"
omarchy hook install post-boot "$ROOT/hooks/90-touchbar-font"
bash "$ROOT/sync-font.sh"
echo 'omarchy-touchbar package installed. Run enable-animation.sh to apply the layout.'
