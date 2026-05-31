extends "res://addons/gut/test.gd"

const T := preload("res://assets/movetables/doink.tres")

func _id(rng: int, dir: int, btn: int) -> String:
	var s: MoveSequence = T.lookup(rng, dir, btn)
	return s.id if s != null else ""

func test_punch_by_range():
	assert_eq(_id(MoveTable.Rng.NORMAL,   MoveTable.Dir.NEUTRAL, MoveTable.Btn.LOW_PUNCH), "punch")
	assert_eq(_id(MoveTable.Rng.CLOSE,    MoveTable.Dir.NEUTRAL, MoveTable.Btn.LOW_PUNCH), "headbutt")
	assert_eq(_id(MoveTable.Rng.GROUNDED, MoveTable.Dir.NEUTRAL, MoveTable.Btn.LOW_PUNCH), "elbow_drop")

func test_kick_by_range():
	assert_eq(_id(MoveTable.Rng.NORMAL,   MoveTable.Dir.NEUTRAL, MoveTable.Btn.LOW_KICK), "kick")
	assert_eq(_id(MoveTable.Rng.CLOSE,    MoveTable.Dir.NEUTRAL, MoveTable.Btn.LOW_KICK), "knee")
	assert_eq(_id(MoveTable.Rng.GROUNDED, MoveTable.Dir.NEUTRAL, MoveTable.Btn.LOW_KICK), "stomp")
	assert_eq(_id(MoveTable.Rng.RUNNING,  MoveTable.Dir.NEUTRAL, MoveTable.Btn.LOW_KICK), "big_boot")

func test_super_punch_far_slap_close_down_uppercut():
	assert_eq(_id(MoveTable.Rng.NORMAL, MoveTable.Dir.NEUTRAL, MoveTable.Btn.HIGH_PUNCH), "slap")
	assert_eq(_id(MoveTable.Rng.CLOSE,  MoveTable.Dir.NEUTRAL, MoveTable.Btn.HIGH_PUNCH), "slap")
	assert_eq(_id(MoveTable.Rng.CLOSE,  MoveTable.Dir.DOWN,    MoveTable.Btn.HIGH_PUNCH), "uppercut")

func test_super_kick_far_spin_close_knee():
	assert_eq(_id(MoveTable.Rng.NORMAL,   MoveTable.Dir.NEUTRAL, MoveTable.Btn.HIGH_KICK), "spin_kick")
	assert_eq(_id(MoveTable.Rng.CLOSE,    MoveTable.Dir.NEUTRAL, MoveTable.Btn.HIGH_KICK), "knee")
	assert_eq(_id(MoveTable.Rng.GROUNDED, MoveTable.Dir.NEUTRAL, MoveTable.Btn.HIGH_KICK), "stomp")
