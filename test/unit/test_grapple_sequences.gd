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

func test_motiontable_maps_grabs_to_sequences():
	var t: MotionTable = load("res://assets/motions/doink_motions.tres")
	assert_not_null(t, "doink_motions.tres loads")
	assert_eq(t.lookup("hip_toss").id, "hip_toss")
	assert_eq(t.lookup("grab_fling").id, "grab_fling")
	assert_eq(t.lookup("neck_grab").id, "neck_grab")
	# Scan order: throws before head grab (matches doink_secret_moves order).
	var ids := []
	for m in t.moves():
		ids.append(m.move_id)
	assert_true(ids.find("hip_toss") < ids.find("neck_grab"), "throws scanned before head grab")

func _assert_followup(path: String, anim: String):
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
	assert_false(has_wait, "follow-up has NO grab window (victim already held)")
	assert_true(has_attach, "has SET_ATTACH")
	assert_true(has_dmg, "has DAMAGE_OPP")
	assert_true(has_detach, "has DETACH")

func test_followup_sequences_exist():
	_assert_followup("res://assets/sequences/doink/piledriver.tres", "piledriver")
	_assert_followup("res://assets/sequences/doink/head_slam.tres", "faceslam")
	_assert_followup("res://assets/sequences/doink/joy_buzzer.tres", "joy_buzzer")

func test_followup_motions_exist():
	var pd: MotionMove = load("res://assets/motions/doink/piledriver.tres")
	assert_not_null(pd, "piledriver motion loads")
	assert_eq(pd.values, PackedInt32Array([MotionBuffer.B_SPUNCH, MotionBuffer.J_TOWARD, MotionBuffer.J_TOWARD]))
	var hs: MotionMove = load("res://assets/motions/doink/head_slam.tres")
	assert_not_null(hs, "head_slam motion loads")
	assert_eq(hs.values, PackedInt32Array([MotionBuffer.B_SKICK, MotionBuffer.J_DOWN, MotionBuffer.J_DOWN]))

func test_main_table_excludes_followups():
	var t: MotionTable = load("res://assets/motions/doink_motions.tres")
	assert_null(t.lookup("piledriver"), "follow-ups are NOT in the main grab-initiator table")
	assert_null(t.lookup("head_slam"))
	assert_eq(t.moves().size(), 3, "main table = 3 grab initiators only")
