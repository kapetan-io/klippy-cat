# Desktop Pixel Cat — Epic Design Document

> **Status:** Scoping / pre-spike
> **Purpose:** This is the top-level design driver. It captures the concept, architecture, constraints, and decisions made so far. It is the parent document for all downstream spike docs and per-feature blueprints. Feature-level design (state machine internals, window-detection internals, etc.) belongs in child documents, not here.

---

## 1. Concept

A small pixel-art cat that lives on the desktop. It is a transparent, always-on-top, click-through companion that wanders, reacts to the cursor and clicks, naps when ignored, and — where the OS allows — treats application windows as physical surfaces it can sit on, ride, and fall off of.

The design goal is an **ambient, lifelike, low-cost** desktop pet: something delightful enough to keep and quiet enough that nobody minds it launching at login every day.

### Guiding principles
- **Lightweight first.** It starts at boot and runs all day. If it's noticeable in CPU, memory, or battery, it gets uninstalled. Lightweight is a hard requirement, not a nice-to-have.
- **Lifelike through economy.** A real cat sleeps most of the day and explodes into motion briefly. Designing for near-zero idle cost naturally produces a more believable pet. Economy and charm align.
- **Shared brain, swappable boots.** Behavior and rendering are written once; OS integration is isolated behind a clean interface so new platforms add a module, not a rewrite.
- **Graceful degradation.** The cat must be a complete, satisfying product *without* its riskiest, least-portable feature (window-riding). That feature is an enhancement that disappears where it can't run.

---

## 2. Target & Platform Strategy

**macOS first.** Ship a complete macOS product before any other platform.

Cross-platform is an explicit future goal, but the app is architected so that adding Windows (and possibly Linux) means implementing one thin native layer, not rewriting the cat.

### Platform reality (recorded for downstream planning)

| Platform | Transparency | Click-through | Other-window geometry | Notes |
|---|---|---|---|---|
| macOS | Strong | Good | Accessibility API (needs permission) | First target. Permission friction is the main cost. |
| Windows | Strong | Easy | Win32 enumeration | Best support for window-riding. Future. |
| Linux | X11 good / Wayland restrictive | X11 yes / Wayland hard | X11 easy / Wayland basically blocks it | Window-riding likely unavailable on Wayland — must degrade gracefully. |

The **"sit on / ride / fall off other windows"** feature is the single biggest portability tax: Accessibility on macOS, Win32 on Windows, effectively impossible on Wayland. The cat must be fully functional without it.

---

## 3. Architecture

Three layers, with the dividing line drawn so that the costly per-platform work is isolated.

### Layer 1 — Cat Brain (100% portable)
The behavior state machine, idle timers, weighted random animation picker, cursor-chase logic, sprite-sequence selection. Written once. Knows nothing about the OS.

### Layer 2 — Rendering (portable via the engine)
Sprite drawing, the transparent window surface, the frame loop. Shared across platforms because the rendering engine is cross-platform. Built assuming **sprite-sheet, frame-based, swappable states** from day one.

### Layer 3 — OS Integration (per-platform, the risky layer)
No shared API exists across OSes for this. It is deliberately isolated behind a narrow interface so the rest of the app never knows which OS it's on. Responsibilities:
- Transparent / borderless / always-on-top / click-through window
- Global cursor position
- Reading other applications' window rectangles
- Permissions
- Menu-bar / tray agent presence (no dock icon)

> The exact interface this layer exposes (e.g. `getWindowRects()`, `setClickThrough()`, `getCursorPos()`) is to be defined in the window-plumbing spike, not here.

**Per-platform cost summary:** Layers 1–2 are shared. Layer 3 is written once per platform, and *other-window detection* in particular must be implemented separately for each. Day one ships only the macOS Layer 3, with the interface stubbed where features aren't yet built.

---

## 4. Technology Decision

**Engine: Godot.**

### Rationale
- No browser/Chromium tax — avoids the Electron-class footprint.
- Self-contained native binary, real control over the frame loop, native rendering.
- Cross-platform, preserving the shared Layer 1–2 goal with good dev velocity.

### Accepted trade-offs (recorded honestly)
- **Godot is not automatically lightweight.** A naive game loop renders 60fps forever and spins a core on a sleeping cat. Idle cost must be engineered, not assumed (see §5).
- **Memory at rest** is higher than a hand-rolled native agent because the engine runtime is carried — tens of MB, not hundreds. Acceptable for the dev-speed and portability gain.
- **Binary size** is fine with a stripped export that drops unused modules.
- **Other-window detection still needs a GDExtension (native code) per platform.** Godot's transparency/always-on-top handles the window itself, but reaching *other apps'* geometry is not built in.

### The alternative we consciously rejected
A native **Swift / AppKit** agent would be the genuinely-lightest macOS option (smallest memory, lowest idle, cleanest menu-bar agent). Rejected because it sacrifices the portable core and multiplies per-platform work — at odds with the cross-platform goal and dev velocity.

---

## 5. The Lightweight Constraint: Idle Throttling

This is a first-class design constraint, not an optimization done later. The mental model: **the cat has a metabolism, and most of the day it should be nearly dead to the CPU.**

### Activity tiers

**Tier 0 — Dormant (~0% CPU, no rendering).**
Asleep or static idle pose. The sprite isn't changing, so *nothing is drawn.* No frames, no redraws — effectively a paused image. Only a slow heartbeat checks "should I wake up?" This is where the cat spends most of a workday.

**Tier 1 — Watching (very low).**
Awake but still — sitting, loafing, tracking the cursor with its eyes. Cursor is *polled* lazily (~5–10x/sec, not 60). The eye won't notice an 8fps gaze update; the CPU will.

