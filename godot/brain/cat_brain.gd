class_name CatBrain
extends RefCounted

## Layer 1 — portable cat behavior. Knows nothing about windows, rendering, or the OS:
## it consumes a cursor position and produces a state + a position to render.
##
## Two ticks, deliberately decoupled (epic §5.2 "decouple thinking from drawing"):
##   [method think]  — slow decision tick (a few Hz). Chooses the state. Cheap; always runs.
##   [method move]   — fast integration tick. Only meaningful in active states (tier 2).
##
## Escalating dormancy (epic §5.4): the longer nothing happens, the deeper it sleeps.

enum State { DORMANT, IDLE, WATCH, WANDER }

# --- tunables (later: a CatConfig resource) ---
const WAKE_RADIUS := 220.0      ## cursor within this of the cat → wake and watch
const APPROACH_RADIUS := 90.0   ## cursor this close → walk toward it
const SPEED := 280.0            ## px/s while walking
const SLEEP_AFTER := 120.0      ## idle seconds → deep sleep (tier 0 dormant)
const WANDER_CHANCE := 0.15     ## per-second odds of a spontaneous wander when idle
const ARRIVE_EPS := 1.0         ## px: close enough to a target to stop

var state: State = State.IDLE
var pos: Vector2                ## cat centre, in global screen coordinates
var facing := 1                 ## +1 right, -1 left
var idle_time := 0.0            ## seconds since the cat last had something to do

var _target: Vector2
var _bounds: Rect2
var _rng := RandomNumberGenerator.new()

func _init(bounds: Rect2, rng_seed: int = 0) -> void:
	_bounds = bounds
	pos = bounds.get_center()
	_target = pos
	if rng_seed != 0:
		_rng.seed = rng_seed

## Activity tier (epic §5): 0 dormant, 1 watching, 2 active. Drives the render cadence.
func tier() -> int:
	match state:
		State.DORMANT: return 0
		State.WANDER: return 2
		_: return 1

## Decision tick. `cursor` is the global cursor position. Returns true if the state changed.
func think(dt: float, cursor: Vector2) -> bool:
	var prev := state
	var d := pos.distance_to(cursor)

	if d <= WAKE_RADIUS:
		idle_time = 0.0
		if d <= APPROACH_RADIUS:
			_target = cursor
			state = State.WANDER        # walk toward the cursor
		else:
			_face_toward(cursor)
			state = State.WATCH         # track it with eyes/head
	else:
		idle_time += dt
		match state:
			State.WATCH:
				state = State.IDLE
			State.WANDER:
				pass                     # let move() finish the current walk
			State.IDLE:
				if idle_time >= SLEEP_AFTER:
					state = State.DORMANT
				elif _rng.randf() < WANDER_CHANCE * dt:
					_target = _random_point()
					state = State.WANDER
			State.DORMANT:
				pass                     # sleeps until the cursor approaches (handled above)

	return state != prev

## Integration tick — moves the cat. Only does work in WANDER (tier 2).
func move(dt: float) -> void:
	if state != State.WANDER:
		return
	_face_toward(_target)
	pos = pos.move_toward(_target, SPEED * dt)
	if pos.distance_to(_target) <= ARRIVE_EPS:
		state = State.IDLE
		idle_time = 0.0

func _face_toward(p: Vector2) -> void:
	if absf(p.x - pos.x) > 4.0:
		facing = 1 if p.x > pos.x else -1

func _random_point() -> Vector2:
	return Vector2(
		_rng.randf_range(_bounds.position.x, _bounds.end.x),
		_rng.randf_range(_bounds.position.y, _bounds.end.y))
