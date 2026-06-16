class_name CatView
extends Sprite2D

## Layer 2 — rendering. One static sprite, animated procedurally (no sprite sheet yet):
## the brain hands a state + facing + carry velocity, the view decides how to draw it.
##   SLEEP    — settled, slightly flattened resting pose (static; the engine idles here).
##   WATCH    — awake and upright, facing the cursor.
##   HELD     — dangles below the cursor and sways against the drag direction (pendulum).
##   LANDING  — falls upright, squashing onto the window edge as it touches down.
## Real per-state sprite-sheet art (breathe / curl / walk) is a later step (epic §7).
##
## Squash pivots at the FEET, not the sprite centre: scaling about the centre would lift the
## feet off whatever the cat is standing on (it'd look like it floats). FEET_FROM_CENTER is the
## visible feet offset measured from the sprite's alpha bounds (matches Desktop.FOOT_OFFSET).

const FEET_FROM_CENTER := 79.0  ## px from the sprite centre down to the visible feet
const SWAY_PER_SPEED := 0.0009  ## rad of tilt per px/s of horizontal carry speed
const SWAY_MAX := 0.6           ## rad clamp on the swing (~34°)
const SWAY_LERP := 9.0          ## how fast the tilt eases toward its target
const SLEEP_SQUASH := Vector2(1.05, 0.9)   ## resting pose — a touch flattened
const LAND_SQUASH := Vector2(1.18, 0.8)    ## maximum squash at the moment of touchdown
const LAND_REACH := 80.0        ## px from the edge where the landing squash begins

var _base_scale: Vector2
var _base_pos: Vector2
var _sway := 0.0

func _ready() -> void:
	_base_scale = scale
	_base_pos = position

## Reflect a brain state. `vel` is the cat's velocity (px/s) — used for the carry sway.
## `to_target` is px remaining to a landing edge (only meaningful while LANDING).
func show_state(state: int, facing: int, dt: float, vel: Vector2, to_target: float) -> void:
	flip_h = facing < 0
	match state:
		CatBrain.State.HELD:
			# Held by the scruff: the body trails the drag, swinging opposite to travel and
			# easing back to hanging straight down when the cursor stops.
			var target := clampf(-vel.x * SWAY_PER_SPEED, -SWAY_MAX, SWAY_MAX)
			_sway = lerp(_sway, target, clampf(SWAY_LERP * dt, 0.0, 1.0))
			rotation = _sway
			_squash(Vector2.ONE)             # in the air — no ground to squash against
		CatBrain.State.LANDING:
			rotation = lerp(rotation, 0.0, clampf(SWAY_LERP * dt, 0.0, 1.0))
			var k := clampf(1.0 - to_target / LAND_REACH, 0.0, 1.0)   # 0 mid-fall → 1 at the edge
			_squash(Vector2.ONE.lerp(LAND_SQUASH, k))
		CatBrain.State.SLEEP:
			rotation = 0.0
			_squash(SLEEP_SQUASH)
		_:  # WATCH — awake and upright
			rotation = 0.0
			_squash(Vector2.ONE)

## Apply a squash factor while keeping the feet planted (scale anchored at the feet, not centre).
func _squash(sq: Vector2) -> void:
	scale = _base_scale * sq
	position = Vector2(_base_pos.x, _base_pos.y + FEET_FROM_CENTER * _base_scale.y * (1.0 - sq.y))
