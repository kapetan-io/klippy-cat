class_name CatBrain
extends RefCounted

## Layer 1 — portable cat behavior. Knows nothing about windows, rendering, or the OS:
## it consumes a cursor position (and, on drop, an optional landing point) and produces a
## state + a position to render.
##
## Movement is deliberately simple: the cat sleeps until you pick it up, follows the cursor
## while carried, and settles where you drop it. The only autonomous behavior left is waking
## to watch a nearby cursor.
##
## Two ticks, decoupled (epic §5.2 "decouple thinking from drawing"):
##   [method think]  — slow decision tick (a few Hz). Sleeps / wakes-to-watch. Cheap; always runs.
##   [method move]   — fast integration tick. Only meaningful while HELD or LANDING (tier 2).
##
## A grab/drop is an external event (the OS layer detects the click) delivered via
## [method grab] / [method release]; proximity never overrides a carry in progress.

enum State { SLEEP, WATCH, HELD, LANDING }

# --- tunables (later: a CatConfig resource) ---
const WAKE_RADIUS := 220.0      ## cursor within this of the cat → wake and watch
const HOLD_OFFSET := 70.0       ## px the cat hangs below the cursor while carried (scruff grip)
const HOLD_LERP := 18.0         ## how fast the cat catches up to the cursor — lower = more dangle lag
const GRAVITY := 2200.0         ## px/s² the cat accelerates at while falling onto a window edge
const FACE_EPS := 4.0           ## px of horizontal travel before flipping facing

var state: State = State.SLEEP
var pos: Vector2                ## cat centre, in global screen coordinates
var facing := 1                 ## +1 right, -1 left

var _target: Vector2
var _bounds: Rect2
var _fall_vel := 0.0            ## current downward speed while LANDING (px/s)

func _init(bounds: Rect2) -> void:
	_bounds = bounds
	pos = bounds.get_center()
	_target = pos

## Activity tier (epic §5): 0 dormant, 1 watching, 2 active. Drives the render cadence.
func tier() -> int:
	match state:
		State.SLEEP: return 0
		State.WATCH: return 1
		_: return 2             # HELD / LANDING animate every frame

## Decision tick. `cursor` is the global cursor position. Returns true if the state changed.
## A carry in progress (HELD/LANDING) is owned by grab/release/move — proximity is ignored.
func think(_dt: float, cursor: Vector2) -> bool:
	if state == State.HELD or state == State.LANDING:
		return false
	var prev := state
	if pos.distance_to(cursor) <= WAKE_RADIUS:
		_face_toward(cursor)
		state = State.WATCH
	else:
		state = State.SLEEP
	return state != prev

## The OS layer saw a grab on the cat body — start carrying it.
func grab() -> void:
	state = State.HELD

## The OS layer saw the drop. `landing` is either a Vector2 to settle onto (a nearby window
## edge the platform found) or null to stay exactly where the cat was let go.
func release(landing: Variant) -> void:
	if landing == null:
		state = State.SLEEP
	else:
		_target = landing
		_fall_vel = 0.0
		state = State.LANDING

## Integration tick — moves the cat. Only does work while HELD or LANDING (tier 2).
func move(dt: float, cursor: Vector2) -> void:
	match state:
		State.HELD:
			# Hang below the cursor by the scruff; the lag makes it swing as you drag.
			pos = pos.lerp(cursor + Vector2(0, HOLD_OFFSET), clampf(HOLD_LERP * dt, 0.0, 1.0))
			_face_toward(cursor)
		State.LANDING:
			# Fall straight down under gravity until the feet meet the edge.
			_fall_vel += GRAVITY * dt
			pos.y += _fall_vel * dt
			if pos.y >= _target.y:
				pos = _target
				_fall_vel = 0.0
				state = State.SLEEP

## Px remaining to the landing edge (only meaningful while LANDING) — lets the view ramp
## the touch-down squash as the cat closes in.
func target_distance() -> float:
	return pos.distance_to(_target)

func _face_toward(p: Vector2) -> void:
	if absf(p.x - pos.x) > FACE_EPS:
		facing = 1 if p.x > pos.x else -1
