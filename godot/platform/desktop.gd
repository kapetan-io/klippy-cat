class_name Desktop
extends RefCounted

## Layer 3 (thin) — the cat's OWN window + cursor, the parts Godot handles natively
## (proven in spikes 1 & 2). Reading OTHER apps' windows is the native WindowDetect module
## (native/window_detect). Kept behind this wrapper so the brain/view stay OS-agnostic.

## Make a window an unobtrusive desktop-pet surface: borderless, always-on-top,
## transparent, click-through, never stealing focus.
static func setup_window(win: Window) -> void:
	win.borderless = true
	win.always_on_top = true
	win.transparent = true
	win.unfocusable = true
	win.set_flag(Window.FLAG_NO_FOCUS, true)
	win.set_flag(Window.FLAG_MOUSE_PASSTHROUGH, true)  # TODO: swap for a cat-body polygon so it's pettable
	win.gui_disable_input = true

## Global cursor position (lazy-polled by the brain's think tick — epic §5.3).
static func cursor_pos() -> Vector2:
	return DisplayServer.mouse_get_position()

## Usable area of the screen the cat window is currently on (excludes menu bar/dock).
static func screen_rect() -> Rect2:
	var i := DisplayServer.window_get_current_screen()
	return DisplayServer.screen_get_usable_rect(i)
