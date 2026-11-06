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

The plugin is the entry point for users. `packaging/omarchy-touchbar/PKGBUILD` pins its matching
daemon revision; Cargo.lock pins the ttfx dependency. The `omarchy-touchbar` package provides/conflicts with `tiny-dfr`; rollback
reinstalls the stock package through pacman. No development override is needed.

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

## Timing, alignment and dictation refinements

The green-only hold defaults to one second; gray has no hold. Idle-dim animation
continues, with full-off and hidden-layer sleep retained. Text uses font metrics
for one shared baseline and ink-centered horizontal placement. The plugin
resolves the user's Omarchy monospace family when applying the layout.

Tap/hold is native input handling, not a polling shell timer. The daemon emits
F15 only after the hold threshold; the plugin binds it through Omarchy's existing
backend-neutral dictation commands. Short taps remain Search/menu actions. Tests
cover tap/hold exclusivity, threshold behavior, cancellation and label alignment.

## Dependency proposal

The proposed dependency is **omarchy-touchbar**, not an assumption that upstream
Asahi tiny-dfr will merge these changes. Omarchy can choose to maintain a fork
and publish its package independently. That ownership decision belongs to its
maintainers. This is a community fork and local package until they agree.

The package includes a standard PKGBUILD and .SRCINFO, a pinned Rust source
revision, a compatibility `tiny-dfr` executable and service, and the original
udev rules/assets. It declares `provides=('tiny-dfr=0.3.8')` and
`conflicts=('tiny-dfr')`. The optional plugin remains the user-session integration.

Font following is event-driven: an Omarchy `font-set` hook writes only a bounded
family name to a user-owned file under /run. The daemon watches that directory,
validates the owner/type/length, and reloads only the font after dropping root.
One initial authorized layout apply creates a tmpfiles rule. Future font changes
do not invoke sudo/pkexec, edit /etc, restart the daemon, or spawn idle processes.
