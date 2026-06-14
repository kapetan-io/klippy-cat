# WindowDetect — Layer 3 (OS Integration)

Reads **other applications' on-screen window rectangles** and exposes them to the Godot side
(the portable cat brain) as a `WindowDetect` class. This is the native piece behind the
epic's "sit on / ride / fall off other windows" feature.

It is deliberately the only place that knows about a specific OS: platform code lives behind
[`src/provider.rs`](src/provider.rs), so adding Windows/Linux means adding a backend, not
touching the Godot-facing class. Validated by **Spike 3** (see `../../desktop-cat-spike-3-window-detection.md`).

## GDScript API

```gdscript
var wd := WindowDetect.new()

wd.is_available()          # bool — false where unsupported/denied → degrade gracefully
wd.requires_permission()   # bool — macOS (CGWindowList): false

# Array of { owner: String, pid: int, layer: int, rect: Rect2 }
# rect is global, top-left origin — same space as DisplayServer screen rects.
for w in wd.get_window_rects():
    print(w["owner"], w["rect"])

# Same, minus the cat's own windows (so it never rides itself):
wd.get_window_rects_excluding(OS.get_process_id())
```

Always gate window-riding behind `is_available()` so the cat just wanders where detection
isn't possible (e.g. Wayland).

## Platform status

| Platform | Backend | Permission | Status |
|---|---|---|---|
| macOS | CGWindowList (`csrc/macos_windows.c`) | **none** (titles would need Screen Recording; we use only bounds) | ✅ implemented |
| Windows | `EnumWindows`/`GetWindowRect` | none | ⬜ stub (returns unavailable) |
| Linux/X11 | `_NET_CLIENT_LIST` + geometry | none | ⬜ stub |
| Linux/Wayland | — | n/a | ⬜ unsupported → `is_available()=false` |

Unimplemented platforms compile to a stub that reports `is_available()=false` and returns
no windows — the graceful-degradation path.

## Build & deploy

```sh
cargo build                 # debug → target/debug/libwindow_detect.dylib
# cargo build --release      # release → target/release/libwindow_detect.dylib

# Deploy into a Godot project next to its .gdextension and ad-hoc sign:
cp target/debug/libwindow_detect.dylib demo/window_detect.dylib
codesign -s - -f demo/window_detect.dylib
```

Run the headless smoke test (exercises the whole API, **creates no window**):

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path demo
```

## Toolchain notes (learned in Spike 3)

- **Rust ≥ 1.85** required (gdext deps use edition2024).
- **gdext 0.4.5 + Godot 4.6:** building with the `api-custom` feature against 4.6 panics in
  gdext's codegen (4.6's `mode_flags` enum). This crate instead builds against gdext's
  **bundled API** and loads into 4.6 via **forward-compat** ("safeguards strict" passes).
  Revisit when a gdext release natively targets 4.6.
- **Extension discovery:** Godot normally writes `.godot/extension_list.cfg` during an editor
  import scan. To load the extension when running a project directly (no editor pass), that
  file must list the `.gdextension` — see [`demo/.godot/extension_list.cfg`](demo/.godot/extension_list.cfg).
- The official notarized Godot loads the ad-hoc-signed dylib without a library-validation block.

## Layout

```
window_detect/
├── Cargo.toml          godot = "0.4", cc build-dep
├── build.rs            compiles the C bridge, links CoreGraphics/CoreFoundation (macOS)
├── csrc/
│   └── macos_windows.c CGWindowList → CSV
├── src/
│   ├── lib.rs          WindowDetect Godot class (the only Godot-aware file)
│   ├── provider.rs     platform-agnostic surface + non-macOS stub
│   └── macos.rs        macOS backend (FFI to the C bridge)
└── demo/               minimal Godot project: headless smoke test
```
