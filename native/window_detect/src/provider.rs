//! Platform-agnostic window-detection surface.
//!
//! The Godot-facing class in `lib.rs` talks only to this module and never knows which OS
//! it is on — that is the epic's "shared brain, swappable boots" boundary. Adding Windows
//! or Linux means adding a backend here, not touching `lib.rs`.

/// One on-screen window owned by some application.
pub struct WindowInfo {
    pub owner: String,
    pub pid: i64,
    pub layer: i64,
    pub x: f32,
    pub y: f32,
    pub width: f32,
    pub height: f32,
}

/// Whether other-window detection works on this platform/runtime at all.
///
/// `false` lets the portable cat brain degrade gracefully — skip window-riding and just
/// wander (e.g. on Wayland, or if a future permission-based backend is denied).
pub fn is_available() -> bool {
    backend::is_available()
}

/// Whether the active backend requires an OS permission grant.
///
/// macOS CGWindowList: `false` (geometry is permission-free). An Accessibility-based
/// backend would return `true`.
pub fn requires_permission() -> bool {
    backend::requires_permission()
}

/// Every on-screen normal application window. Empty when detection is unavailable.
pub fn window_rects() -> Vec<WindowInfo> {
    backend::window_rects()
}

#[cfg(target_os = "macos")]
use crate::macos as backend;

// Fallback for not-yet-implemented platforms: detection simply reports unavailable,
// so window-riding switches itself off and the rest of the cat runs unchanged.
#[cfg(not(target_os = "macos"))]
mod backend {
    use super::WindowInfo;
    pub fn is_available() -> bool {
        false
    }
    pub fn requires_permission() -> bool {
        false
    }
    pub fn window_rects() -> Vec<WindowInfo> {
        Vec::new()
    }
}
