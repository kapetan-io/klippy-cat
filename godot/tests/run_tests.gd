extends SceneTree

## Headless Layer-1 tests. Drives CatBrain through scenarios via its public surface
## (think/grab/release/move/state) — no window, no rendering. Run with:
##   Godot --headless --path godot -s res://tests/run_tests.gd

const Brain = preload("res://brain/cat_brain.gd")
const Plat = preload("res://platform/desktop.gd")
const BOUNDS := Rect2(0, 0, 2000, 1200)

var _fail := 0

func _initialize() -> void:
	_test_sleeps_by_default()
	_test_wakes_to_watch_near_cursor()
	_test_returns_to_sleep_when_cursor_leaves()
	_test_grab_carries_and_follows_cursor()
	_test_drop_without_landing_stays_in_place()
	_test_drop_onto_landing_slides_then_sleeps()
	_test_carry_ignores_cursor_proximity()
	_test_watch_faces_cursor()
	_test_lands_only_by_falling_onto_window_below()
	_test_ignores_window_above_too_far_or_not_over()
	_test_falls_onto_the_highest_surface_below()
	if _fail == 0:
		print("OK: all CatBrain tests passed")
	else:
		print("FAIL: %d CatBrain test(s) failed" % _fail)
	quit(_fail)

func check(cond: bool, msg: String) -> void:
	if cond:
		print("  pass: ", msg)
	else:
		_fail += 1
		print("  FAIL: ", msg)

# default state is asleep, and a far cursor keeps it that way
func _test_sleeps_by_default() -> void:
	print("sleeps_by_default")
	var b := Brain.new(BOUNDS)
	check(b.state == Brain.State.SLEEP, "starts SLEEP")
	b.think(0.1, b.pos + Vector2(900, 0))    # far cursor (> WAKE_RADIUS)
	check(b.state == Brain.State.SLEEP, "far cursor → stays SLEEP")
	check(b.tier() == 0, "SLEEP is tier 0")

# cursor within WAKE_RADIUS → wake and watch
func _test_wakes_to_watch_near_cursor() -> void:
	print("wakes_to_watch_near_cursor")
	var b := Brain.new(BOUNDS)
	b.think(0.1, b.pos + Vector2(150, 0))    # 150 < WAKE_RADIUS(220)
	check(b.state == Brain.State.WATCH, "near cursor → WATCH")
	check(b.tier() == 1, "WATCH is tier 1")

# watching, then the cursor walks away → back to sleep
func _test_returns_to_sleep_when_cursor_leaves() -> void:
	print("returns_to_sleep_when_cursor_leaves")
	var b := Brain.new(BOUNDS)
	b.think(0.1, b.pos + Vector2(150, 0))
	check(b.state == Brain.State.WATCH, "near cursor → WATCH")
	b.think(0.1, b.pos + Vector2(900, 0))
	check(b.state == Brain.State.SLEEP, "cursor gone → SLEEP")

# grab → HELD, and move() converges the cat to hang below the cursor
func _test_grab_carries_and_follows_cursor() -> void:
	print("grab_carries_and_follows_cursor")
	var b := Brain.new(BOUNDS)
	b.grab()
	check(b.state == Brain.State.HELD, "grab → HELD")
	check(b.tier() == 2, "HELD is tier 2")
	var cursor := Vector2(500, 400)
	for _i in 200:                            # let the lerp settle on a still cursor
		b.move(0.016, cursor)
	check(b.pos.distance_to(cursor + Vector2(0, Brain.HOLD_OFFSET)) <= 1.0,
		"carried cat hangs HOLD_OFFSET below the cursor")

# drop with no landing point → settles in place, asleep
func _test_drop_without_landing_stays_in_place() -> void:
	print("drop_without_landing_stays_in_place")
	var b := Brain.new(BOUNDS)
	b.grab()
	b.move(0.016, Vector2(800, 600))
	var where := b.pos
	b.release(null)
	check(b.state == Brain.State.SLEEP, "drop (no landing) → SLEEP")
	check(b.pos == where, "stays exactly where dropped")

