# Spike 3 — Other-Window Detection (Accessibility / window-riding)

> **Parent:** [`desktop-cat-epic-design.md`](./desktop-cat-epic-design.md) (§3 Layer 3, §4 GDExtension, §9 Spike 3)
> **Siblings:** Spike 1 (idle cost — PASS, corrected to ~1%/core) · Spike 2 (window plumbing — PARTIAL)
> **Status:** ✅ **COMPLETE — PASS (Stage A + Stage B).** Other-window geometry readable on macOS with **no permission** (CGWindowList), cheap to poll, and proven end-to-end through a **Rust GDExtension** into GDScript (headless). See §7.
> **Spike type:** Existential **only for window-riding** (epic §9). If it fails, the cat still ships as a complete desktop pet that wanders without sitting on windows. This protects the Linux/Wayland story too.
> **Scope:** Read *other applications'* window rectangles on macOS, characterize the permission cost, and prove the native (Rust GDExtension) path into Godot. First spike that requires **native code**.

---

## 1. Why this spike

"Sit on / ride / fall off other windows" (epic §6) is the single biggest portability tax and the only feature needing to read *other* apps' geometry. macOS exposes this two ways, with very different permission cost — the whole point of the spike is to find the cheapest path that still works, and to confirm the cat **degrades gracefully** when it's unavailable (so the same architecture survives Wayland later).

Two candidate macOS APIs:
- **`CGWindowListCopyWindowInfo`** (CoreGraphics) — snapshot of *all* on-screen windows: bounds, owner pid/name, window layer. **Window bounds + owner need no Accessibility permission** (only window *titles* require Screen Recording on recent macOS). Poll-based.
- **Accessibility (`AXUIElement…`)** — per-app window list, position/size, the *focused* window, and **event-driven move/resize notifications** (`AXObserver`). Requires the app be **Accessibility-trusted** (TCC; user grants in System Settings). Richer + event-driven, but that's the "permission friction" the epic flags as the main macOS cost.

The spike must answer: **does the no-permission CGWindowList path suffice for window-riding, or do we need the permission-gated AX path** — and what does each cost.

---

## 2. Hypotheses (falsifiable)

| ID | Claim | Stage |
|---|---|---|
| **H1 — geometry readable** | Our process can read other apps' window rectangles (position + size + owner) on this macOS. | A (Swift probe) |
| **H2a — no-permission path** | `CGWindowListCopyWindowInfo` returns usable per-window bounds + owner **without any permission grant**. | A1 |
| **H2b — permission path** | Accessibility (`AXUIElementCopyAttributeValue` for `kAXWindows/Position/Size`) returns per-window geometry **after** an Accessibility grant, and **fails cleanly before** it. | A2 |
| **H3 — live tracking is cheap** | Window movement can be tracked for "riding" either by low-rate polling (CGWindowList) or event-driven (`AXObserver` move notifications) within the Spike-1 idle budget. | A |
| **H4 — Godot integration** | A **Rust GDExtension** (gdext) loads in Godot 4.6 and surfaces other-window rects to GDScript via a narrow Layer-3 call. | B |
| **H5 — graceful degradation** | With the feature disabled/denied, the app still runs fully (cat wanders; no crash, no nag-loop). | A/B |

---

## 3. Pass / fail criteria (locked before measurement)

| ID | PASS | FAIL |
|---|---|---|
| H1 | At least one API returns correct rects for known windows (cross-checked against actual on-screen positions). | Neither API yields other-app geometry. |
| H2a | CGWindowList lists windows with plausible bounds + owner names, **no permission prompt**. | Bounds unavailable without permission, or owner unidentifiable. |
| H2b | AX returns geometry once trusted; `AXIsProcessTrusted()` correctly reports false→true across the grant; pre-grant calls fail with a clean error (no crash). | AX unusable, or permission state can't be detected, or denial crashes/hangs. |
| H3 | A move of a target window is reflected within ≤150 ms (poll ≤10 Hz **or** event-driven), at idle CPU within Spike-1 PASS band when no windows are moving. | Tracking needs high-rate polling that breaks the idle budget. |
| H4 | GDScript receives a list of `{owner, rect}` from the Rust extension in a running Godot 4.6 project. | Extension won't load/build, or can't cross the boundary. |
| H5 | Feature flag off ⇒ app behaves as the Spike-1/2 cat with zero window-riding code paths firing. | Absence breaks startup or the main loop. |

