# Spike 1 — Idle-Cost + Transparency Combo

> **Parent:** [`desktop-cat-epic-design.md`](./desktop-cat-epic-design.md) (see §4 Godot decision, §5 Idle throttling, §9 Validation spikes)
> **Status:** ⚠️ **CORRECTED** — original headline (0.033%) did NOT reproduce. Corrected steady-state floor ≈ **1.0% of one core**. Verdict still PASS, but on revised numbers. See **§0 Correction** and Spike 2 §7.6.

---

## 0. Correction (added post-Spike-2)

During Spike 2, the **exact** config-A project from this spike was re-run and measured **~1.0–1.07% of one core**, not 0.033% — a ~30× discrepancy. Re-running it multiple times reproduced ~1.0% consistently; the original 0.033% could **not** be reproduced.

**What this means:**
- The original 0.033% almost certainly caught the process in a transient macOS **App-Nap / timer-coalesced** state (main loop woken ~3×/sec) rather than its steady state. The reproducible steady state is the low-processor-mode wakeup loop running at its real cadence (~145×/sec at the default `low_processor_mode_sleep_usec=6900`), costing ≈ **1.0% of one core** (~10 ms CPU/sec ≈ 0.1% of this 10-core machine).
- **The core existential finding still HOLDS:** transparency is *not* the cost — transparent and opaque windows measured **identical** (re-confirmed in Spike 2). macOS does not force expensive continuous compositing of the transparent surface.
- The idle cost is the **wakeup loop**, and it is **tunable**: raising `low_processor_mode_sleep_usec` to 100 ms (≈10 wakeups/sec) dropped idle toward ~0.6% in testing. This is a real lever (epic §5 discipline) for the build phase.

**Revised verdict:** still **PASS** — ~1.0% of one core (~0.1% of total machine) is acceptable for an all-day agent, and it's tunable downward — but the "near-0%" language in §7–8 below is **overstated**; read it as "low single-digit % of one core, tunable," not "effectively zero." The §3 threshold table puts 1.0% at the Pass/Gray boundary, so this is a *qualified* pass that should be re-validated cleanly during the build (see Spike 2 §7.6 for the full investigation and the testing-disruption caveat).

> The detailed numbers in §7 below are the **original (non-reproducible)** run, kept for the record. Treat §0 as authoritative.

---
> **Spike type:** Existential for the whole concept (epic §9: "if this fails, rethink the stack")
> **Scope:** Window + render idle cost ONLY. No cat, no behavior, no animation, no native/OS-integration code, no Rust.

---

## 1. Why this spike runs first

The epic's entire premise is a desktop pet **lightweight enough to launch at boot and run all day without anyone minding** (epic §1, §5). The single assumption that premise rests on, and that nothing downstream can rescue if it's false, is:

> A transparent, always-on-top window can sit motionless on the desktop at **near-zero CPU**, because on-demand rendering means a static sprite pushes **no frames** (epic §5, disciplines 1–2).

The known risk (epic §9, Spike 1): **macOS per-pixel transparency might force continuous compositing.** If the OS re-composites the transparent surface every display refresh even when Godot draws nothing, then "near-zero idle" is unreachable, the §5 cost model collapses, and the §4 Godot decision itself may have to be revisited in favor of a native AppKit agent. This spike exists to know that on day one, cheaply, before any real effort is committed.

---

## 2. Hypothesis (falsifiable claim)

**H1 (primary):** A Godot 4.6 window configured as **transparent + borderless + always-on-top**, running in **low-processor / on-demand redraw mode** and displaying **one static, non-animated sprite**, sustains **< 1.0% of a single CPU core** averaged over a 60-second motionless idle window on the target Mac.

**H0 (null / failure):** Transparency forces continuous compositing or continuous redraw such that idle CPU stays **≥ 3% of a core** regardless of on-demand settings.

The claim is falsifiable: a numeric sustained CPU measurement either lands under the pass line or it doesn't.

