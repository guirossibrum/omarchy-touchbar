#!/usr/bin/python3
"""Deterministic model parsing, helper selection, and unsupported no-effects."""
import importlib.util
import os
import py_compile
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import hardware
spec = importlib.util.spec_from_file_location('fixture', ROOT / 'tests/hardware-fixture.py')
fixture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixture)


class HardwareTest(unittest.TestCase):
    def setUp(self):
        # Helper-selection tests are independent of the developer/CI host CPU.
        architecture = patch.object(hardware.os, 'uname')
        architecture.start().return_value.machine = 'aarch64'
        self.addCleanup(architecture.stop)

    def test_model_fixtures(self):
        cases = {
            'M1 Touch Bar': (b'apple,j293\0apple,t8103\0apple,arm-platform\0', True),
            'M2 Touch Bar': (b'apple,j493\0apple,t8112\0apple,arm-platform\0', True),
            'M1 Air': (b'apple,j313\0apple,t8103\0', False),
            'prefix': (b'apple,j293evil\0', False),
            'empty': (b'', False),
            'not NUL terminated': (b'apple,j293', False),
            'empty entry': (b'apple,j293\0\0', False),
            'newline': (b'apple,j293\n\0', False),
            'non ASCII': (b'apple,j293\0\xff\0', False),
            'oversized': (b'apple,j293\0' + b'x' * 4096 + b'\0', False),
        }
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'compatible'
            for name, (data, expected) in cases.items():
                with self.subTest(name=name):
                    path.write_bytes(data)
                    self.assertEqual(hardware.compatible_supported(path), expected)
            path.unlink()
            self.assertFalse(hardware.compatible_supported(path), 'x86/missing DT')
            os.mkfifo(path)
            self.assertFalse(hardware.compatible_supported(path), 'FIFO must not block')

    def test_helper_precedence_and_failure(self):
        with patch.object(hardware.shutil, 'which', side_effect=lambda name, **kwargs: '/helpers/' + name), \
             patch.object(hardware.subprocess, 'run') as run:
            run.return_value.returncode = 1
            with patch.dict(os.environ, {'OMARCHY_PROC_ROOT': '/fake', 'BASH_ENV': '/fake'}):
                self.assertFalse(hardware.supported())
            self.assertEqual(run.call_count, 1)
            self.assertEqual(run.call_args.args[0], ['/usr/bin/bash', '-p', '--', '/helpers/omarchy-hw-touchbar'])
            self.assertNotIn('OMARCHY_PROC_ROOT', run.call_args.kwargs['env'])
            self.assertNotIn('BASH_ENV', run.call_args.kwargs['env'])
            run.return_value.returncode = 0
            self.assertTrue(hardware.supported())
        with patch.object(hardware.shutil, 'which', side_effect=[None, '/helpers/matcher']), \
             patch.object(hardware.subprocess, 'run') as run:
            run.return_value.returncode = 0
            self.assertTrue(hardware.supported())
            self.assertEqual(run.call_args.args[0], ['/usr/bin/bash', '-p', '--', '/helpers/matcher', 'apple,j293', 'apple,j493'])
        with patch.object(hardware.shutil, 'which', return_value=None), \
             patch.object(hardware, 'compatible_supported', return_value=False) as parse:
            self.assertFalse(hardware.supported())
            parse.assert_called_once_with(hardware.COMPATIBLE)

    def test_root_resolution_and_architecture(self):
        with patch.object(hardware.os, 'geteuid', return_value=0), \
             patch.object(hardware.shutil, 'which', return_value='/usr/bin/omarchy-hw-touchbar') as which, \
             patch.object(hardware.subprocess, 'run') as run:
            run.return_value.returncode = 0
            self.assertTrue(hardware.supported())
            which.assert_called_once_with('omarchy-hw-touchbar', path='/usr/bin:/bin')
            self.assertEqual(run.call_args.args[0][:3], ['/usr/bin/bash', '-p', '--'])
        with patch.object(hardware.os, 'uname') as uname, \
             patch.object(hardware.shutil, 'which') as which:
            uname.return_value.machine = 'x86_64'
            self.assertFalse(hardware.supported())
            which.assert_not_called()

    def test_unsupported_entrypoints_do_nothing(self):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            plugin = work / 'home/.config/omarchy/plugins/io.github.austindixson.touchbar'
            fixture.prepare(ROOT, plugin, b'apple,j313\0apple,t8103\0')
            # Sitecustomize audits child execution, including fixed /usr/bin paths.
            # Unlike a PATH stub this catches sudo, pkexec, pacman and shell tools.
            audit = work / 'audit'
            audit.mkdir()
            log = work / 'spawned'
            (audit / 'sitecustomize.py').write_text(
                'import os,sys\n'
                'def audit(event,args):\n'
                ' if event in ("subprocess.Popen","os.exec","os.posix_spawn"):\n'
                '  with open(os.environ["SPAWN_LOG"],"a") as f: f.write(str(args)+"\\n")\n'
                'sys.addaudithook(audit)\n')
            # Prepare the test instrumentation cache before the snapshot. Do
            # not disable bytecode in child processes: catch production caches.
            py_compile.compile(str(audit / 'sitecustomize.py'), doraise=True)
            env = dict(os.environ, HOME=str(work / 'home'), XDG_CACHE_HOME=str(work / 'cache'),
                       OMARCHY_TOUCHBAR_FONT_DIR=str(work / 'font'),
                       OMARCHY_TOUCHBAR_BINDINGS=str(work / 'bindings.lua'),
                       PYTHONPATH=str(audit), SPAWN_LOG=str(log))
            (work / 'font').mkdir()
            (work / 'bindings.lua').write_text('-- keep bindings\n')
            # Exact complete tree snapshot also detects temporary/backup/cache files.
            def snapshot():
                return {str(p.relative_to(work)): p.read_bytes() for p in work.rglob('*') if p.is_file()}
            before = snapshot()
            for relative in ('apply.sh', 'enable-animation.sh', 'install-native.sh',
                             'native/install-package.sh', 'sync-font.sh', 'sync-font.py',
                             'hooks/90-touchbar-font'):
                with self.subTest(entrypoint=relative):
                    interpreter = '/usr/bin/python3' if relative.endswith('.py') else '/usr/bin/bash'
                    result = subprocess.run([interpreter, str(plugin / relative)], env=env,
                                            capture_output=True, text=True, timeout=5)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(snapshot(), before)
            self.assertFalse(log.exists(), 'unsupported path spawned a command from Python')
            # Guard placement protects fixed-path Bash elevation too: xtrace must
            # end at predicate, never reach makepkg/pacman/sudo/pkexec/systemctl.
            for relative in ('apply.sh', 'enable-animation.sh', 'install-native.sh', 'native/install-package.sh'):
                trace = subprocess.run(['/usr/bin/bash', '-x', str(plugin / relative)], env=env,
                                       capture_output=True, text=True, timeout=5)
                self.assertEqual(trace.returncode, 0)
                for forbidden in ('/usr/bin/pacman ', '/usr/bin/sudo ', '/usr/bin/pkexec ',
                                  '/usr/bin/makepkg ', '/usr/bin/systemctl ', 'mktemp', 'mkdir -p'):
                    self.assertNotIn(forbidden, trace.stderr)


if __name__ == '__main__':
    unittest.main(verbosity=2)
