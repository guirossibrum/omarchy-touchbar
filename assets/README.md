`omarchy-green.svg` follows the Omarchy menu's U+E900 glyph from the `omarchy`
font, distributed with [Omarchy](https://github.com/omacom/omarchy). The trace
graph follows the same 19 rails, splitting at all six mapped junctions. The logo remains Omarchy's mark;
these assets do not imply endorsement of this community fork.

`omarchy-trace-preview.gif` is rendered by tiny-dfr's native Rust/Cairo renderer,
using the real ttfx Wipe effect and the settings in `native/preview.toml`.
It is enlarged 4x for review; the actual Touch Bar icon is 48x48 pixels.

`omarchy-topology.json` is the numbered node/rail map. `omarchy-topology.svg`
labels its six junctions. `omarchy-routes.json` enumerates all 495 simple routes
between the 153 unordered node pairs; reverse routes are the same lists reversed.
Regenerate the route export with `python3 tools/map-logo.py`. These files are
review artifacts, not animation-loop inputs.