**Tier 2 — Active (normal, brief).**
Walking, chasing, pouncing — full animation at 30/60fps. Always a short burst of a few seconds, then settle back to Tier 1 or 0. Active is the exception, never the resting state.

### Core disciplines

1. **On-demand rendering, not a free-running loop.** The most important rule. Draw only when something visually changed. A static sleeping cat pushes zero frames. (Godot's low-processor / redraw-on-request mode is the mechanism.)
2. **Decouple thinking from drawing.** The decision loop ticks slowly (a few times/sec is plenty). The animation loop only spins up when a decision triggers motion. Don't run both at 60fps because one occasionally needs to.
3. **Event-driven wake-ups where possible.** React to OS events (mouse moved, focus changed) instead of polling. Cursor proximity may require polling — if so, make it lazy and the *only* thing polling during Tier 1.
4. **Sleep deeper the longer nothing happens.** Escalate dormancy: idle 30s → sit; 2min → lie down; 5min → deep sleep, drop to Tier 0 and slow the heartbeat itself (e.g. 10x/sec → 1x/sec). Cheaper *and* cuter as time passes.
5. **Respect machine state.** On battery → throttle harder, longer timers, lower active framerate. Screen locked / display asleep → full Tier 0. Fullscreen app in focus (game/video) → consider hiding entirely; never cost frames during someone's game.

### The rule of thumb
**A motionless cat costs nothing. A watching cat costs almost nothing. Only a moving cat is allowed to cost real CPU — and it's only ever moving briefly.**

---

## 6. Events & Interactions

### Events the app listens for
- Mouse movement — proximity, speed, direction
- Clicks — left / right / double, on the cat vs. elsewhere
- Idle detection — no input for N seconds/minutes
- Window geometry — positions, sizes, focus changes (for window-riding)
- System signals — time of day, battery, do-not-disturb, audio playing
- Dragging — picking the cat up and releasing it

### Interaction catalog (expected behavior)
- Cursor approaches slowly → cat watches, head tracks
- Cursor moves fast / wiggles → cat chases or pounces
- Click on cat → reacts (purr, meow, startle, swat)
- Cat sits on the active window's top edge; window moves → cat rides; window closes → cat drops and lands
- Drag the cat → it dangles, then plops (possibly grumpy) on release
- Long idle → cat curls up and naps somewhere (corner, on a window)
- Right-click → small menu (feed, summon, settings, hide)

---

## 7. Animation Set

Idle filler and rare animations are what sell the "alive" feeling; a weighted random picker prevents repetition. The final required state list is **defined by** the behavior decisions, so it is settled *after* the behavior loop is prototyped against a placeholder — not drawn up front.

**Essential states:** idle/breathing, walk + run cycles (L/R), sit, lie down, sleep (curl + Zzz), wake/stretch + yawn.

**Reactive:** watch cursor (head/eye tracking), pounce/chase, startle, groom/lick paw, swat, being held/dragged (dangle), land/plop after a fall.

**Delight / rare:** chase a cursor "fly," knock a tiny pixel object off a window edge, loaf (bread pose), tail flick when annoyed, falling-asleep-mid-stretch fail.

---

## 8. Build Order

Plumbing is the risk; art is not. Build the app shell with a **generic placeholder sprite** (a colored square with `idle`/`walk`/`sleep` "states") first, and nail the *feel* of motion before committing to artwork. The renderer assumes sprite-sheet animation from day one so dropping in real art later is a content swap, not a rewrite.

1. Transparent always-on-top window + placeholder square that renders.
2. Square follows cursor / wanders / sits idle — tune motion feel and the state machine.
3. Window-detection spike (Accessibility API) — prove "sit on a window edge" in isolation.
4. Swap the square for real sprites, now that the required states are known.

---

## 9. Validation Spikes (do before committing real effort)

Each spike answers a "could this kill the design?" question cheaply. Order matters.

**Spike 1 — Idle-cost + transparency combo (FIRST, existential).**
Transparent + always-on-top + on-demand redraw, motionless sprite. Confirm **near-0% idle CPU on macOS.** This validates the entire lightweight premise. If transparency forces continuous compositing and near-zero is unreachable, the whole cost model — and possibly the stack — changes. Know this on day one.

**Spike 2 — Window plumbing (existential).**
Borderless, click-through, multi-monitor spanning, surviving display sleep/wake, running as a menu-bar agent with no dock icon. Proves the cat can live on the desktop unobtrusively. Defines the Layer 3 interface.

**Spike 3 — Other-window detection (existential only for window-riding).**
The Accessibility-permissions spike for reading other apps' window rects. Riskiest and least-portable feature. Prove it on macOS in isolation, and confirm the cat **degrades gracefully without it** (this protects the future Linux/Wayland story).

### Spike priority logic
Spikes 1 and 2 are existential for the whole concept — if either fails, rethink the stack. Spike 3 is existential only for the window-riding feature — if it fails, ship a cat that wanders the desktop without sitting on windows, still a complete product.

Only after 1–3 are green: build the behavior state machine against the placeholder (Build Order steps 1–2), then swap in real sprites last.

---

## 10. Downstream Documents

This epic drives the following child documents, to be written as each is approached:
- **Per-spike design docs** — one each for Spikes 1, 2, 3.
- **Per-feature blueprints** (via the blueprint-create flow) — window plumbing, behavior state machine, window-riding, animation system, etc.

Feature-level and spike-level decisions live in those documents. This epic stays broad and shallow: concept, architecture, constraints, and the spike/feature index they hang off of.
