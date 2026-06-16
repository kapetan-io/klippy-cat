class_name Desktop
extends RefCounted

## Layer 3 (thin) — the cat's OWN window + cursor, plus the bridge to the native WindowDetect
## module for *other* apps' windows (used only when the cat is dropped). Kept behind this
## wrapper so the brain/view stay OS-agnostic.

const LAND_RANGE := 200.0   ## px the cat may fall to reach a window edge below it
const FOOT_OFFSET := 79.0   ## px from the cat's centre down to its visible feet (measured from
                            ## the sprite's alpha bounds) — so its feet sit ON the edge, not above

## If grabbing the cat doesn't register on macOS (a borderless no-focus window may not be
## handed mouse events), flip this true: the window will take focus when clicked so the grab
## lands. Trade-off — clicking the cat then briefly steals focus from the app behind it.
const GRAB_STEALS_FOCUS := false

## Make a window an unobtrusive desktop-pet surface: borderless, always-on-top, transparent,
## and — unlike a pure overlay — clickable on the cat body so it can be picked up.
static func setup_window(win: Window) -> void:
	win.borderless = true
	win.always_on_top = true
	win.transparent = true
	win.unfocusable = not GRAB_STEALS_FOCUS
	win.set_flag(Window.FLAG_NO_FOCUS, not GRAB_STEALS_FOCUS)
	# Events inside this polygon hit the cat (so it can be grabbed); the transparent corners
	# fall through to whatever is behind. Replaces the old full FLAG_MOUSE_PASSTHROUGH.
	win.set_flag(Window.FLAG_MOUSE_PASSTHROUGH, false)
	win.mouse_passthrough_polygon = _body_polygon()
	win.gui_disable_input = false

## A generous octagon over the cat body, in window-local pixels (the window is 256×256).
static func _body_polygon() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(64, 24), Vector2(192, 24),
		Vector2(232, 96), Vector2(232, 200),
		Vector2(180, 240), Vector2(76, 240),
		Vector2(24, 200), Vector2(24, 96)])

## Global cursor position (lazy-polled by the brain's think tick — epic §5.3).
static func cursor_pos() -> Vector2:
	return DisplayServer.mouse_get_position()

## Usable area of the screen the cat window is currently on (excludes menu bar/dock).
static func screen_rect() -> Rect2:
	return DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())

## Where the cat should land when dropped at `cat` (its centre). The cat only ever *falls*:
## it lands on the first window top-edge directly below its feet, within LAND_RANGE. Returns
## a Vector2 to settle onto, or null to stay where it was dropped. Degrades to null when the
## native WindowDetect module isn't loaded/available.
static func nearest_window_landing(cat: Vector2, self_pid: int) -> Variant:
	if not ClassDB.class_exists("WindowDetect"):
		return null
	var wd: Object = ClassDB.instantiate("WindowDetect")
	if wd == null or not wd.is_available():
		return null
	return landing_for_rects(cat, wd.get_window_rects_excluding(self_pid))

## Pure geometry (testable without the OS): given the cat centre and a list of window dicts
## ({ "rect": Rect2, ... }), return the feet-on-edge landing point for the highest window top
## edge that sits below the cat's feet within LAND_RANGE and that the cat is over, else null.
static func landing_for_rects(cat: Vector2, rects: Array) -> Variant:
	var feet := cat.y + FOOT_OFFSET
	var best: Variant = null
	var best_top := INF
	for w in rects:
		var r: Rect2 = w["rect"]
		if cat.x < r.position.x or cat.x > r.end.x:
			continue                      # cat isn't over this window
		var top := r.position.y
		if top < feet or top - feet > LAND_RANGE:
			continue                      # edge isn't below the feet, or is too far to fall to
		if top < best_top:                # highest edge below = the first surface it falls onto
			best_top = top
			best = Vector2(cat.x, top - FOOT_OFFSET)
	return best
