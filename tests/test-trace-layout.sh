#!/bin/bash
# Check the plugin-to-daemon schema and fallback without root or real configs.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cp "$ROOT/layout-animated.json" "$WORK/layout.json"
printf '%s\n' '-- existing user bindings' >"$WORK/bindings.lua"
# Use fake fixed-path elevation? No: the renderer is the embedded Python block;
# capture its TOML before the script's EXIT trap removes its temporary file.
python3 - "$ROOT" "$WORK" <<'PY'
import json, pathlib, re, subprocess, sys, tomllib
root, work = map(pathlib.Path, sys.argv[1:])
script = (root / 'apply.sh').read_text()
program = script.split("<<'PY'\n", 1)[1].split('\nPY\n', 1)[0]
args = [str(work/'layout.json'), str(work/'bindings.lua'), '-- begin', '-- end',
        'Generated test', str(work/'config.toml'), '65536', '262144']
subprocess.run(['python3', '-', *args], input=program, text=True, check=True)
config = tomllib.loads((work/'config.toml').read_text())
first = config['MediaLayerKeys'][0]
assert first['Icon'] == 'omarchy-green' and first['Action'] == 'Search'
assert len(first['Trace']['Paths']) == 1
assert first['Trace']['Paths'][0][0] == first['Trace']['Paths'][0][-1]
points = first['Trace']['Paths'][0]
# The logo's rails are orthogonal: no diagonal bridges between disconnected paths.
assert all((a[0] == b[0]) != (a[1] == b[1]) for a,b in zip(points, points[1:]))
assert config['AdaptiveBrightness'] is True
assert 'o.rebind("PRINT"' in (work/'bindings.lua').read_text()
assert [b['Action'] for b in config['PrimaryLayerKeys']] == ['F'+str(i) for i in range(1,13)]
# The same generator must continue supporting the static fallback.
(work/'layout.json').write_text((root/'layout.json').read_text())
subprocess.run(['python3', '-', *args], input=program, text=True, check=True)
static = tomllib.loads((work/'config.toml').read_text())
assert 'Trace' not in static['MediaLayerKeys'][0]
# Reject non-finite values rather than injecting malformed TOML.
invalid = json.loads((root/'layout-animated.json').read_text())
invalid['buttons'][0]['trace']['LineWidth'] = float('nan')
(work/'layout.json').write_text(json.dumps(invalid))
assert subprocess.run(['python3', '-', *args], input=program, text=True, capture_output=True).returncode != 0
print('PASS: animated schema, first-position action, static fallback, Fn keys, adaptive brightness, binding replacement, invalid numbers')
PY
