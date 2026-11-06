# Hardware validation — 2026-11-05

Host: M1 13-inch MacBook Pro (`MacBookPro17,1`), aarch64 Omarchy/Hyprland.
Packaged tiny-dfr: 0.3.7-1. Native renderer: pinned by `native/source.env`.

- Native unit tests: eight unique tests pass in the daemon and preview targets.
- Existing plugin bindings/I/O regression suite: pass.
- Trace layout/schema, finite numeric fields, menu action/position, Fn mapping,
  static fallback and binding replacement checks: pass.
- Rust formatting, shell syntax, Git whitespace checks: pass.
- Installer fetches the full pinned commit, tests, builds and validates the real
  installed configuration before activation. This path was exercised end to end.
- Live daemon uses `/usr/local/libexec/tiny-dfr-omarchy`, one thread, and its
  current invocation has no startup panic. Packaged executable is retained.
- The third-to-first menu move keeps `Action = "Search"`; all user laptop
  brightness overrides remain in bindings.lua. Hyprland reports no config errors.
- Final live layout uses an explicit graph with 18 nodes, 19 rails and six
  degree-3 junctions. Tests verify splitting into two/three outgoing branches,
  merging around loops, complete rail coverage, linear timing and sources clear
  of nodes. All 495 simple routes are exported and checked against the graph.
  The preview GIF is regenerated from these exact settings.

## Short resource samples

Process CPU ticks from `/proc/PID/stat`, divided by elapsed monotonic time and
`SC_CLK_TCK`. Percentages refer to **one CPU core**, not the whole machine.
These are short spot checks, not battery or sustained performance benchmarks.

| Mode | Sample | CPU, one core | RSS |
| --- | ---: | ---: | ---: |
| Packaged static daemon | 5.0 s | 0.2% | 23552 KiB |
| Previous continuous-walk implementation | 8.0 s | 0.625% | 29408 KiB |
| Native function-key layer | 5.0 s | 0.0% | not sampled |

The function-key layer was selected by temporarily setting `MediaLayerDefault`
false, then restoring the exact original configuration in a `finally` block.
No CPU ticks were observed in that five-second sample. This tests scheduling
with the static layer selected; it is not a physical Fn-key press test.

## Adaptive brightness

The panel's original raw brightness was 509. At 50%,
it was 255 and the Touch Bar followed from
129 to 91. Restoring the
exact original panel level restored the Touch Bar to 129.

## Startup compatibility issue found and fixed

The first live attempt used the new upstream code with the older packaged
configuration and panicked on a missing `DoublePressSwitchLayers` field. The
packaged daemon was restored while fixing it. The field now defaults to zero,
and `--check-config` validates config/fonts/icons without opening DRM. The
installer also checks the new invocation for a caught panic and restores the
packaged service if startup fails. Subsequent validation and live startup pass.

The machine has a pre-existing logind lid guard for a spurious libinput lid event.
This animation change does not install or replace that workaround. Physical
lid-close/open behavior was not re-tested during these animation measurements.

## Constant-speed branching update

The renderer now uses the real ttfx Wipe with Linear easing. Weighted arrival
distances for 64 interior sources are computed when loading the icon. Sources
are at least one line-width from both nodes. Fronts launch both ways, split
at every reached junction, and merge on rails; the last-arrival calculation
includes rail interiors so no gaps are left at phase completion.

The current live invocation started without a panic, with all 19 configured
rails. A 8.0-second sample measured 1.375% of one CPU
core and one thread. This remains a short spot check, not a battery benchmark.
