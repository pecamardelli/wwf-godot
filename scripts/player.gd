class_name Player
extends Fighter
## A Fighter driven by per-player input actions.
## player_index 0 -> p1_* actions; player_index 1 -> p2_* actions.

const _PUNCH := preload("res://assets/sequences/doink/punch.tres")
const _HEADBUTT := preload("res://assets/sequences/doink/headbutt.tres")
const _KICK := preload("res://assets/sequences/doink/kick.tres")
const _BIG_BOOT := preload("res://assets/sequences/doink/big_boot.tres")

@export var player_index: int = 0

func _action_prefix() -> String:
	return "p1_" if player_index == 0 else "p2_"

func get_input_direction() -> Vector2:
	var p: String = _action_prefix()
	return Vector2(
		Input.get_axis(p + "left", p + "right"),
		Input.get_axis(p + "up", p + "down")
	)

func _unhandled_input(_event: InputEvent) -> void:
	# Same gate as movement: helpless/blocking fighters can't start a move.
	if not Fighter.input_allowed(mode) or is_attacking():
		return
	var p := _action_prefix()
	if Input.is_action_just_pressed(p + "punch"):
		# close -> headbutt, else punch (full range/relative-input dispatch is 2c)
		start_move(_HEADBUTT if _opponent_is_close() else _PUNCH)
	elif Input.is_action_just_pressed(p + "kick"):
		start_move(_BIG_BOOT if mode == Mode.RUNNING else _KICK)

func _opponent_is_close() -> bool:
	var nearest := 1e9
	for f in get_tree().get_nodes_in_group("fighters"):
		if f == self:
			continue
		nearest = minf(nearest, absf(f.global_position.x - global_position.x))
	return nearest <= 50.0   # arcade close gate ~50 (DOINK.ASM:1921)