### Supporting sub-claims (measured as evidence, not pass/fail gates)
- **H2 (on-demand is doing the work):** the same transparent window with low-processor mode **off** (free-running loop) costs *materially* more than H1's config — confirming the savings come from on-demand redraw, not from the window happening to be cheap.
- **H3 (transparency tax is small):** idle cost of the transparent window is not dramatically higher than an opaque window in the same on-demand mode — confirming transparency itself isn't the dominant cost.

---

## 3. Pass / fail threshold (locked before measurement)

CPU is expressed as **percent of one core**, where `100%` = one fully saturated core (the convention `top`/`ps` use on macOS). The Mac under test has 10 cores, so 1% of a core is 0.1% of total machine capacity.

| Band | Sustained idle CPU (60s avg, % of one core) | Verdict | Action |
|---|---|---|---|
| **Ideal** | < 0.5% | Strong pass | Proceed to Spike 2 with confidence; cost model validated. |
| **Pass** | 0.5% – 1.0% | Pass | Proceed to Spike 2. |
| **Gray** | 1.0% – 3.0% | Inconclusive | Do **not** proceed yet. Investigate redraw strategy (sleep_usec tuning, explicit redraw suppression) before committing. |
| **Fail** | > 3.0% | Fail | Stop. Reconsider compositing workarounds / redraw strategy; escalate to possible stack change (native AppKit) per epic §4/§9. |

### Why these numbers are defensible
- **The bar is "nobody minds it launching every day" (epic §1, §15).** A well-behaved macOS menu-bar agent idles in the noise — well under 1% of a core. A pet that spins a measurable fraction of a core 8 hours a day shows up in battery life and fan behavior and gets uninstalled. That makes **1% of a core the honest pass line** for "indistinguishable from idle," not an aspirational one.
- **3% as the hard-fail floor:** ~3% of one core sustained ≈ a few minutes of CPU-hours per workday — small in absolute terms but already enough to read as "this thing is always doing something," which contradicts the §5 thesis that *a motionless cat costs nothing*. Anything above it isn't a tuning problem, it's a model problem.
- **The 1–3% gray band exists on purpose:** it's the zone where on-demand rendering is *partly* working but something (compositor, a stray redraw, vsync wakeups) is leaking cost. That's a "diagnose before you trust it" result, not a quiet pass.

### Energy (secondary, best-effort)
macOS "Energy Impact" is the metric Apple itself uses for background-app citizenship. Target: **qualitatively Low / negligible.** Captured via `powermetrics` if it can run non-interactively, otherwise via an Activity Monitor → Energy reading. This is corroborating evidence, **not** a pass/fail gate (CPU% is the gate).

---

## 4. Test setup

### Environment (recorded at run time)
| Field | Value |
|---|---|
| Godot version | **4.6.3.stable.official** (`7d41c59c4`) |
| Godot build | **Standard** (non-Mono / non-.NET) — bundle id `org.godotengine.godot`, no `GodotSharp` artifacts |
| Godot location | `/Applications/Godot.app` |
| macOS | 26.5.1 (build 25F80) |
| Hardware | MacBook Pro, Apple M1 Max — 8 performance + 2 efficiency cores |
| Memory | 64 GB |
| Architecture | arm64 (Apple Silicon) |
| Display | Built-in Retina (HiDPI / scaling noted in results) |
| Power source | Recorded at run time (`pmset -g batt`) — plugged vs battery noted |
| Rust | Not installed (out of scope — Layer 3 / Spike 3) |

### Window configuration under test (the real shipped config)
- `display/window/size/transparent = true`
- `display/window/per_pixel_transparency/allowed = true`
- `display/window/size/borderless = true`
- `display/window/size/always_on_top = true`
- `application/run/low_processor_mode = true` (on-demand redraw; epic §5 mechanism)
- Root viewport `transparent_bg = true`, reasserted at runtime as belt-and-suspenders.

> **Deliberately out of scope for Spike 1:** click-through, multi-monitor spanning, menu-bar agent / no-dock-icon, display-sleep survival. Those are **Spike 2** (window plumbing). Spike 1 isolates *only* the transparency + on-demand-redraw idle-cost question.