# drop near a window → LANDING slides onto the edge, then sleeps there
func _test_drop_onto_landing_slides_then_sleeps() -> void:
	print("drop_onto_landing_slides_then_sleeps")
	var b := Brain.new(BOUNDS)
	b.grab()
	b.move(0.016, Vector2(400, 300))
	var edge := b.pos + Vector2(0, 120)       # a window top-edge 120px below the drop
	b.release(edge)
	check(b.state == Brain.State.LANDING, "drop near window → LANDING")
	for _i in 200:
		b.move(0.05, Vector2.ZERO)            # cursor irrelevant while landing
		if b.state == Brain.State.SLEEP:
			break
	check(b.state == Brain.State.SLEEP, "falls to the edge → SLEEP")
	check(b.pos == edge, "settled exactly on the edge (no overshoot)")

# a carry in progress is not yanked out by think()'s proximity check
func _test_carry_ignores_cursor_proximity() -> void:
	print("carry_ignores_cursor_proximity")
	var b := Brain.new(BOUNDS)
	b.grab()
	b.think(0.1, b.pos + Vector2(900, 0))    # far cursor would mean SLEEP if not carried
	check(b.state == Brain.State.HELD, "far cursor during carry → still HELD")

# facing flips with which side the cursor is on while watching
func _test_watch_faces_cursor() -> void:
	print("watch_faces_cursor")
	var b := Brain.new(BOUNDS)
	b.think(0.1, b.pos + Vector2(150, 0))     # cursor to the right
	check(b.facing == 1, "cursor right → facing +1")
	b.think(0.1, b.pos + Vector2(-150, 0))    # cursor to the left
	check(b.facing == -1, "cursor left → facing -1")

func _rect(x: float, y: float, w: float, h: float) -> Dictionary:
	return {"rect": Rect2(x, y, w, h)}

# dropped above a window the cat is over → falls so its feet rest on that top edge
func _test_lands_only_by_falling_onto_window_below() -> void:
	print("lands_only_by_falling_onto_window_below")
	var cat := Vector2(500, 300)               # feet at 300 + FOOT_OFFSET
	var top := cat.y + Plat.FOOT_OFFSET + 70    # a window edge 70px below the feet (within range)
	var landing = Plat.landing_for_rects(cat, [_rect(400, top, 200, 300)])
	check(landing != null, "window below within range → lands")
	check(landing == Vector2(cat.x, top - Plat.FOOT_OFFSET), "feet settle on the edge, x unchanged")

# never flies up to a higher window, never reaches a far one, never lands off to the side
func _test_ignores_window_above_too_far_or_not_over() -> void:
	print("ignores_window_above_too_far_or_not_over")
	var cat := Vector2(500, 300)
	var feet := cat.y + Plat.FOOT_OFFSET
	check(Plat.landing_for_rects(cat, [_rect(400, 100, 200, 50)]) == null,
		"window above the cat → no upward fly")
	check(Plat.landing_for_rects(cat, [_rect(400, feet + Plat.LAND_RANGE + 50, 200, 100)]) == null,
		"window too far below → stays put")
	check(Plat.landing_for_rects(cat, [_rect(0, feet + 40, 100, 100)]) == null,
		"cat not horizontally over the window → no landing")

# stacked windows below → lands on the highest one (the first surface a fall would hit)
func _test_falls_onto_the_highest_surface_below() -> void:
	print("falls_onto_the_highest_surface_below")
	var cat := Vector2(500, 300)
	var near := cat.y + Plat.FOOT_OFFSET + 40
	var far := cat.y + Plat.FOOT_OFFSET + 150
	var landing = Plat.landing_for_rects(cat, [_rect(400, far, 200, 200), _rect(400, near, 200, 100)])
	check(landing == Vector2(cat.x, near - Plat.FOOT_OFFSET), "lands on the nearer (higher) edge")
