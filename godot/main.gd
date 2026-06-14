extends Node2D

## Root: owns the cat window and runs the two decoupled loops (epic §5.2).
##   - Heartbeat Timer → think()  : slow, always on, cheap. Polls cursor, picks state.
##   - _process()       → move()  : per-frame, switched ON only for active (tier 2) states,
##                                  switched OFF the moment the cat settles → engine idles.
##
## The window is the cat: a 256×256 transparent surface repositioned to the cat's centre,
## so the cat's global position is directly comparable to WindowDetect's window rects later.

const HALF := Vector2i(128, 128)   # the 256×256 sprite's centre, window-local

var brain: CatBrain

@onready var view: CatView = $CatView
@onready var heartbeat: Timer = $Heartbeat

var _debug := false             # opt-in (CLIPI_LOG=1): log state/pos to user://live.txt
var _ticks := 0

func _ready() -> void:
	Desktop.setup_window(get_window())
	brain = CatBrain.new(Desktop.screen_rect())
	_place()
	view.show_state(brain.state, brain.facing)
	heartbeat.timeout.connect(_think)
	_apply_tier(brain.tier())
	set_process(false)             # no animation loop until a state needs it
	_debug = OS.get_environment("CLIPI_LOG") == "1"
	if _debug:
		var t := FileAccess.open("user://live.txt", FileAccess.WRITE)
		if t:
			t.close()

# --- slow decision loop (always running, a few Hz) ---
func _think() -> void:
	brain.think(heartbeat.wait_time, Desktop.cursor_pos())
	view.show_state(brain.state, brain.facing)
	_apply_tier(brain.tier())
	if _debug:
		_log()
	if brain.tier() >= 2:
		set_process(true)          # spin up the animation/movement loop
	elif brain.tier() == 1:
		_place()                   # watching may have re-faced the cursor

# --- fast animation loop (only while active) ---
func _process(dt: float) -> void:
	brain.move(dt)
	view.show_state(brain.state, brain.facing)
	_place()
	if brain.tier() < 2:
		set_process(false)         # settled → stop drawing
		_apply_tier(brain.tier())

func _place() -> void:
	get_window().position = Vector2i(brain.pos) - HALF

## Sleep deeper the longer nothing happens (epic §5.4): slow the heartbeat and cap fps by tier.
func _apply_tier(t: int) -> void:
	match t:
		0:  # dormant — 1 Hz heartbeat just to notice the cursor returning
			heartbeat.wait_time = 1.0
			Engine.max_fps = 10
		1:  # watching — lazy cursor poll
			heartbeat.wait_time = 0.1
			Engine.max_fps = 10
		2:  # active — full animation
			heartbeat.wait_time = 0.1
			Engine.max_fps = 60

func _log() -> void:
	_ticks += 1
	var names := ["DORMANT", "IDLE", "WATCH", "WANDER"]
	var line := "t=%d state=%s tier=%d pos=(%d,%d) cursor=%s" % [
		_ticks, names[brain.state], brain.tier(),
		int(brain.pos.x), int(brain.pos.y), str(Desktop.cursor_pos())]
	var f := FileAccess.open("user://live.txt", FileAccess.READ_WRITE)
	if not f:
		f = FileAccess.open("user://live.txt", FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_line(line)
		f.close()
