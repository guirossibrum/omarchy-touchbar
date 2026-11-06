# Review scope

## Problem and behavior

The plugin configures a static Touch Bar and does not implement a renderer.
The first button can now show a green Omarchy glyph, tracing gray to green and
back with a randomized starting point per pass. Pressing it retains the menu
action; Fn, other keys, and adaptive brightness retain their existing behavior.

## Reuse existing Omarchy code

Omarchy's screensaver launches `ttfx`, maintained at `omacom/ttfx`. The companion
tiny-dfr build links that project's public Rust library at revision
`14ed2742596f0056b13e25d14a83ea851adc2294`. It uses `fx::effects::wipe::Wipe` with
`Linear` easing on a one-row virtual canvas, and its RNG for starting points.
The adapter maps the resulting linear coverage to weighted distances on a rail
graph. Junctions split the wavefront; loops merge it. All routing is precomputed
when the icon loads, and sources are strictly inside rails, clear of nodes. No separate
effect algorithm or terminal rendering stack is maintained in this plugin.

The engine creates the masks only when loading the icon; playback retains those
small masks, not the full engine. It caps animation to roughly 15 fps and pauses
animation wakeups on hidden layers and dim/off backlights. Idle/lid behavior is
still owned by tiny-dfr/system policy, not an animation process.

## Two small integration boundaries

1. **tiny-dfr fork:** generic optional `Trace` configuration and dirty-button
   scheduling; no hard-coded Omarchy logo. It also provides a hardware-free
   preview and tests for phase continuity and bounded geometry.
2. **This plugin:** SVG/logo paths, static and animated layouts, JSON-to-TOML
   serialization, an opt-in pinned native build/install helper, and rollback.

The plugin is the entry point for users. `native/source.env` pins its matching
daemon revision; Cargo.lock pins the ttfx dependency. Packaged tiny-dfr is kept
and can be restored by removing one systemd override.

## Proposed upstream sequence

Review native `Trace` support independently, then review the plugin assets,
layout, tests and optional installer. An Omarchy/macOS-hardware packaging PR can
depend on an accepted native version rather than making the main desktop repo
track a floating community fork. Nothing here guarantees upstream acceptance.
The main Omarchy repo should not gain a copy of either rendering engine.

## Hardware validation

Validation for this branch is on an M1 13-inch MacBook Pro (`MacBookPro17,1`),
using Hyprland and tiny-dfr's normal DRM/input devices. The local machine also
has a separate logind-based lid guard for a spurious libinput lid event; that
workaround is independent of this animation patch and is not installed by this
plugin. CPU, lid and layer checks are recorded in VALIDATION.md once measured.
