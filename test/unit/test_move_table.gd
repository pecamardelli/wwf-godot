extends "res://addons/gut/test.gd"

func _table() -> MoveTable:
	return load("res://assets/movetables/doink.tres")

func test_low_punch_far_is_punch_close_is_headbutt():
	var t := _table()
	assert_eq(t.lookup(MoveTable.Rng.NORMAL, MoveTable.Dir.NEUTRAL, MoveTable.Btn.LOW_PUNCH).id, "punch")
	assert_eq(t.lookup(MoveTable.Rng.CLOSE, MoveTable.Dir.NEUTRAL, MoveTable.Btn.LOW_PUNCH).id, "headbutt")

func test_high_punch_is_uppercut():
	assert_eq(_table().lookup(MoveTable.Rng.NORMAL, MoveTable.Dir.NEUTRAL, MoveTable.Btn.HIGH_PUNCH).id, "uppercut")

func test_dir_specific_falls_back_to_neutral():
	# no TOWARD entry exists -> falls back to the NEUTRAL low-kick (kick)
	assert_eq(_table().lookup(MoveTable.Rng.NORMAL, MoveTable.Dir.TOWARD, MoveTable.Btn.LOW_KICK).id, "kick")

func test_running_high_kick_is_big_boot():
	assert_eq(_table().lookup(MoveTable.Rng.RUNNING, MoveTable.Dir.NEUTRAL, MoveTable.Btn.HIGH_KICK).id, "big_boot")
