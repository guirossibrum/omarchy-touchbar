#!/usr/bin/python3
"""Fail-closed Touch Bar hardware predicate; no fixture overrides in this CLI."""
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys

SUPPORTED = frozenset((b'apple,j293', b'apple,j493'))
COMPATIBLE = Path('/proc/device-tree/compatible')
MAX_BYTES = 4096


def compatible_supported(path):
    """Parse the kernel's NUL-terminated compatible list (also used by tests)."""
    try:
        descriptor = os.open(path, os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW)
        with os.fdopen(descriptor, 'rb') as source:
            if not stat.S_ISREG(os.fstat(source.fileno()).st_mode):
                return False
            data = source.read(MAX_BYTES + 1)
    except OSError:
        return False
    if not data or len(data) > MAX_BYTES or not data.endswith(b'\0'):
        return False
    entries = data[:-1].split(b'\0')
    if any(not entry or any(c < 33 or c > 126 for c in entry) for entry in entries):
        return False
    return bool(SUPPORTED.intersection(entries))


def supported():
    if os.uname().machine != 'aarch64':
        return False
    # Omarchy's helpers are authoritative when installed. Never feed their
    # development/test fixture overrides into a real installation decision.
    environment = os.environ.copy()
    for name in ('OMARCHY_PROC_ROOT', 'OMARCHY_SYS_ROOT', 'OMARCHY_IMAGE_ROOT',
                 'BASH_ENV', 'ENV'):
        environment.pop(name, None)
    for name, arguments in (
        ('omarchy-hw-touchbar', []),
        ('omarchy-hw-match-device-tree', ['apple,j293', 'apple,j493']),
    ):
        helper = shutil.which(name, path='/usr/bin:/bin' if os.geteuid() == 0 else None)
        if helper:
            try:
                # Both Omarchy predicates are Bash scripts. Protected mode also
                # ignores inherited exported functions, including at root.
                return subprocess.run(['/usr/bin/bash', '-p', '--', helper, *arguments], env=environment,
                                      stdin=subprocess.DEVNULL,
                                      stdout=subprocess.DEVNULL,
                                      stderr=subprocess.DEVNULL, timeout=3).returncode == 0
            except (OSError, subprocess.SubprocessError):
                return False
    return compatible_supported(COMPATIBLE)


if __name__ == '__main__':
    # No --force, environment fixture path, or command-line model override.
    if len(sys.argv) != 1:
        sys.exit(2)
    sys.exit(0 if supported() else 1)
