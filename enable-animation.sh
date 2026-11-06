#!/bin/bash
# Preserve the user's layout; customize only the Omarchy menu button.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
python3 - "$ROOT" <<'PY'
import datetime, json, pathlib, shutil, sys
root = pathlib.Path(sys.argv[1])
layout = pathlib.Path.home() / '.config/omarchy/touchbar.json'
if layout.exists():
    if layout.is_symlink() or not layout.is_file() or layout.stat().st_size > 65536:
        sys.exit('Refusing a non-regular or oversized layout')
    data = json.loads(layout.read_text())
    suffix = datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    shutil.copy2(layout, str(layout) + '.bak-' + suffix)
else:
    data = json.loads((root/'layout.json').read_text())
data.setdefault('fontTemplate', 'system')
buttons = data.get('buttons', [])
index = next((i for i, b in enumerate(buttons) if b.get('key') == 'Search'), None)
if index is None:
    sys.exit('No Search/menu button in your layout; add one before enabling animation')
menu = buttons.pop(index)
menu.pop('text', None)
menu['icon'] = 'omarchy-green'
menu.setdefault('holdKey','F15')
menu.setdefault('holdMilliseconds',600)
menu.setdefault('holdHyprKey','code:193')
menu.setdefault('holdStartCommand','omarchy dictation start')
menu.setdefault('holdStopCommand','omarchy dictation stop')
menu['trace'] = json.loads((root/'assets/omarchy-trace.json').read_text())
buttons.insert(0, menu)
layout.parent.mkdir(parents=True, exist_ok=True)
# apply.sh separately validates the resulting layout before installing it.
temp = layout.with_name('.touchbar-animation-' + str(__import__('os').getpid()) + '.json')
with temp.open('x') as output:
    json.dump(data, output, indent=2)
    output.write('\n')
temp.replace(layout)
PY
exec bash "$ROOT/apply.sh"
