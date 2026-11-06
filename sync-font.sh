#!/bin/bash
# Runs unprivileged on font-set and post-boot. Never edits /etc or restarts a daemon.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec /usr/bin/python3 "$ROOT/sync-font.py" "$@"
