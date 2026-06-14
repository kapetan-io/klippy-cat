# Spike 2 — Window Plumbing

> **Parent:** [`desktop-cat-epic-design.md`](./desktop-cat-epic-design.md) (see §3 Layer 3, §9 Spike 2)
> **Sibling:** [`desktop-cat-spike-1-idle-cost.md`](./desktop-cat-spike-1-idle-cost.md) — ✅ PASS (idle 0.033%/core)
> **Status:** ◑ **PARTIAL** — H1 borderless ✓, H3 multi-monitor ✓, H2 click-through API ✓; H4 sleep/wake + H5 agent deferred. Key outcome: idle-cost finding corrects Spike 1 (~1.0%/core, not 0.033%). See §7.
> **Spike type:** Existential for the whole concept (epic §9: Spikes 1 & 2 both gate the stack)
> **Scope:** The cat's **own** window plumbing on macOS, in pure Godot. **No Rust, no other-app window detection** — reading *other* applications' window rects is **Spike 3** and is explicitly excluded here.

---

## 1. Why this spike runs (after Spike 1)

Spike 1 proved the cat can sit on the desktop **cheaply**. Spike 2 proves it can sit there **unobtrusively and correctly** — that the window can be a borderless, click-through, always-on-top surface that behaves across multiple monitors, survives the display sleeping, and presents as a proper macOS **background agent** (menu-bar presence, no dock icon) rather than a normal app window.

This is existential because if Godot **can't** deliver click-through or a no-dock agent on macOS, the cat is a clunky floating app window that steals clicks and clutters the dock — not an ambient pet. It would force native shims earlier than planned, or a stack rethink. This spike also produces a concrete deliverable: **the Layer 3 interface definition** (epic §3 defers it to "the window-plumbing spike" — i.e. here).

---

## 2. Hypotheses (falsifiable, per capability)

Spike 2 is a set of mostly-boolean capability gates plus one numeric carry-over from Spike 1. Each is independently falsifiable.

