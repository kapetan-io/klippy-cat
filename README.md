# Klippy-Cat

A small pixel-art cat that lives on your desktop — a transparent, always-on-top companion that
sleeps where it lies, wakes to watch a passing cursor, and lets you pick it up and drop it. Let
go near a window and (where the OS allows) it lands on the window's top edge.

<p align="center">
  <img src="klippy-cat-sprite-256.png" width="200" alt="Klippy the caped pixel cat">
</p>

The design goal is an **ambient, lifelike, low-cost** desktop pet: delightful enough to keep,
quiet enough that nobody minds it launching at login every day.

> **Status: pre-alpha.** The three existential validation spikes are complete (all green) and
> the portable core renders and behaves on screen: it sleeps, wakes to watch the cursor, and can
> be picked up, carried, and dropped onto nearby window edges. Not yet a polished pet — see
> [Roadmap](#roadmap).

## Architecture

Three layers, split so the costly per-platform work is isolated ("shared brain, swappable boots"):

| Layer | What | Portability | Where |
|---|---|---|---|
| **1 — Cat Brain** | behavior state machine, idle timers, movement | 100% portable | [`godot/brain/`](godot/brain) |
| **2 — Rendering** | sprite drawing, transparent window, frame loop | portable (via Godot) | [`godot/view/`](godot/view), [`godot/main.gd`](godot/main.gd) |
| **3 — OS Integration** | transparent/on-top window, cursor, **other apps' window rects** | per-platform native | [`godot/platform/`](godot/platform), [`native/window_detect/`](native/window_detect) |

- **Engine:** Godot 4.6 (standard build). No Electron/Chromium tax.
- **Native:** a Rust GDExtension reads other apps' window geometry (macOS first), with no
  permission prompt — see [`native/window_detect`](native/window_detect).
- **Idle cost is engineered, not assumed:** on-demand rendering + decoupled think/draw loops +
  escalating dormancy tiers, so a motionless cat costs ~nothing.

## Repository layout

```
desktop-cat-epic-design.md          the parent design doc (concept, architecture, constraints)
desktop-cat-spike-1-idle-cost.md    spike: near-0 idle CPU with transparency (PASS)
desktop-cat-spike-2-window-plumbing.md   spike: borderless/click-through/multi-monitor (PARTIAL)
desktop-cat-spike-3-window-detection.md  spike: read other apps' windows, no permission (PASS)
godot/                              the Godot project — Layers 1 & 2 (+ thin platform wrapper)
native/window_detect/              Rust GDExtension — Layer 3 macOS window detection
klippy-cat*.png                    sprite art (original + alpha-stripped + 256² sprite)
```

## Quick start

```sh
# 1. Build the native Layer-3 module (macOS; Rust ≥ 1.85)
cd native/window_detect && cargo build

# 2. Open the pet project in Godot 4.6 and run it
#    (Godot.app → import godot/ → play, or:)
/Applications/Godot.app/Contents/MacOS/Godot --path godot
```

See [`godot/README.md`](godot/README.md) and [`native/window_detect/README.md`](native/window_detect/README.md)
for details, headless tests, and the toolchain notes learned during the spikes.

## Roadmap

- [x] Validation spikes (idle cost, window plumbing, other-window detection)
- [x] Portable behavior core: sleep / wake-on-cursor / pick-up / carry / drop
- [x] Pick up & drop — cat-body grab region (not full click-through) + drop-landing onto window edges
- [ ] Sprite-sheet animation per state (curled sleep, breathe, scruff-held) — procedural for now
- [ ] Window-riding (ride along / fall off windows, beyond the drop-landing snap)
- [ ] Cursor-velocity reactions (fast wiggle → pounce/chase)
- [ ] Menu-bar agent packaging (no dock icon) + display sleep/wake handling
- [ ] Windows / Linux Layer-3 backends

## License

MIT
