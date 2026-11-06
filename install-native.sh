#!/bin/bash
# Compatibility entry point for prebuilt package installation; never builds.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ ${1:-} != "--uninstall" ]]; then
  /usr/bin/python3 "$ROOT/hardware.py" || exit 0
fi
if ! command -v omarchy-install-touchbar >/dev/null; then
  echo 'This installer requires Omarchy with the prebuilt Touch Bar integration. Install that update and use: omarchy install touchbar' >&2
  echo 'No source-build fallback is provided. The signed combined package must be published before installation.' >&2
  exit 1
fi
exec omarchy-install-touchbar "$@"
