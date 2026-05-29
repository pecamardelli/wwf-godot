extends "res://addons/gut/test.gd"

func _assert_grab(path: String, anim: String):
	var m: MoveSequence = load(path)
	assert_not_null(m, path + " loads")
	assert_true(m.is_grapple, "is a grapple")
	assert_eq(m.anim_name, anim)
	var has_wait := false; var has_attach := false; var has_dmg := false; var has_detach := false
	for f in m.frames:
		match f.command:
			SequenceFrame.Command.WAIT_HIT_OPP: has_wait = true
			SequenceFrame.Command.SET_ATTACH: has_attach = true
			SequenceFrame.Command.DAMAGE_OPP: has_dmg = true
			SequenceFrame.Command.DETACH: has_detach = true
	assert_true(has_wait, "has WAIT_HIT_OPP")
	assert_true(has_attach, "has SET_ATTACH")
	assert_true(has_dmg, "has DAMAGE_OPP")
	assert_true(has_detach, "has DETACH")

func test_hip_toss_sequence():
	_assert_grab("res://assets/sequences/doink/hip_toss.tres", "hip_toss")

func test_grab_fling_sequence():
	_assert_grab("res://assets/sequences/doink/grab_fling.tres", "fling")
