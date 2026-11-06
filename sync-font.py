#!/usr/bin/python3
"""Publish a bounded family name to the user's runtime font channel."""
import os
import pathlib
import subprocess
import sys
import tempfile

uid = os.getuid()
directory = pathlib.Path(os.environ.get('OMARCHY_TOUCHBAR_FONT_DIR', f'/run/omarchy-touchbar-font-{uid}'))
if not directory.exists():
    # Packaged tiny-dfr without the optional native installer has no channel.
    sys.exit(0)
if directory.is_symlink() or not directory.is_dir() or directory.stat().st_uid != uid:
    sys.exit('Refusing an unsafe Touch Bar font directory')
if len(sys.argv) > 2:
    sys.exit('Usage: sync-font.sh [family]')
family = sys.argv[1] if len(sys.argv) == 2 else subprocess.check_output(
    ['/usr/bin/fc-match', 'monospace', '-f', '%{family}\n'], text=True, timeout=2
).splitlines()[0].split(',')[0].strip()
if (not family or len(family.encode()) > 256 or
        any(ord(c) < 32 or ord(c) == 127 or c in ':=/\\' for c in family)):
    sys.exit('Invalid font family')
temporary = None
try:
    with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=directory, delete=False) as output:
        temporary = pathlib.Path(output.name)
        os.fchmod(output.fileno(), 0o644)
        output.write(family)
        output.flush()
        os.fsync(output.fileno())
    os.replace(temporary, directory / 'current-font')
finally:
    if temporary is not None:
        temporary.unlink(missing_ok=True)
