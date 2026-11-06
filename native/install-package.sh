#!/bin/bash
# One authorized package installation; no passwordless policy is installed.
set -euo pipefail
if (( EUID != 0 || $# != 1 )) || [[ ! -f $1 ]]; then
  echo 'Usage (root): install-package.sh /absolute/package.pkg.tar.zst' >&2
  exit 1
fi
# ALPM question bit 4 permits replacing the explicitly conflicting stock package.
/usr/bin/pacman -U --noconfirm --ask 4 -- "$1"

# Migrate only the exact override created by this project's earlier installer.
legacy=/etc/systemd/system/tiny-dfr.service.d/90-omarchy-animation.conf
expected=$'[Service]\nExecStart=\nExecStart=/usr/local/libexec/tiny-dfr-omarchy'
migrated=0
if [[ -f $legacy && $(<"$legacy") == "$expected" ]]; then
  /usr/bin/rm -- "$legacy"
  migrated=1
fi
/usr/bin/systemctl daemon-reload
/usr/bin/systemctl restart tiny-dfr.service
/usr/bin/sleep 1
invocation=$(/usr/bin/systemctl show tiny-dfr.service -p InvocationID --value)
startup_log=$(/usr/bin/journalctl --no-pager "_SYSTEMD_INVOCATION_ID=$invocation")
if ! /usr/bin/systemctl is-active --quiet tiny-dfr.service || [[ $startup_log == *"panicked at"* ]]; then
  echo 'New daemon failed startup; restoring stock tiny-dfr' >&2
  /usr/bin/pacman -S --noconfirm --ask 4 tiny-dfr
  /usr/bin/systemctl restart tiny-dfr.service
  exit 1
fi
if (( migrated )); then
  /usr/bin/rm -f /usr/local/libexec/tiny-dfr-omarchy
fi