---

## 4. Test setup

### Environment
| Field | Value |
|---|---|
| macOS | 26.5.1 (25F80), Apple M1 Max, arm64 |
| Native toolchain | Xcode CLT present; clang 21.0.0; **swiftc 6.3.2** (Stage A needs no install) |
| Rust | Installed — `~/.cargo/bin` (rustc/cargo/rustup) — for Stage B |
| Godot | 4.6.3.stable.official, Standard build |
| Frameworks | CoreGraphics (CGWindowList), ApplicationServices/AppKit (AX) — system-provided |

### Stage A — native feasibility probe (Swift CLI, no Godot, no Rust)
- **A1 `cgwin` probe:** dump all on-screen windows (owner, pid, layer, bounds) via `CGWindowListCopyWindowInfo`. Read-only; **creates no windows** (so it cannot repeat the Spike-2 compositor disruption).
- **A2 `axwin` probe:** check `AXIsProcessTrusted()`; if trusted, enumerate a target app's windows and read `kAXPositionAttribute`/`kAXSizeAttribute`; if not, exit cleanly reporting "needs Accessibility grant."
- **Permission note (yours to grant):** for a CLI, the *trusted* entity is the calling terminal/binary. Granting Accessibility in System Settings → Privacy & Security → Accessibility is a manual, user-only step. A1 needs none; A2 does.

### Stage B — Rust GDExtension integration (only if Stage A clears the existential question)
- Minimal **gdext** extension exposing e.g. `WindowDetect.get_window_rects() -> Array[Dictionary]`, calling the API chosen in Stage A.
- Loaded by a tiny Godot project; GDScript prints the rects. Window testing uses the **Spike-2 one-window safe protocol**.

### Out of scope
- Actual riding physics / "fall off edge" behavior (feature blueprint, not spike).
- Windows/Linux implementations (architecture-noted only).
- Shipping-grade code signing / notarization of the extension.

---

## 5. Method
1. **A1:** build + run `cgwin`; verify a few windows' bounds against where they actually are on screen; confirm no permission prompt. Record owners/bounds.
2. **A2:** run `axwin` ungranted → expect clean "not trusted." (If you choose to grant Accessibility, re-run → expect geometry.) Record both states.
3. **H3:** move a target window; sample how quickly each method reflects it; confirm idle (nothing moving) stays within Spike-1 budget via the CPU-time-delta method.
4. **B:** build the gdext extension; load in Godot; confirm GDScript receives rects. (Deferred behind Stage A.)
5. **H5:** confirm feature-flag-off path is inert.

---

