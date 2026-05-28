class_name Player
extends Fighter
## A Fighter driven by per-player input actions.
## player_index 0 -> p1_* actions; player_index 1 -> p2_* actions.

const _MOVES := preload("res://assets/movetables/doink.tres")

const _CLOSE_GATE := 50.0   # arcade close-range gate (headbutt vs punch), DOINK.ASM:1921; tune in playtest

@export var player_index: int = 0

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

## True only when the action exists in the map AND was just pressed. The has_action
## guard keeps Player 2 (which has no attack actions yet) from erroring on missing ones.
func _pressed(action: String) -> bool:
	return InputMap.has_action(action) and Input.is_action_just_pressed(action)
