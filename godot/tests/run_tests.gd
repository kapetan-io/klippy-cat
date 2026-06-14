extends SceneTree

## Headless Layer-1 tests. Drives CatBrain through scenarios via its public surface
## (think/move/state) — no window, no rendering. Run with:
##   Godot --headless --path godot -s res://tests/run_tests.gd

const Brain = preload("res://brain/cat_brain.gd")
const BOUNDS := Rect2(0, 0, 2000, 1200)

var _fail := 0

func _initialize() -> void:
	_test_wakes_and_watches_near_cursor()
	_test_approaches_close_cursor()
	_test_idle_escalates_to_dormant()
	_test_wander_reaches_target_then_idles()
	_test_faces_movement_direction()
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

# cursor just inside WAKE_RADIUS but outside APPROACH_RADIUS → WATCH
func _test_wakes_and_watches_near_cursor() -> void:
	print("wakes_and_watches_near_cursor")
	var b := Brain.new(BOUNDS, 1)
	var cursor := b.pos + Vector2(150, 0)   # 150 < WAKE(220), > APPROACH(90)
	b.think(0.1, cursor)
	check(b.state == Brain.State.WATCH, "near cursor → WATCH")
	check(b.tier() == 1, "WATCH is tier 1")

# cursor within APPROACH_RADIUS → WANDER toward it
func _test_approaches_close_cursor() -> void:
	print("approaches_close_cursor")
	var b := Brain.new(BOUNDS, 1)
	var cursor := b.pos + Vector2(40, 0)    # 40 < APPROACH(90)
	b.think(0.1, cursor)
	check(b.state == Brain.State.WANDER, "close cursor → WANDER")
	check(b.tier() == 2, "WANDER is tier 2")

# cursor far for > SLEEP_AFTER → DORMANT
func _test_idle_escalates_to_dormant() -> void:
	print("idle_escalates_to_dormant")
	var b := Brain.new(BOUNDS, 1)
	var far := b.pos + Vector2(900, 0)      # > WAKE_RADIUS
	b.state = Brain.State.IDLE
	b.think(Brain.SLEEP_AFTER + 1.0, far)   # one big idle step crosses the sleep threshold
	check(b.state == Brain.State.DORMANT, "long idle → DORMANT")
	check(b.tier() == 0, "DORMANT is tier 0")

# WANDER integrates toward target, then settles to IDLE
func _test_wander_reaches_target_then_idles() -> void:
	print("wander_reaches_target_then_idles")
	var b := Brain.new(BOUNDS, 1)
	b.state = Brain.State.WANDER
	var target := b.pos + Vector2(100, 0)
	b._target = target
	for _i in 100:                           # 100 * 0.05s @ 280px/s covers 100px
		b.move(0.05)
		if b.state == Brain.State.IDLE:
			break
	check(b.state == Brain.State.IDLE, "reaches target → IDLE")
	check(b.pos.distance_to(target) <= Brain.ARRIVE_EPS, "arrived at target (no overshoot)")

# facing flips with travel direction
func _test_faces_movement_direction() -> void:
	print("faces_movement_direction")
	var b := Brain.new(BOUNDS, 1)
	b.think(0.1, b.pos + Vector2(150, 0))    # cursor to the right
	check(b.facing == 1, "cursor right → facing +1")
	b.think(0.1, b.pos + Vector2(-150, 0))   # cursor to the left
	check(b.facing == -1, "cursor left → facing -1")
