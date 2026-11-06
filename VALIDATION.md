# Hardware validation — 2026-11-05

Host: M1 13-inch MacBook Pro (`MacBookPro17,1`), aarch64 Omarchy/Hyprland.
Packaged tiny-dfr: 0.3.7-1. Native renderer: pinned by `packaging/omarchy-touchbar/PKGBUILD`.

- Native tests: 14 tests pass in the daemon target and 9 in the preview target.
- Existing plugin bindings/I/O regression suite: pass.
- Trace layout/schema, finite numeric fields, menu action/position, Fn mapping,
  static fallback and binding replacement checks: pass.
- Rust formatting, shell syntax, Git whitespace checks: pass.
- The package build fetches the full pinned commit and runs its tests. The
  package installer verifies the new invocation and can restore stock tiny-dfr
  if startup reports a caught panic. The local package transaction passed.
- Live daemon uses package-owned `/usr/bin/tiny-dfr` (a compatibility symlink to
  `/usr/bin/omarchy-touchbar`), one thread, with no startup panic. Stock tiny-dfr
  can be restored through pacman.
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

## Green hold, idle dim, labels and dictation

- Timing tests verify a one-second hold only while fully green and immediate
  recoloring after reaching gray, across all 64 source phases.
- Animation scheduling now permits idle-dim brightness 1 and sleeps only for
  full-off brightness 0 or a static layer. A 42-second live probe did not observe
  an idle-dim state, so this probe does not establish live dim behavior. The
  implementation's gate and timing regression tests were checked.
- Text layout tests verify `term`, `lock`, and `snip` share a baseline and are
  horizontally centered using glyph bearings. The generated live FontTemplate
  is `JetBrainsMono Nerd Font`, matching the user's current Omarchy monospace.
- Plugin schema tests verify font resolution, a 600 ms F15 HoldAction, and
  backend-neutral `omarchy dictation start` / `omarchy dictation stop` bindings.
  The live backend selector returns `superwhisper`; both generated press/release
  shortcuts are present. No microphone recording was started during validation.
- Native gesture tests verify short taps never start holds, holds start only
  once and release without tapping, and sliding off cancels/releases correctly.
  Cancellation also releases the gesture on input cancel, device removal, layer
  changes, config reload and a fully off backlight.
- After applying the combined update, the daemon invocation has no startup panic,
  Hyprland has no configuration errors, and user laptop-brightness bindings remain.

## Managed package and automatic-font integration

The daemon now builds as `omarchy-touchbar 0.3.8.omarchy1-1` from the pinned
native commit in PKGBUILD. The makepkg build and check phase passed on aarch64:
14 native tests and 9 preview tests. Package metadata declares a versioned
`tiny-dfr` provider and a conflict with stock tiny-dfr. The local installation
replaced stock tiny-dfr in one transaction; pacman owns both executable names.
The service now uses `/usr/bin/tiny-dfr`, with no development ExecStart override.

The font-set/post-boot hooks write only a bounded family string in a user-owned
runtime directory. The daemon validates and watches it after dropping root.
The initial live state update loaded JetBrainsMono Nerd Font without a panic.
Unit/plugin checks cover bounded family input, atomic writer behavior with
symlink/FIFO leftovers, system-font selection and explicit font opt-out.
The x86_64 architecture is declared but has not been built/tested in this session.

The actual installed font-set hook was exercised with Adwaita Mono, then the
current system font (JetBrainsMono Nerd Font) was restored. The daemon logged both
updates and retained PID 355801 throughout. Font changes used no pkexec/sudo,
service restart, or system-font setting mutation. The system font itself was
left unchanged; the test invoked only this plugin's hook, not other user hooks.
`pacman -Qkk omarchy-touchbar` reports 50 files and zero altered files. The
existing lid guard and daemon are active, and Hyprland reports no config errors.