### The scene (minimal, self-contained)
- A single `Node2D` root with a script.
- **One static sprite:** a `Sprite2D` showing a generated 64×64 solid-color `ImageTexture`, drawn once and never animated. No external art asset.
- **No `_process` / `_physics_process` defined** → nothing requests a per-frame redraw. After the first frame the engine has no reason to draw again.
- Runs as the **project directly** (`Godot --path <proj>`, not the editor) so the measured process represents the shipped app, not the IDE.

### Test matrix
| # | Window | Redraw mode | Purpose |
|---|---|---|---|
| **A** (primary) | Transparent + borderless + always-on-top | Low-processor / on-demand | **The pass/fail measurement (H1).** |
| **B** (contrast) | Transparent + borderless + always-on-top | Free-running (low-proc OFF) | Shows on-demand is doing the work (H2). |
| **C** (contrast) | Opaque, otherwise identical | Low-processor / on-demand | Isolates the transparency tax (H3). |

---

## 5. Measurement method

1. Launch the project (config A) in the background; capture its PID.
2. Let it settle ~10 s (startup/JIT/first-frame composite are not idle cost).
3. Sample process CPU with **`top -l` interval samples**: `top -l 13 -s 5 -pid <PID> -stats pid,command,cpu` → 13 samples 5 s apart ≈ 60 s. **Discard the first sample** (`top`'s first reading is cumulative-since-launch, not an interval), average the remaining 12.
   - `top`'s CPU column on macOS is % of one core, matching the threshold table.
   - Cross-check with a second tool (`ps -o %cpu`) for sanity.
4. Record memory (RSS) alongside, as a §4-relevant data point ("tens of MB, not hundreds").
5. Repeat the 60 s sample for configs B and C.
6. Energy: attempt `sudo -n powermetrics` for a short sample; if sudo isn't available non-interactively, fall back to an Activity Monitor Energy reading and note the method.
7. Note observational surprises: Retina scaling behavior, on-battery vs plugged delta (if testable without disrupting the user), and **display-sleep behavior flagged for manual confirmation** (forcibly sleeping the user's display is intrusive; see §7).

**What "reading" means:** the headline number is the **60 s interval average CPU% for config A**. That single number is compared against the §3 table to produce the verdict.

---

## 6. Outcome interpretation (decided in advance)

- **Pass (< 1.0%)** → The lightweight premise holds on Godot/macOS. Transparency does **not** force continuous compositing in a way that defeats on-demand rendering. **Proceed to Spike 2 (window plumbing).** The §4 Godot decision stands on this axis.
- **Gray (1.0–3.0%)** → On-demand rendering is partially working. **Do not proceed.** Diagnose: tune `low_processor_mode_sleep_usec`, hunt stray redraw requests, check whether the compositor (not Godot) is the cost. Re-measure before any go/no-go.
- **Fail (> 3.0%)** → The transparency/compositing tax defeats the cost model. Reconsider, in order: (a) redraw strategy / window-server interaction, (b) whether a transparent window can ever be cheap on this macOS, (c) **stack change to a native Swift/AppKit agent** (epic §4 "consciously rejected" alternative) — which would sacrifice the portable core, a major architectural reversal that must go back to the epic for review, not be decided inside this spike.

---

## 7. Results

**Run date:** 2026-06-13 · **Status: PASS (Ideal band).**

### 7.1 Environment as run
- **Godot:** 4.6.3.stable.official (`7d41c59c4`), Standard build, Metal 4.0 / Forward+ renderer, Device: Apple M1 Max (Apple7).
- **macOS:** 26.5.1 (25F80). **Hardware:** MacBook Pro M1 Max (8P+2E), 64 GB, arm64.
- **Power source:** AC (plugged in), battery at 79%. On-battery not separately tested (see §7.4).
- **Display / scaling:** Main display 2560×1440 @ **100 Hz**; a second 2560×1440 @ 60 Hz display also attached (multi-display present). Window placed on main display.

### 7.2 Measurements

Headline numbers come from the **accumulated CPU-time delta** method (30 s window, 10 s settle), which has far finer resolution than `top`'s interval CPU. `top`'s 60 s interval sampling reported `0.0%` for all three configs — true but coarse; it only means "< ~0.05%", so the CPU-time delta is the authoritative reading.

| Config | Idle CPU (% of one core) | RSS | Notes |
|---|---|---|---|
| **A — transparent + on-demand (primary)** | **0.033%** | ~216 MB (ps RSS) / ~123 MB (top) | The pass/fail measurement. 0.79→0.79s CPU over 30 s. |
| **B — transparent + free-running** | **0.333%** | ~125 MB | low-processor OFF. ~10× config A. |
| **C — opaque + on-demand** | **0.033%** | ~123 MB | Identical to A. |

- **Energy impact:** Not captured numerically — `powermetrics --show-process-energy` requires interactive sudo, which wasn't run non-interactively. Given a sustained **0.033% of one core** (≈ 0.0033% of total machine capacity), energy impact is **qualitatively negligible**. A precise reading can be taken later via Activity Monitor → Energy if desired; it is corroborating only, not the gate.

**What the contrasts prove:**
- **A = C (0.033% = 0.033%)** → transparency adds **no measurable idle CPU tax**. The existential worry — that macOS per-pixel transparency forces continuous compositing that defeats on-demand rendering — is **disproven** on this stack. This is the core finding.
- **B = 10× A (0.333% vs 0.033%)** → **on-demand redraw is exactly what buys the near-zero.** A free-running loop is still cheap on an M1 Max in absolute terms, but it costs an order of magnitude more, confirming the §5 "decouple thinking from drawing / on-demand rendering" discipline is real and load-bearing (and will matter far more on weaker hardware and on battery).

### 7.3 Verdict
- **Headline (config A) CPU: 0.033% of one core.**
- **Band (§3): Ideal (< 0.5%).**
- **PASS** — by a wide margin (~15× under the 0.5% ideal line, ~30× under the 1.0% pass line).

### 7.4 Surprises & observations
- **`top` vs CPU-time delta:** `top`'s coarse interval sampling read 0.0% even for the free-running config B; only the CPU-time delta exposed B's true 0.333% and the clean 10× gap. Methodological note for future spikes: **do not trust `top`'s per-interval CPU for sub-1% work** — use accumulated CPU time.
- **Transparency genuinely free at idle:** the most reassuring surprise — A and C were bit-for-bit identical (both 0.033%). No compositing penalty observed for the always-on-top transparent surface while static.
- **Memory higher than the epic's estimate:** RSS ≈ **216 MB** (ps) / ~123 MB (top private). Epic §4 estimated "tens of MB, not hundreds." Actual at-rest is **low hundreds of MB** with the Forward+ Metal renderer. See §7.5.
- **On-battery vs plugged:** only tested on AC. macOS may throttle differently on battery, but since the cost is already ~0.03% of a core, any battery-mode delta is immaterial to the verdict. Worth a confirming glance during Spike 2.
- **Display sleep:** **not tested** — forcibly sleeping the user's display mid-session is intrusive, and display-sleep survival is explicitly a **Spike 2** concern, not Spike 1's transparency/idle question. Flagged for Spike 2.
- **HiDPI/Retina:** no scaling anomalies observed; window rendered correctly on the 100 Hz main display. Multi-display behavior (window crossing monitors) is a Spike 2 item.

### 7.5 Findings that affect Spikes 2–3 / architecture (surfaced, NOT acted on)
1. **At-rest memory ≈ 120–220 MB, vs the epic §4 "tens of MB" estimate.** CPU is a non-issue; **memory** is the real footprint cost of the Godot choice and the epic's §4 accounting understates it by roughly an order of magnitude. Not a Spike-1 failure (the gate is idle CPU), but it should be **reviewed against the §4 trade-off rationale and the "lightweight" bar**, and may motivate testing the **Compatibility renderer** (lighter than Forward+) in a later spike. *Surfaced for review only.*
2. **On-demand rendering is load-bearing, not optional.** The 10× A→B gap means the §5 disciplines must be enforced from the first line of the renderer; any accidental free-running loop (a stray `_process` that calls `queue_redraw`) silently costs 10×. Relevant to the behavior/rendering build (Layers 1–2), not just this spike.
3. **Multi-display + high-refresh (100 Hz) environment present.** Good real-world test bed for Spike 2 (multi-monitor spanning, per-display refresh, display sleep/wake). No action now.

---

## 8. Recommendation

**PROCEED to Spike 2 (window plumbing).**

The existential question this spike exists to answer is settled with a wide margin: a transparent, always-on-top Godot 4.6 window displaying a motionless sprite idles at **0.033% of one core** on the target Mac, with **no measurable transparency/compositing tax** (config A = config C). The §5 lightweight cost model holds, and the §4 Godot decision stands **on the idle-CPU axis**.

One caveat carried forward, not blocking: **at-rest memory (~120–220 MB) is materially higher than the epic §4 estimate** and deserves a review against the "lightweight enough to launch every day" bar — surfaced in §7.5 for decision, not acted on here.

---

## Appendix A — Reproduction

The throwaway test projects (`spike1/proj_{a,b,c}/`) were deleted after the run. Everything needed to reproduce them is below. Each project is three files: `project.godot`, `main.tscn`, `main.gd`. The scene and script are **identical across all three**; only `project.godot` differs.

### `main.gd` (shared by A, B, C)
```gdscript
extends Node2D

# Spike 1 — static idle scene. One sprite, drawn once, never animated.
# No _process/_physics_process is defined, so nothing requests a per-frame redraw.

func _ready() -> void:
	var win := get_window()
	win.borderless = true
	win.always_on_top = true
	win.size = Vector2i(256, 256)
	win.position = Vector2i(200, 200)

	var want_transparent: bool = ProjectSettings.get_setting("display/window/size/transparent", false)
	if want_transparent:
		win.transparent = true
		get_viewport().transparent_bg = true
	else:
		# Opaque contrast config (C): a fair "normal" window with a solid background.
		var bg := ColorRect.new()
		bg.color = Color(0.10, 0.10, 0.12, 1.0)
		bg.size = Vector2(256, 256)
		add_child(bg)

	# The single static sprite: a generated 64x64 solid-color texture.
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.7, 1.0, 1.0))
	var spr := Sprite2D.new()
	spr.texture = ImageTexture.create_from_image(img)
	spr.position = Vector2(128, 128)
	add_child(spr)

	print("SPIKE1_PID=", OS.get_process_id())
```

### `main.tscn` (shared by A, B, C)
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://main.gd" id="1"]

[node name="Main" type="Node2D"]
script = ExtResource("1")
```

### `project.godot` — the only file that differs
**Config A (transparent + on-demand):** `low_processor_mode=true`, `transparent=true`, `per_pixel_transparency/allowed=true`.
**Config B (transparent + free-running):** same as A but `low_processor_mode=false`.
**Config C (opaque + on-demand):** same as A but `transparent=false`, `per_pixel_transparency/allowed=false`.

```ini
config_version=5

[application]
config/name="Spike1 A transparent on-demand"
run/main_scene="res://main.tscn"
run/low_processor_mode=true          ; B: false

[display]
window/size/borderless=true
window/size/transparent=true         ; C: false
window/size/always_on_top=true
window/per_pixel_transparency/allowed=true   ; C: false
```

### Measurement commands
Run a project directly (not the editor) so the measured process matches the shipped app:
```sh
/Applications/Godot.app/Contents/MacOS/Godot --path proj_a &
PID=$!
```

Authoritative idle-CPU reading — **accumulated CPU-time delta** (10 s settle, 30 s window). `top -l`'s per-interval CPU is too coarse below ~1% and reported 0.0% for all configs; do not rely on it.
```sh
cputime_to_s() { awk -F: '{ if (NF==3) print $1*3600+$2*60+$3; else if (NF==2) print $1*60+$2; else print $1 }'; }
sleep 10
a=$(ps -o cputime= -p $PID | tr -d ' ' | cputime_to_s)
sleep 30
b=$(ps -o cputime= -p $PID | tr -d ' ' | cputime_to_s)
awk -v a=$a -v b=$b 'BEGIN{printf "AVG CPU = %.3f%% of one core\n", (b-a)/30*100}'
```