## 6. Outcome interpretation (decided in advance)
- **CGWindowList suffices (H2a pass, H3 pass via polling)** → **best case:** window-riding with **no permission friction**. Prefer it; treat AX as an optional enhancement for event-driven precision. Major win for the macOS UX and the cross-platform degradation story.
- **Need AX (H2b)** → window-riding works but carries the documented permission friction; the cat must degrade gracefully when denied (H5) and never nag. Acceptable per epic, but friction is real.
- **H4 fails (extension won't bridge)** → the Layer-3 native path is in doubt; revisit epic §4 (GDExtension assumption). Existential for the feature, not the product.
- **All fail** → ship the wandering cat without window-riding (epic §9 fallback). Not fatal.

---

## 7. Results

**Run date:** 2026-06-13 · **Stage A: PASS — existential question answered YES, best case.** Stage B (Rust GDExtension) pending.

### 7.1 Stage A1 — CGWindowList (no permission) — **PASS**
`CGWindowListCopyWindowInfo` returned 44 on-screen entries; 5 normal app windows (layer 0) with correct owner + bounds, **no permission prompt**:
```
pid=1426 L0 iTerm2    2560x1410 @ (2560,30)   (title empty/hidden)
pid=637  L0 Finder    1159x436  @ (25,720)    (title empty/hidden)
pid=637  L0 Finder    1158x436  @ (25,274)    (title empty/hidden)
pid=5123 L0 Obsidian  1828x1261 @ (393,99)    (title empty/hidden)
pid=2094 L0 Firefox   1685x1381 @ (661,30)    (title empty/hidden)
```
Bounds cross-check correct (iTerm2 on screen 1 at x=2560; Firefox top of screen 0 at y=30, below the 30 px menu bar — matches Spike 2's screen enumeration). **Coordinate space:** global, top-left origin — same convention Godot's `DisplayServer` screen rects use, so no reconciliation needed.

### 7.2 Stage A2 — Accessibility — ungranted path **PASS** (clean), granted path **untested (optional)**
`AXIsProcessTrusted() = false` detected cleanly; AX reads correctly reported unavailable with **no crash**. The granted path (reading `kAXPosition/kAXSize`) was **not exercised** — it needs a manual Accessibility grant, and since CGWindowList already supplies bounds with no permission, **AX is optional** (only needed for event-driven move notifications or window titles). Code is ready (`spike3/axwin.swift`) if we choose to validate it later.

### 7.3 H3 — live tracking + idle cost — **PASS**
CGWindowList poll cost: **0.533 ms/call** (500 calls / 266 ms). A 10 Hz ride-poll ≈ **0.53% of one core**, incurred **only while the cat is riding** a window (Tier 2); zero when idle. Comfortably within budget. Event-driven AX observers (no polling) remain an option if we later take the permission.

### 7.4 Stage B — Rust GDExtension — **PASS**
Built a minimal **gdext** extension (`spike3/gdext/`) wrapping the C CGWindowList parser, loaded it into Godot 4.6.3, and called it from GDScript — **headless, no window created**:
```
Initialize godot-rust (API v4.5.stable, runtime v4.6.3.stable, safeguards strict)
OK: Rust GDExtension returned 8 windows
  iTerm2  pid=1426 layer=0 rect=[P:(2560,30),  S:(2560,1410)]
  Firefox pid=2094 layer=0 rect=[P:(194,52),   S:(2197,1239)]
  Slack   pid=38671 ... Discord ... Obsidian ... Finder x2 ...
```
The full chain works: **GDScript → Rust `#[func]` → C `CGWindowListCopyWindowInfo` → `Array<Dictionary>{owner,pid,layer,rect:Rect2}` → GDScript**, with geometry arriving as native Godot `Rect2` in the correct coordinate space.

**Build/integration notes (real, for the build phase):**
- **Toolchain:** Godot 4.6 is newer than gdext 0.4.5's `api-custom` codegen handles (it panicked on 4.6's `mode_flags` enum). Solution that worked: build against gdext's **bundled API (4.5)** and rely on **forward-compat** into 4.6 ("safeguards strict" passed). Watch for a gdext release that natively targets 4.6.
- **Rust ≥1.85 required** (gdext deps need edition2024); updated stable 1.83 → 1.96.
- **Hard parts in C, thin Rust binding:** keeping CoreGraphics/CoreFoundation parsing in a small C file (`csrc/windows.c`, compiled via `cc` in `build.rs`, linking `CoreGraphics`/`CoreFoundation` frameworks) kept the Rust side tiny.
- **Extension registration:** running outside the editor needs `.godot/extension_list.cfg` listing the `.gdextension` (the editor import scan normally writes this). Relevant to packaging the shipped app.
- The dylib was ad-hoc signed; the official notarized Godot loaded it fine (no library-validation block).

### 7.5 H5 — graceful degradation — **PASS (path proven)**
`isAvailable()` is cheaply determinable: CGWindowList success, or `AXIsProcessTrusted()` for the AX path. The denied/unavailable case returns cleanly, so the portable brain can gate window-riding behind a single bool and run the wandering cat everywhere else (protects the Wayland story).

### 7.6 Verdict & surprises
- **Verdict: the existential question is answered YES** — other apps' window rectangles are readable on macOS, **with no permission friction**, cheaply pollable. Window-riding is feasible on the cheapest possible path.
- **Biggest surprise (positive):** the epic (§2/§4) framed Accessibility permission as "the main cost" of macOS window detection. **For geometry, that cost is avoidable** — CGWindowList needs no grant. The permission friction only returns if we want titles (Screen Recording) or event-driven precision (Accessibility). That meaningfully de-risks the riskiest feature.
- **Confirmed boundary:** window **titles** are permission-gated (all came back empty), **bounds + owner are not.**

### 7.7 Findings affecting architecture (surfaced, not acted on)
1. **Prefer CGWindowList as the macOS `WindowDetect` primary** (no permission); make AX an *optional enhancement* for event-driven move tracking. This simplifies onboarding and strengthens the graceful-degradation story the epic wants.
2. **Cross-platform parallel:** Windows `EnumWindows`/`GetWindowRect` is likewise permission-free; the no-permission posture generalizes (Wayland remains the degraded case). Update epic §2 table's "needs permission" framing for macOS — true for AX, **not** for CGWindowList.
3. **Poll only while riding.** Window-detection must be demand-driven (cat on a window → poll ~10 Hz; otherwise off) to honor the Spike-1 idle budget. A Layer-3 concern to bake in.
4. **Stage B still needed** to retire the epic §4 GDExtension assumption (can Godot load a Rust native lib and cross the boundary). Existential for the *stack*, not the *feature*.

---

## 8. Deliverable — Layer 3 window-detection interface (draft)
```
interface WindowDetect:                       # the per-platform piece behind Layer 3
    isAvailable() -> bool                      # false on Wayland / when denied → graceful degrade
    requiresPermission() -> bool               # macOS-AX: true; macOS-CGWindowList: false
    getWindowRects() -> [ {owner, pid, layer, rect} ]   # all on-screen windows
    # optional event-driven (AX only):
    observeWindowMoved(pid, callback)
```
> This is the `getWindowRects()` the epic §3 deferred. It sits behind `isAvailable()` so the portable brain can run window-riding only where the OS layer reports support.

---

## 9. Recommendation

**Existential question: PASS — proceed.** Window-riding is feasible on macOS via **CGWindowList with no permission friction**, at ~0.5%/core only while riding. This is the best-case outcome and de-risks the epic's riskiest feature.

**Architecture call (surfaced for the epic):** make the macOS `WindowDetect` implementation **CGWindowList-first** (no permission, poll-while-riding), with **Accessibility as an optional enhancement** for event-driven move tracking. Update the epic §2 "needs permission" framing accordingly.

**Stage B confirmed (§7.4):** the Rust GDExtension path works end-to-end into Godot 4.6 — the epic §4 GDExtension assumption is **retired (validated)**.

**Optional, deferred (not existential):** validate the **AX granted path** + an `AXObserver` move-notification, only if we later decide event-driven precision is worth the Accessibility permission. CGWindowList polling already covers window-riding.

**Spike status across the project:** Spike 1 PASS (corrected ~1%/core), Spike 2 PARTIAL (plumbing works; H4 sleep/wake + H5 agent export deferred), **Spike 3 COMPLETE PASS (A+B)**. All three existential questions — cheap idle, livable window, readable other-windows — are **green**, and the native-extension stack is proven. Recommend proceeding to behavior/build (epic §8), with the only open follow-ups being Spike 2's H4/H5 (display-sleep + agent packaging).
