#!/bin/bash
# Build the matching native renderer as the user; install only finished artifacts.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$ROOT/native/source.env"

run_as_root() {
  if (( EUID == 0 )); then "$@"
  elif [[ -t 0 && -t 1 ]]; then /usr/bin/sudo "$@"
  else /usr/bin/pkexec "$@"
  fi
}

if [[ ${1:-} == --uninstall ]]; then
  run_as_root /usr/bin/bash -c '
    rm -f /etc/systemd/system/tiny-dfr.service.d/90-omarchy-animation.conf
    systemctl daemon-reload
    systemctl restart tiny-dfr.service
    rm -f /usr/local/libexec/tiny-dfr-omarchy
  '
  echo 'Restored the packaged tiny-dfr daemon. Trace buttons use their static icons.'
  exit 0
fi
[[ $# == 0 ]] || { echo 'Usage: install-native.sh [--uninstall]' >&2; exit 1; }
(( EUID != 0 )) || { echo 'Build as your normal user; the installer elevates only to copy finished files.' >&2; exit 1; }
for tool in cargo git pkg-config; do
  command -v "$tool" >/dev/null || {
    echo 'Missing build tools. On Omarchy: omarchy pkg add rust gcc pkgconf cairo pango librsvg libinput systemd-libs' >&2
    exit 1
  }
done

BUILD="${XDG_CACHE_HOME:-$HOME/.cache}/omarchy-touchbar/native"
mkdir -p "$BUILD"
if [[ ! -d $BUILD/.git ]]; then /usr/bin/git -C "$BUILD" init -q; fi
/usr/bin/git -C "$BUILD" fetch --depth 1 "$NATIVE_REPOSITORY" "$NATIVE_REVISION"
/usr/bin/git -C "$BUILD" checkout --detach --force FETCH_HEAD
[[ $(/usr/bin/git -C "$BUILD" rev-parse HEAD) == "$NATIVE_REVISION" ]] || exit 1
/usr/bin/cargo test --locked --manifest-path "$BUILD/Cargo.toml"
/usr/bin/cargo build --locked --release -j 2 --manifest-path "$BUILD/Cargo.toml" --bin tiny-dfr
binary="$BUILD/target/release/tiny-dfr"
[[ $("$binary" --capabilities) == 'trace-animation ttfx-wipe' ]] || exit 1
"$binary" --check-config

run_as_root /usr/bin/bash -c '
  set -eu
  install -D -m 755 "$1" /usr/local/libexec/tiny-dfr-omarchy
  install -D -m 644 "$2" /etc/systemd/system/tiny-dfr.service.d/90-omarchy-animation.conf
  systemctl daemon-reload
  systemctl restart tiny-dfr.service
  sleep 1
  invocation=$(systemctl show tiny-dfr.service -p InvocationID --value)
  if ! systemctl is-active --quiet tiny-dfr.service ||
     journalctl --no-pager "_SYSTEMD_INVOCATION_ID=$invocation" | grep -q "panicked at"; then
    echo "Native renderer failed startup; restoring packaged tiny-dfr" >&2
    rm -f /etc/systemd/system/tiny-dfr.service.d/90-omarchy-animation.conf
    systemctl daemon-reload
    systemctl restart tiny-dfr.service
    exit 1
  fi
  rm -f /etc/systemd/system/tiny-dfr.service.d/90-omarchy-animation.conf.disabled
' bash "$binary" "$ROOT/native/90-omarchy-animation.conf"
echo 'Native renderer installed. Apply layout-animated.json to enable tracing.'
