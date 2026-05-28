class_name Player
extends Fighter
## A Fighter driven by per-player input actions.
## player_index 0 -> p1_* actions; player_index 1 -> p2_* actions.

const _MOVES := preload("res://assets/movetables/doink.tres")

const _CLOSE_GATE := 50.0   # arcade close-range gate (headbutt vs punch), DOINK.ASM:1921; tune in playtest

@export var player_index: int = 0

## Motion-input state (arcade wrest_joystat). Filled each frame by feed_input().
var motion_buffer := MotionBuffer.new()
var charge := ChargeTracker.new()
var _input_tick := 0
var _prev_stick := 0
var _prev_buttons := 0

func _action_prefix() -> String:
	return "p1_" if player_index == 0 else "p2_"

func get_input_direction() -> Vector2:
	var p: String = _action_prefix()
	return Vector2(
		Input.get_axis(p + "left", p + "right"),
		Input.get_axis(p + "up", p + "down")
	)

func wants_to_run() -> bool:
	return Input.is_action_just_pressed(_action_prefix() + "run")

func wants_to_block() -> bool:
	return Input.is_action_pressed(_action_prefix() + "block")

func _unhandled_input(_event: InputEvent) -> void:
	# While downed, any button/direction press mashes toward a faster getup.
	if mode == Mode.ONGROUND:
		var p := _action_prefix()
		if _pressed(p + "punch") or _pressed(p + "kick") or _pressed(p + "high_punch") \
				or _pressed(p + "high_kick") or _pressed(p + "left") or _pressed(p + "right"):
			mash_recover()
		return
	# Same gate as movement: helpless/blocking fighters can't start a move.
	if not Fighter.input_allowed(mode) or is_attacking():
		return
	var btn := _pressed_button()
	if btn < 0:
		return
	var seq: MoveSequence = _MOVES.lookup(_current_range(), _current_dir(), btn)
	if seq != null:
		start_move(seq)
	elif mode == Mode.RUNNING:
		mode = Mode.NORMAL   # an attack press with no running variant still ends the run

## Which attack button was just pressed, or -1.
func _pressed_button() -> int:
	var p := _action_prefix()
	if _pressed(p + "punch"): return MoveTable.Btn.LOW_PUNCH
	if _pressed(p + "high_punch"): return MoveTable.Btn.HIGH_PUNCH
	if _pressed(p + "kick"): return MoveTable.Btn.LOW_KICK
	if _pressed(p + "high_kick"): return MoveTable.Btn.HIGH_KICK
	return -1

func _current_range() -> int:
	if mode == Mode.RUNNING:
		return MoveTable.Rng.RUNNING
	if target != null and is_instance_valid(target) \
			and global_position.distance_to(target.global_position) <= _CLOSE_GATE:
		return MoveTable.Rng.CLOSE
	return MoveTable.Rng.NORMAL

func _current_dir() -> int:
	var rel := RelativeInput.resolve(get_input_direction(), _facing)
	if rel.down: return MoveTable.Dir.DOWN
	if rel.toward: return MoveTable.Dir.TOWARD
	if rel.away: return MoveTable.Dir.AWAY
	return MoveTable.Dir.NEUTRAL

func _physics_process(delta: float) -> void:
	feed_input(get_input_direction(), _buttons_held_mask(), facing())
	super(delta)

## Fill the motion buffer from this frame's input EDGES (arcade update_joystat).
## stick `dir` is the 8-way direction; `buttons_held` is an OR of MotionBuffer.B_* bits.
func feed_input(dir: Vector2, buttons_held: int, facing: float) -> void:
	_input_tick += 1
	var stick := MotionBuffer.encode_stick(dir, facing)
	if stick != _prev_stick:
		motion_buffer.push(stick, _input_tick)        # stick-change edge
	var downs := buttons_held & ~_prev_buttons
	for bit in [MotionBuffer.B_PUNCH, MotionBuffer.B_BLOCK, MotionBuffer.B_SPUNCH,
			MotionBuffer.B_KICK, MotionBuffer.B_SKICK]:
		if (downs & bit) != 0:
			motion_buffer.push(bit | stick, _input_tick)   # button-down edge carries stick
	charge.update(buttons_held)
	_prev_stick = stick
	_prev_buttons = buttons_held

## OR of the attack buttons currently held (live input).
func _buttons_held_mask() -> int:
	var p := _action_prefix()
	var m := 0
	if _held(p + "punch"): m |= MotionBuffer.B_PUNCH
	if _held(p + "block"): m |= MotionBuffer.B_BLOCK
	if _held(p + "high_punch"): m |= MotionBuffer.B_SPUNCH
	if _held(p + "kick"): m |= MotionBuffer.B_KICK
	if _held(p + "high_kick"): m |= MotionBuffer.B_SKICK
	return m

func _held(action: String) -> bool:
	return InputMap.has_action(action) and Input.is_action_pressed(action)

## True only when the action exists in the map AND was just pressed. The has_action
## guard keeps Player 2 (which has no attack actions yet) from erroring on missing ones.
func _pressed(action: String) -> bool:
	return InputMap.has_action(action) and Input.is_action_just_pressed(action)
