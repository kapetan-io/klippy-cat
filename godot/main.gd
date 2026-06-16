extends Node2D

## Root: owns the cat window and runs the two decoupled loops (epic §5.2).
##   - Heartbeat Timer → think()  : slow, always on, cheap. Polls cursor, sleeps / wakes-to-watch.
##   - _process()       → move()  : per-frame, switched ON only while carried/landing (tier 2),
##                                  switched OFF the moment the cat settles → engine idles.
##
## Pick-up/drop is OS input: a left-click on the cat body (the window's passthrough polygon)
## grabs it; releasing the button drops it onto a nearby window edge or where it was let go.
##
## The window is the cat: a 256×256 transparent surface repositioned to the cat's centre,
## so the cat's global position is directly comparable to WindowDetect's window rects.

const HALF := Vector2i(128, 128)   # the 256×256 sprite's centre, window-local
const CARRY_MARGIN := 100.0        # keep the cursor within this of the window centre while
                                   # carried, so the window never slips out from under it and
                                   # the release click is always delivered to us

var brain: CatBrain

@onready var view: CatView = $CatView
@onready var heartbeat: Timer = $Heartbeat

var _self_pid := 0
var _last_pos: Vector2          # previous-frame centre, for the carry-sway velocity
var _debug := false             # opt-in (KLIPPY_LOG=1): log state/pos to user://live.txt
var _ticks := 0

func _ready() -> void:
	Desktop.setup_window(get_window())
	_self_pid = OS.get_process_id()
	brain = CatBrain.new(Desktop.screen_rect())
	_last_pos = brain.pos
	_place()
	view.show_state(brain.state, brain.facing, 0.0, Vector2.ZERO, 0.0)
	heartbeat.timeout.connect(_think)
	_apply_tier(brain.tier())
	set_process(false)             # no carry loop until the cat is grabbed
	_debug = OS.get_environment("KLIPPY_LOG") == "1"
	if _debug:
		var t := FileAccess.open("user://live.txt", FileAccess.WRITE)
		if t:
			t.close()

# --- input: pick up / put down ---
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if brain.state != CatBrain.State.HELD:
			brain.grab()
			set_process(true)
			_apply_tier(brain.tier())

# --- slow decision loop (always running, a few Hz) ---
func _think() -> void:
	brain.think(heartbeat.wait_time, Desktop.cursor_pos())
	view.show_state(brain.state, brain.facing, heartbeat.wait_time, Vector2.ZERO, 0.0)
	_apply_tier(brain.tier())
	if _debug:
		_log()
	if brain.tier() >= 2:
		set_process(true)
	elif brain.tier() == 1:
		_place()                   # watching may have re-faced the cursor

# --- fast carry/landing loop (only while active) ---
func _process(dt: float) -> void:
	var cursor := Desktop.cursor_pos()
	# A held button is released while the cursor is over us; poll for that so we never miss
	# the up-event (the carry clamp below keeps the cursor inside the window).
	if brain.state == CatBrain.State.HELD and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		brain.release(Desktop.nearest_window_landing(brain.pos, _self_pid))

	brain.move(dt, cursor)
	if brain.state == CatBrain.State.HELD:
		_clamp_to_cursor(cursor)

	var vel := (brain.pos - _last_pos) / maxf(dt, 0.0001)
	_last_pos = brain.pos
	view.show_state(brain.state, brain.facing, dt, vel, brain.target_distance())
	_place()
	if brain.tier() < 2:
		set_process(false)         # settled → stop drawing
		_apply_tier(brain.tier())

# Keep the cursor inside the cat window while carried, so the window can't slide out from
# under it (which would strand the cat by swallowing the mouse-release event).
func _clamp_to_cursor(cursor: Vector2) -> void:
	brain.pos.x = clampf(brain.pos.x, cursor.x - CARRY_MARGIN, cursor.x + CARRY_MARGIN)
	brain.pos.y = clampf(brain.pos.y, cursor.y - CARRY_MARGIN, cursor.y + CARRY_MARGIN)

func _place() -> void:
	get_window().position = Vector2i(brain.pos) - HALF

## Sleep deeper the longer nothing happens (epic §5.4): slow the heartbeat and cap fps by tier.
func _apply_tier(t: int) -> void:
	match t:
		0:  # asleep — poll a few times a second so a returning cursor still wakes it
			heartbeat.wait_time = 0.3
			Engine.max_fps = 10
		1:  # watching — lazy cursor poll
			heartbeat.wait_time = 0.1
			Engine.max_fps = 10
		2:  # carried / landing — full animation
			heartbeat.wait_time = 0.1
			Engine.max_fps = 60

func _log() -> void:
	_ticks += 1
	var names := ["SLEEP", "WATCH", "HELD", "LANDING"]
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
