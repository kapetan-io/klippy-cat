//! Layer 3 — OS Integration: the `WindowDetect` Godot class.
//!
//! Exposes other applications' on-screen window rectangles to the portable cat brain so it
//! can sit on / ride / fall off windows. Platform specifics live in `provider` (+ a per-OS
//! backend); this file is the only part that knows about Godot.
//!
//! Gate window-riding behavior behind [`WindowDetect::is_available`] so the cat degrades
//! gracefully where detection is unsupported or denied.

mod provider;

#[cfg(target_os = "macos")]
mod macos;

use godot::prelude::*;
use provider::WindowInfo;

struct WindowDetectExtension;

#[gdextension]
unsafe impl ExtensionLibrary for WindowDetectExtension {}

#[derive(GodotClass)]
#[class(base=RefCounted)]
struct WindowDetect {
    base: Base<RefCounted>,
}

#[godot_api]
impl IRefCounted for WindowDetect {
    fn init(base: Base<RefCounted>) -> Self {
        Self { base }
    }
}

#[godot_api]
impl WindowDetect {
    /// True when other-window detection works on this platform/runtime.
    #[func]
    fn is_available(&self) -> bool {
        provider::is_available()
    }

    /// True when the active backend needs an OS permission grant.
    /// macOS (CGWindowList) returns `false`.
    #[func]
    fn requires_permission(&self) -> bool {
        provider::requires_permission()
    }

    /// Every on-screen application window as
    /// `{ owner: String, pid: int, layer: int, rect: Rect2 }`.
    ///
    /// Coordinates are global, top-left origin — the same space as Godot's
    /// `DisplayServer` screen rects, so no conversion is needed.
    #[func]
    fn get_window_rects(&self) -> Array<VarDictionary> {
        provider::window_rects().iter().map(to_dict).collect()
    }

    /// Like [`Self::get_window_rects`] but omits windows owned by `exclude_pid` —
    /// pass the cat's own pid (`OS.get_process_id()`) so it never tries to ride itself.
    #[func]
    fn get_window_rects_excluding(&self, exclude_pid: i64) -> Array<VarDictionary> {
        provider::window_rects()
            .iter()
            .filter(|w| w.pid != exclude_pid)
            .map(to_dict)
            .collect()
    }
}

fn to_dict(w: &WindowInfo) -> VarDictionary {
    let mut d = VarDictionary::new();
    d.set("owner", w.owner.clone());
    d.set("pid", w.pid);
    d.set("layer", w.layer);
    d.set(
        "rect",
        Rect2::new(Vector2::new(w.x, w.y), Vector2::new(w.width, w.height)),
    );
    d
}
