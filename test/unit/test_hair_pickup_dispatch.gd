extends "res://addons/gut/test.gd"
## _grounded_move_or_hair_pickup: upgrades a resolved elbow_drop to hair_pickup at the head.

func _player_at(x: float, y: float) -> Player:
	var p := Player.new(); add_child_autofree(p)
	p.global_position = Vector2(x, y); p.side = Fighter.Side.PLAYER
	return p

func _downed_enemy_at(x: float, y: float, facing: float) -> Fighter:
	var f := Fighter.new(); add_child_autofree(f)
	f.global_position = Vector2(x, y); f.side = Fighter.Side.ENEMY
	f.mode = Fighter.Mode.ONGROUND; f._set_facing(facing)
	return f

func _elbow() -> MoveSequence:
	return load("res://assets/sequences/doink/elbow_drop.tres")

func test_gate_pass_swaps_to_hair_pickup():
	var p := _player_at(100, 400); p._set_facing(1.0)         # faces right toward the foe
	p.target = _downed_enemy_at(150, 400, -1.0)               # dx 50>=32, opposite facing = head
	assert_eq(p._grounded_move_or_hair_pickup(_elbow(), MoveTable.Btn.HIGH_PUNCH).id, "hair_pickup")

func test_too_close_keeps_elbow_drop():
	var p := _player_at(100, 400); p._set_facing(1.0)
	p.target = _downed_enemy_at(120, 400, -1.0)               # dx 20 < 32
	assert_eq(p._grounded_move_or_hair_pickup(_elbow(), MoveTable.Btn.HIGH_PUNCH).id, "elbow_drop")

func test_same_facing_feet_keeps_elbow_drop():
	var p := _player_at(100, 400); p._set_facing(1.0)
	p.target = _downed_enemy_at(150, 400, 1.0)                # same facing = at the feet
	assert_eq(p._grounded_move_or_hair_pickup(_elbow(), MoveTable.Btn.HIGH_PUNCH).id, "elbow_drop")

func test_no_target_keeps_elbow_drop():
	var p := _player_at(100, 400); p._set_facing(1.0); p.target = null
	assert_eq(p._grounded_move_or_hair_pickup(_elbow(), MoveTable.Btn.HIGH_PUNCH).id, "elbow_drop")

func test_non_elbow_move_passes_through_unchanged():
	var p := _player_at(100, 400); p._set_facing(1.0)
	p.target = _downed_enemy_at(150, 400, -1.0)
	var stomp := load("res://assets/sequences/doink/stomp.tres")
	assert_eq(p._grounded_move_or_hair_pickup(stomp, MoveTable.Btn.HIGH_PUNCH).id, "stomp", "only elbow_drop is upgraded")

func test_low_punch_at_head_keeps_elbow_drop():
	# GROUNDED+LOW_PUNCH also resolves to elbow_drop, but hair pickup is SPUNCH-only (arcade).
	var p := _player_at(100, 400); p._set_facing(1.0)
	p.target = _downed_enemy_at(150, 400, -1.0)   # geometry would pass...
	assert_eq(p._grounded_move_or_hair_pickup(_elbow(), MoveTable.Btn.LOW_PUNCH).id, "elbow_drop",
		"low punch does NOT hair-pickup; only SPUNCH does")

func test_null_seq_passes_through():
	var p := _player_at(100, 400); p._set_facing(1.0)
	p.target = _downed_enemy_at(150, 400, -1.0)
	assert_null(p._grounded_move_or_hair_pickup(null, MoveTable.Btn.HIGH_PUNCH), "null lookup stays null")
