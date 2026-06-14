# Clipi-Cat — Godot project (Layers 1 & 2)

The portable core of the desktop pet: the **Cat Brain** (behavior) and **Rendering**. OS
integration lives elsewhere — the cat's own window is handled by Godot + a thin wrapper
(`platform/desktop.gd`); reading *other* apps' windows is the native `WindowDetect` module
(`../native/window_detect`). This split is the epic's "shared brain, swappable boots."

## Layout

```
godot/
├── project.godot          transparent/borderless/always-on-top, low_processor_mode
├── main.tscn / main.gd    root: owns the window, runs the two decoupled loops
├── brain/cat_brain.gd     LAYER 1 — portable behavior FSM (no Godot/OS knowledge)
├── view/cat_view.gd       LAYER 2 — rendering (static sprite now; sheet-anim later)
├── platform/desktop.gd    thin Layer-3 wrapper for the cat's OWN window + cursor
├── assets/                clipi-kat-sprite-256.png (placeholder art)
└── tests/run_tests.gd     headless Layer-1 tests (no window)
```

## The cat is the window
A 256×256 transparent surface repositioned to the cat's centre as it moves. So the cat's
global position is directly comparable to `WindowDetect`'s window rects — which is what
window-riding (Spike 3) will use.

## Idle discipline (epic §5 — engineered, not assumed)
Two loops, decoupled:
- **Heartbeat Timer → `think()`** — slow decision tick (a few Hz), always on, cheap. Polls
  the cursor, picks a state.
- **`_process()` → `move()`** — per-frame movement, switched **on only for active (tier 2)**
  states and **off the instant the cat settles**, so a still cat pushes no frames.

`_apply_tier()` slows the heartbeat and caps fps as the cat sleeps deeper:

| Tier | State | Heartbeat | max_fps |
|---|---|---|---|
| 0 Dormant | deep sleep | 1 Hz | 10 |
| 1 Watching | idle / tracking cursor | 10 Hz | 10 |
| 2 Active | walking / chasing | 10 Hz | 60 |

> Spikes measured ~1% of one core at the default wake interval, tunable lower via
> `low_processor_mode_sleep_usec`. Re-validate idle cleanly (one window) as behavior grows.

## Run

```sh
# headless Layer-1 tests (safe, no window)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot -s res://tests/run_tests.gd

# live pet (opens a transparent always-on-top window)
/Applications/Godot.app/Contents/MacOS/Godot --path godot
```

## State machine (Layer 1)
`DORMANT → IDLE → WATCH → WANDER`, driven by cursor proximity and idle time:
cursor within `WAKE_RADIUS` → **WATCH** (track) → within `APPROACH_RADIUS` → **WANDER**
(walk toward it); cursor gone → **IDLE**, escalating to **DORMANT** after `SLEEP_AFTER`;
spontaneous wander to a random point while idle.

## Build-order status (epic §8)
- [x] Transparent always-on-top window + rendered sprite
- [~] Follows cursor / wanders / sits idle — **this sketch** (tune feel next)
- [x] Window-detection spike (→ `native/window_detect`)
- [ ] Swap placeholder for real sprite-sheet animation (states defined by behavior first)

## Next
- Cursor *velocity* (fast wiggle → pounce/chase vs slow → watch).
- Click reactions (needs a cat-body interactive region instead of full click-through).
- Sprite-sheet animation in `CatView` per state.
- A `CatConfig` resource for the tunables now hard-coded in `cat_brain.gd`.
