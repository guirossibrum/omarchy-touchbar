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
assert first['HoldAction'] == 'F15' and first['HoldMilliseconds'] == 600
assert 'o.bind_hold("code:193"' in (work/'bindings.lua').read_text()
assert '"omarchy dictation start"' in (work/'bindings.lua').read_text()
assert '"omarchy dictation stop"' in (work/'bindings.lua').read_text()
try:
    expected_font = subprocess.check_output(['/usr/bin/fc-match','monospace','-f','%{family}\n'],text=True,timeout=2).splitlines()[0].split(',')[0].strip()
except (OSError,subprocess.SubprocessError,IndexError):
    expected_font = 'monospace'
assert config['FontTemplate'] == expected_font
topology = json.loads((root/'assets/omarchy-topology.json').read_text())
assert len(first['Trace']['Paths']) == len(topology['edges']) == 19
assert len(topology['nodes']) == 18
assert sum(node['degree'] == 3 for node in topology['nodes']) == 6
positions = {node['id']:node['position'] for node in topology['nodes']}
rails = {tuple(sorted((tuple(positions[e['from']]), tuple(positions[e['to']])))) for e in topology['edges']}
assert rails == {tuple(sorted(map(tuple,path))) for path in first['Trace']['Paths']}
assert all((a[0] == b[0]) != (a[1] == b[1]) for a,b in rails)
routes = json.loads((root/'assets/omarchy-routes.json').read_text())
assert len(routes) == 153
assert sum(len(entry['routes']) for entry in routes) == 495
for entry in routes:
    for route in entry['routes']:
        nodes = route['nodes']
        assert len(nodes) == len(set(nodes))
        assert nodes[0] == entry['from'] and nodes[-1] == entry['to']
        assert all(tuple(sorted((tuple(positions[a]),tuple(positions[b])))) in rails for a,b in zip(nodes,nodes[1:]))
assert first['Trace']['PauseSeconds'] == 1.0
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
print('PASS: trace schema, tap/hold dictation routing, system font, static fallback, Fn keys, adaptive brightness, invalid numbers')
PY