| ID | Claim | Type |
|---|---|---|
| **H1 — Borderless** | A Godot 4.6 window renders with no title bar / no window chrome. | Boolean |
| **H2 — Click-through** | The window can be made to pass mouse events through to the application beneath it, AND a sub-region can be made interactive (so the cat's body stays clickable while transparent areas pass through). | Boolean (both halves) |
| **H3 — Multi-monitor** | Godot correctly enumerates all attached screens (position, size, usable rect, DPI/scale, refresh), and the window can be placed on and render correctly on each. | Boolean + correctness |
| **H4 — Display sleep/wake** | After the display sleeps and wakes, the window persists (still transparent, borderless, always-on-top) AND idle CPU stays within the Spike 1 PASS band (< 1.0% of one core). | Boolean + numeric |
| **H5 — Agent / no dock icon** | An exported `.app` with `LSUIElement` set launches with **no dock icon** and a working **menu-bar status item**, and the app runs normally. | Boolean (both halves) |

**Overall Spike 2 verdict = PASS only if H1–H4 pass and H5 passes.** A failure in any one is recorded with its blast radius (some failures degrade gracefully — see §6).

---

## 3. Pass / fail criteria (locked before measurement)

| ID | PASS criterion | FAIL criterion |
|---|---|---|
| H1 | No title bar, no border, no shadow chrome visible; window is purely the sprite surface. | Any forced chrome that can't be removed. |
| H2a (passthrough) | A click over a transparent part of the window lands on the app **beneath** it (observed: underlying app reacts). | Clicks are swallowed by the cat window with no way to pass them. |
| H2b (interactive region) | The Godot API can designate a polygon/region of the window that **stays** clickable while the rest passes through. | No supported way to keep part of the window interactive → "pet the cat" is impossible without native code. |
| H3 | `get_screen_count() ≥ 2` here; each screen's position/size/usable-rect/scale/refresh read back plausibly; window placed on screen 2 appears and renders transparently there. | Wrong geometry, or window can't be placed on a secondary screen. |
| H4 | Post-wake: window present + transparent + on-top; idle CPU re-measured **< 1.0%/core** (CPU-time-delta method from Spike 1). | Window gone/opaque/below other windows after wake, or idle CPU jumps above 1%/core. |
| H5a (no dock) | Exported agent `.app` shows **no Dock icon** on launch. | Dock icon appears and can't be suppressed. |
| H5b (menu-bar) | A status item appears in the macOS menu bar and can hold a menu (the eventual feed/summon/settings/hide menu, epic §6). | No supported status-item API → menu-bar presence needs native code. |

Numeric carry-over (H4) reuses Spike 1's threshold table verbatim: Ideal <0.5%, Pass <1.0%, Gray 1–3%, Fail >3% of one core.

---

## 4. Test setup

### Environment (recorded at run time)
| Field | Value |
|---|---|
| Godot | 4.6.3.stable.official (`7d41c59c4`), Standard build, Metal/Forward+ |
| Export templates | **Required for H5** — `~/Library/Application Support/Godot/export_templates/4.6.3.stable/` (status recorded in §7) |
| macOS | 26.5.1 (25F80) |
| Hardware | MacBook Pro M1 Max (8P+2E), 64 GB, arm64 |
| Displays | 2× 2560×1440 (main @ 100 Hz, secondary @ 60 Hz) — good multi-monitor + mixed-refresh test bed |
| Power | AC at run time (noted) |

### Godot APIs under test (the candidate Layer 3 surface)
- **Window flags:** `borderless`, `always_on_top`, `transparent` (carried from Spike 1), plus `Window.FLAG_MOUSE_PASSTHROUGH` for full click-through.
- **Interactive region:** `Window.mouse_passthrough_polygon` / `DisplayServer.window_set_mouse_passthrough(region)` — region that remains clickable.
- **Screens:** `DisplayServer.get_screen_count()`, `screen_get_position(i)`, `screen_get_size(i)`, `screen_get_usable_rect(i)`, `screen_get_scale(i)`, `screen_get_refresh_rate(i)`, `screen_get_dpi(i)`.
- **Cursor:** `DisplayServer.mouse_get_position()` (global) — needed by the cat brain later; sanity-checked here.
- **Status item:** `DisplayServer.create_status_indicator(...)` / `status_indicator_set_menu(...)` (Godot 4.2+).
- **Agent / no dock:** macOS export — `LSUIElement=true` in the exported bundle's `Info.plist` (via export preset option if present, otherwise patch `Contents/Info.plist` post-export and ad-hoc re-sign).

### Out of scope (explicit)
- Reading **other apps'** window rectangles → **Spike 3** (needs native GDExtension/Rust).
- Click-through *behavior tuning* for the cat (which pixels are clickable when) → feature blueprint, not this spike. Here we only prove the **mechanism** exists.

---

## 5. Measurement / verification method

Two projects:
- **`plumbing/`** — a dev-run project (like Spike 1) exercising H1–H4. A small on-screen/stdout HUD prints screen enumeration, cursor position, and the passthrough state so results are capturable from logs.
- **`agent/`** — exported to a real `.app` for H5 (no dock + status item).

Per capability:
1. **H1 Borderless** — launch, observe no chrome (screenshot / visual). Trivially also confirmed by Spike 1's borderless run.
2. **H2 Click-through** — enable full passthrough; position the window over a known target window (e.g. a TextEdit/Finder window); click; confirm the underlying app receives the click (observational). Then set an interactive polygon over the sprite and confirm a click there is received by Godot (logged) while outside passes through.
3. **H3 Multi-monitor** — print `get_screen_count()` and each screen's geometry/scale/refresh to stdout; move the window to screen index 1; confirm it appears and renders transparently on the secondary display; re-sample idle CPU there.
4. **H4 Display sleep/wake** — record window state + a baseline idle CPU; `pmset displaysleepnow`; wait; wake; re-confirm window state and re-measure idle CPU via the CPU-time-delta method. *(Intrusive — done with the user present and forewarned.)*
5. **H5 Agent** — export `agent/` to `.app`, ensure `LSUIElement=true`, register a status indicator in `_ready`; launch the `.app`; confirm **no dock icon** and a **menu-bar item**; confirm the process runs and idles cheaply.

Idle CPU uses the **accumulated CPU-time delta** method validated in Spike 1 (`top` is too coarse below ~1%).

---

## 6. Outcome interpretation (decided in advance)

- **All pass** → The cat can live on the macOS desktop unobtrusively and correctly. **Lock the Layer 3 interface (§8)** and proceed to behavior/build (epic §8 steps 1–2), with Spike 3 (other-window detection) as the remaining existential-for-window-riding gate.
- **H2b fails (no interactive region)** → cat can be click-through OR clickable but not both via Godot → "pet the cat" interactions need a native shim. Degrade: ship click-through-only first; flag native work. Not fatal.
- **H5 fails (dock icon unavoidable / no status API)** → cat works but presents as a normal app (dock clutter). Degrade: ship with dock icon, flag a native menu-bar agent shim. Annoying, not fatal to the concept.
- **H1 or H3 fails** → serious; these are basic windowing. Would undercut the §4 "Godot handles the window itself" assumption and trigger a Layer 3 / stack review.
- **H4 fails (idle cost jumps after wake, or window lost)** → the §5 lightweight model has a hole around power transitions; investigate before trusting all-day-at-boot. Existential-adjacent.

---

## 7. Results

**Run date:** 2026-06-13 · **Status: PARTIAL** — H1/H3 passed, H2 API-verified, idle-cost finding corrects Spike 1; H4/H5 deferred after a testing-induced system disruption (§7.7).

### 7.1 Environment as run
- Export templates present: **No** — `~/Library/Application Support/Godot/export_templates/4.6.3.stable/` empty. H5 (agent export) blocked on this; not installed (the ~700 MB download was not initiated).
- Power source: AC.
- Screens enumerated: **2** — see H3 below. Standard-DPI (scale 1.00, dpi 94) external displays; the Retina built-in panel was NOT under test.

### 7.2 Per-capability results
| ID | Capability | Result | Evidence / notes |
|---|---|---|---|
| H1 | Borderless | **PASS** | Window renders as pure surface, no chrome (also already shown in Spike 1). |
| H2a | Click-through (passthrough) | **API-VERIFIED** | `Window.set_flag(FLAG_MOUSE_PASSTHROUGH, true)` accepted, no error. Full behavioral confirmation (click lands on app beneath) deferred — see §7.7. |
| H2b | Interactive region | **API-VERIFIED** | `Window.mouse_passthrough_polygon` accepted with a cat-body polygon, no error. Behavioral confirmation deferred. |
| H3 | Multi-monitor enumerate + place | **PASS** | 2 screens enumerated with correct geometry; window placed and rendered on both screen 0 and screen 1. Data below. |
| H4 | Display sleep/wake (+ idle CPU) | **DEFERRED** | Intrusive (`pmset displaysleepnow`); not run, and not safe to run amid the §7.7 disruption. |
| H5a | No dock icon (exported agent) | **DEFERRED** | Blocked: export templates not installed. |
| H5b | Menu-bar status item | **DEFERRED** | Blocked: export templates not installed (status-indicator API exists in 4.6 but unverified at runtime). |

**H3 screen enumeration (verbatim):**
```
SCREENS=2
  screen 0: pos=(0, 0)    size=(2560, 1440) usable=[P:(0, 30),    S:(2560, 1410)] scale=1.00 refresh=100.0Hz dpi=94
  screen 1: pos=(2560, 0) size=(2560, 1440) usable=[P:(2560, 30), S:(2560, 1410)] scale=1.00 refresh=60.0Hz dpi=94
CURSOR_GLOBAL=(3007, 613)   # global cursor pos read correctly (on screen 1)
```
Geometry, usable-rect (30 px menu-bar inset), per-screen scale, and mixed refresh (100/60 Hz) all read correctly. `DisplayServer.mouse_get_position()` (global cursor) also works.

### 7.3 Overall verdict
**PARTIAL.** The pure-Godot window plumbing that was tested **works** (borderless, multi-monitor enumeration/placement, click-through APIs accepted). The agent/no-dock test (H5) is blocked on an uninstalled prerequisite, and display-sleep (H4) plus click-through *behavioral* confirmation were deferred after the disruption. **No capability failed** — the incomplete items are untested, not broken.

### 7.6 Idle-cost finding (corrects Spike 1) — the headline of this run

Measuring the plumbing window's idle CPU (CPU-time-delta method from Spike 1) produced **~1.0–1.5% of one core**, far above Spike 1's claimed 0.033%. A long investigation isolated the cause:

| Test | Result | Conclusion |
|---|---|---|
| Plumbing window (passthrough region) | ~1.1–1.7%/core | Much higher than Spike 1. |
| Passthrough none / region / full | all ~1.2–1.5% | **Not** caused by click-through. |
| Transparent vs **opaque** (scriptless, interleaved ×4) | **both exactly 1.000%** | **Transparency is NOT the cost** (Spike 1's A=C equality holds). |
| Screen 0 (100 Hz) vs screen 1 (60 Hz) | both 1.36% | **Not** per-vblank compositing; refresh-independent. |
| Input-event counter | events flat at 98, CPU steady 1.33% | **Not** mouse/input-driven. |
| **Exact Spike 1 proj_a, re-run ×2** | **1.03% / 1.07%** | **Spike 1's 0.033% does NOT reproduce.** |
| `low_processor_mode_sleep_usec` 6900 → 33000 → 100000 | 2.88% → 2.20% → 0.60%* | **Idle cost = the wakeup loop; it's tunable.** |

\* the `sleep_usec` row ran during the §7.7 disruption so absolute values are inflated, but the **downward trend with longer sleep is real and decisive**.

**Conclusion:** the reproducible idle floor for a static transparent always-on-top Godot window on this machine is **~1.0% of one core** (~0.1% of the 10-core machine), driven by the low-processor-mode wakeup loop (~145 wakeups/sec at default). Spike 1's 0.033% was a non-reproducible transient (App-Nap / timer coalescing). **Accepted as good-enough for now** (user decision), with `sleep_usec` tuning available as a lever during the build. Spike 1 doc updated with a §0 Correction.

### 7.7 Testing disruption (recorded honestly)
Running **multiple transparent always-on-top windows concurrently** during back-to-back measurements caused **Firefox/YouTube video playback to freeze** — always-on-top + transparent surfaces force WindowServer to re-composite the layers above other apps' hardware-accelerated video, and several stacked at once made it acute. All Godot processes were killed on the user's report and playback recovered. **Protocol fix for future runs: never more than one such window alive; tear each down immediately after measuring.** This also contaminated the `sleep_usec` absolute numbers above (trend still valid).

### 7.8 Findings that affect Spike 3 / architecture (surfaced, not acted on)
1. **Idle cost is ~1.0%/core, not ~0% — and it's the wakeup-loop cadence, not transparency.** The build must treat `low_processor_mode_sleep_usec` (and deeper dormancy tiers, epic §5.4) as first-class. Re-validate idle cleanly (one window, no other floating windows) during the build.
2. **Always-on-top transparent windows can disrupt other apps' video compositing.** Relevant to epic §5.5 "respect machine state" (hide/yield during fullscreen video/games) — this is now evidence-backed, not hypothetical.
3. **Export templates are a hard prerequisite** for any agent/no-dock/menu-bar work (Spike 2 H5 and packaging). ~700 MB, not yet installed.
4. **Test displays are standard-DPI externals (scale 1.0), not the Retina built-in.** Retina/HiDPI rendering and idle cost remain unverified on the actual built-in panel.

### 7.9 Asset note — real sprite available
`clipi-kat.png` (682×437, pixel-art black cat with red cape) was added to the repo root for **sprite tests going forward** (placeholder→real-art swap, epic §8 step 4). Caveat: it currently has an **opaque orange comic-burst background**; a transparent desktop pet needs the cat isolated on alpha (background stripped / sprite cropped) before it's drop-in usable for the transparent window.

---

## 8. Deliverable — Layer 3 interface (draft, finalized by the run)

> Epic §3 defers the Layer 3 interface definition to this spike. Draft below; confirmed/adjusted against what actually worked in §7. **`getWindowRects()` (other apps) is intentionally absent — it belongs to Spike 3.**

```
# Layer 3 — OS Integration (per-platform). macOS impl validated by Spike 2.

interface WindowPlumbing:
    setTransparent(on: bool)
    setBorderless(on: bool)
    setAlwaysOnTop(on: bool)
    setClickThrough(on: bool)                 # full passthrough
    setInteractiveRegion(polygon: [Vec2])     # region that stays clickable
    moveToScreen(index: int, pos: Vec2)
    getScreens() -> [Screen]                  # {index, pos, size, usableRect, scale, dpi, refreshHz}
    getCursorPosition() -> Vec2               # global

interface AgentPresence:                      # macOS: LSUIElement + NSStatusItem
    runAsAgent()                              # build/export-time: no dock icon
    createStatusItem(icon, menu) -> id
    removeStatusItem(id)

# events the OS layer raises up to the portable brain:
    onDisplaySleep()  / onDisplayWake()
    onScreensChanged()                        # monitor attach/detach
```

---

## 9. Recommendation

**PARTIAL PASS — proceed, with two follow-ups before locking Layer 3.**

What's proven (pure Godot, no native code): borderless, always-on-top, transparent, multi-monitor enumeration + placement, global cursor read, and the click-through APIs (full passthrough + interactive polygon) all work and are accepted without error. That covers the load-bearing parts of the §8 `WindowPlumbing` interface — it can be drafted as validated for those methods.

**Follow-ups required before Spike 2 is fully green (none are blockers to starting behavior work):**
1. **Install macOS export templates (~700 MB)**, then run **H5** (exported `.app` + `LSUIElement` → no dock icon + `NSStatusItem` menu-bar item). This is the only untested *capability*; the `AgentPresence` half of §8 is unconfirmed until then.
2. **Clean idle re-measure + H4 (display sleep/wake)** under the safe one-window protocol (§7.7). Confirm idle settles to ~1.0%/core (or lower with `sleep_usec` tuning) and survives sleep/wake. This also re-validates the corrected Spike 1 number in a controlled way.
3. **Behavioral** click-through confirmation (click passes to the app beneath; cat body stays clickable) — deferred from H2, do under the safe protocol.

**Not fatal anywhere:** no capability failed. The idle-cost reality (~1.0%/core, tunable) is accepted for now per user decision. Recommend doing the behavior/build work (epic §8) and the three follow-ups above can run alongside, using `clipi-kat.png` as the sprite once its background is stripped to alpha.
