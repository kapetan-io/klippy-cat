// Compiles the per-platform native bridge and links the OS frameworks it needs.
// Only macOS is implemented today; other targets fall back to the stub in `provider`.
fn main() {
    #[cfg(target_os = "macos")]
    {
        cc::Build::new()
            .file("csrc/macos_windows.c")
            .compile("window_detect_macos");
        println!("cargo:rustc-link-lib=framework=CoreGraphics");
        println!("cargo:rustc-link-lib=framework=CoreFoundation");
        println!("cargo:rerun-if-changed=csrc/macos_windows.c");
    }
}
