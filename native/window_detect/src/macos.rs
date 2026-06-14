//! macOS backend — reads window geometry via CGWindowList through the C bridge in
//! `csrc/macos_windows.c`. Permission-free: only window *titles* are gated (Screen
//! Recording), and window-riding needs only bounds.

use crate::provider::WindowInfo;
use std::ffi::CStr;
use std::os::raw::c_char;

extern "C" {
    fn window_detect_macos_csv() -> *mut c_char;
    fn window_detect_macos_free(p: *mut c_char);
}

pub fn is_available() -> bool {
    true
}

pub fn requires_permission() -> bool {
    false
}

pub fn window_rects() -> Vec<WindowInfo> {
    // The C side allocates the CSV; we own it and must free it.
    let csv = unsafe {
        let ptr = window_detect_macos_csv();
        if ptr.is_null() {
            return Vec::new();
        }
        let s = CStr::from_ptr(ptr).to_string_lossy().into_owned();
        window_detect_macos_free(ptr);
        s
    };

    let mut out = Vec::new();
    for line in csv.lines() {
        let f: Vec<&str> = line.split(',').collect();
        if f.len() != 7 {
            continue;
        }
        out.push(WindowInfo {
            owner: f[0].to_string(),
            pid: f[1].parse().unwrap_or(-1),
            layer: f[2].parse().unwrap_or(0),
            x: f[3].parse().unwrap_or(0.0),
            y: f[4].parse().unwrap_or(0.0),
            width: f[5].parse().unwrap_or(0.0),
            height: f[6].parse().unwrap_or(0.0),
        });
    }
    out
}
