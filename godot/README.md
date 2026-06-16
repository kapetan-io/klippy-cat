# Klippy-Cat — Godot project (Layers 1 & 2)

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
├── platform/desktop.gd    thin Layer-3 wrapper: cat's OWN window + cursor + drop-landing lookup
├── window_detect.gdextension   loads the native module (../native/window_detect) for drop-landing
├── assets/                klippy-cat-sprite-256.png (placeholder art)
└── tests/run_tests.gd     headless Layer-1 tests (no window)
```

## The cat is the window
A 256×256 transparent surface repositioned to the cat's centre as it moves. So the cat's
global position is directly comparable to `WindowDetect`'s window rects — which is what
window-riding (Spike 3) will use.

## Idle discipline (epic §5 — engineered, not assumed)
Two loops, decoupled:
- **Heartbeat Timer → `think()`** — slow decision tick (a few Hz), always on, cheap. Polls
  the cursor, sleeps / wakes-to-watch.
- **`_process()` → `move()`** — per-frame movement, switched **on only while carried/landing
  (tier 2)** and **off the instant the cat settles**, so a still cat pushes no frames.

`_apply_tier()` slows the heartbeat and caps fps as the cat sleeps deeper:

| Tier | State | Heartbeat | max_fps |
|---|---|---|---|
| 0 Asleep | resting (default) | ~3 Hz | 10 |
| 1 Watching | tracking a near cursor | 10 Hz | 10 |
| 2 Active | carried / landing | 60 Hz | 60 |

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
`SLEEP → WATCH → HELD → LANDING`. The cat sleeps by default; the only thing it does on its
own is wake to watch a near cursor. You move it by hand:

- **SLEEP** — resting in place; the engine idles here.
- **WATCH** — cursor within `WAKE_RADIUS` → awake and facing the cursor (no wandering).
- **HELD** — a left-click on the cat body grabs it; it hangs `HOLD_OFFSET` below the cursor and
  sways as you drag (a `lerp` lag gives the pendulum). Follows the **global** cursor, so you can
  drag it anywhere.
- **LANDING** — on release, the platform looks for a window top-edge within `LAND_RANGE` that the
  cat is over (via the native `WindowDetect` module); if found, the cat slides onto it, else it
  settles exactly where it was dropped. Either way → **SLEEP**.

`grab()` / `release(landing)` are external events: the OS layer (`main.gd`) detects the click;
the brain stays portable and never touches the window or the mouse buttons itself.

### Picking up the cat (Layer 3 notes)
- The window uses a **`mouse_passthrough_polygon`** over the cat body (not full click-through),
  so clicks on the cat are grabs while the transparent corners fall through to apps behind.
- If a grab doesn't register on macOS (a borderless no-focus window may not be handed clicks),
  flip `Desktop.GRAB_STEALS_FOCUS = true` — the window then takes focus on click so the grab lands.
- Drop-landing needs the native module loaded: `window_detect.gdextension` + a local
  `window_detect.dylib` (copied from `../native/window_detect/target/debug/`). **Open the project
  in the editor once** after adding it so `.godot/extension_list.cfg` registers it. Without it,
  landing degrades to "stay where dropped".

## Build-order status (epic §8)
- [x] Transparent always-on-top window + rendered sprite
- [x] Pick up / carry / drop, with drop-landing onto nearby window edges
- [x] Window-detection spike (→ `native/window_detect`), now wired into the live project
- [~] Procedural animation (carry sway, landing squash, sleep pose) — real sprite-sheet art next

## Next
- Real sprite-sheet art per state (curled sleep, breathe, scruff-held) to replace the procedural
  transforms in `CatView`.
- Pivot the carry sway at the scruff (top of the sprite) for a truer dangle.
- A `CatConfig` resource for the tunables now hard-coded in `cat_brain.gd` / `desktop.gd`.
