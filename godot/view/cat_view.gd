class_name CatView
extends Sprite2D

## Layer 2 — rendering. Today: a single static placeholder sprite (clipi-kat).
## Built to swap to sprite-sheet, frame-based animation per state (epic §7) without the
## brain ever knowing — the brain hands a state + facing, the view decides how to draw it.

## Reflect a brain state. Returns nothing; only touches visuals.
func show_state(_state: int, facing: int) -> void:
	flip_h = facing < 0
	# TODO (build order step 4): pick the sprite-sheet frames for `_state`
	# (idle/walk/sit/sleep/...) and advance them only while in an active tier.
