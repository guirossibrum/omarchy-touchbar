#!/usr/bin/python3
"""Test-only adapter: copy entrypoints, inject explicit DT fixture, never live HW.

The installed detector has no fixture switch. The copied detector below imports
its real bounded parser by absolute path. No PATH helper or host model is used.
"""
from pathlib import Path
import shutil
import sys


def prepare(source, destination, compatible):
    source, destination = Path(source).resolve(), Path(destination).resolve()
    destination.mkdir(parents=True)
    for name in ('apply.sh', 'enable-animation.sh', 'install-native.sh',
                 'sync-font.sh', 'sync-font.py', 'layout.json'):
        shutil.copy2(source / name, destination / name)
    shutil.copytree(source / 'assets', destination / 'assets')
    shutil.copytree(source / 'native', destination / 'native')
    shutil.copytree(source / 'hooks', destination / 'hooks')
    fixture = destination / 'compatible'
    fixture.write_bytes(compatible)
    (destination / 'hardware.py').write_text(
        'import sys\nsys.dont_write_bytecode = True\n'
        'import importlib.util\n'
        f'spec = importlib.util.spec_from_file_location("real_hardware", {str(source / "hardware.py")!r})\n'
        'module = importlib.util.module_from_spec(spec)\n'
        'spec.loader.exec_module(module)\n'
        f'def supported(): return module.compatible_supported({str(fixture)!r})\n'
        'if __name__ == "__main__": raise SystemExit(0 if supported() else 1)\n'
    )


if __name__ == '__main__':
    prepare(sys.argv[1], sys.argv[2], b'apple,j293\0apple,t8103\0apple,arm-platform\0')
