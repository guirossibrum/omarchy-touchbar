#!/bin/bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
OMARCHY_TOUCHBAR_FONT_DIR="$WORK" bash "$ROOT/sync-font.sh" 'JetBrainsMono Nerd Font'
[[ $(cat "$WORK/current-font") == 'JetBrainsMono Nerd Font' ]]
[[ $(stat -c %a "$WORK/current-font") == 644 ]]
# Atomic replacement must not follow a stale symlink or block on a FIFO.
printf victim >"$WORK/victim"
rm "$WORK/current-font"
ln -s "$WORK/victim" "$WORK/current-font"
OMARCHY_TOUCHBAR_FONT_DIR="$WORK" bash "$ROOT/sync-font.sh" 'CaskaydiaMono Nerd Font'
[[ $(cat "$WORK/victim") == victim && ! -L $WORK/current-font ]]
rm "$WORK/current-font"
mkfifo "$WORK/current-font"
OMARCHY_TOUCHBAR_FONT_DIR="$WORK" timeout 3 bash "$ROOT/sync-font.sh" 'JetBrainsMono Nerd Font'
[[ -f $WORK/current-font ]]
if OMARCHY_TOUCHBAR_FONT_DIR="$WORK" bash "$ROOT/sync-font.sh" 'monospace:file=/etc/passwd'; then
  echo 'FAIL: accepted a fontconfig file pattern' >&2
  exit 1
fi
echo 'PASS: unprivileged atomic font updates, readable state, symlink/FIFO handling, bounded family validation'
