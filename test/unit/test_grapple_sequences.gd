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

func test_grapple_sequences_walk_every_attacker_frame():
	# Bug 2 guard: the throw/follow-up must step through EVERY sprite frame of its attacker
	# animation IN ORDER, or the visible throw is cut short. The step count may EXCEED the
	# attacker clip (so the longer victim clip isn't forced to drop frames — see the victim
	# test below); when it does, an attacker frame repeats, but none may be skipped.
	var sf: SpriteFrames = load("res://assets/sprites/doink/doink_frames.tres")
	for pair in [["hip_toss", "hip_toss"], ["grab_fling", "fling"],
			["piledriver", "piledriver"], ["head_slam", "faceslam"], ["joy_buzzer", "joy_buzzer"]]:
		var m: MoveSequence = load("res://assets/sequences/doink/%s.tres" % pair[0])
		var n: int = sf.get_frame_count(pair[1])
		var seen := {}
		var prev := -1
		for f in m.frames:
			assert_true(f.anim_frame >= prev, "%s attacker frames are monotonic (no jump back)" % pair[0])
			prev = f.anim_frame
			seen[f.anim_frame] = true
		for i in range(n):
			assert_true(seen.has(i), "%s shows attacker frame %d (throw not cut short)" % [pair[0], i])

func test_grapple_victim_plays_every_frame():
	# Root-cause guard: the victim's slave clip was resampled onto the ATTACKER's step count;
	# when the victim clip is LONGER it dropped frames (the puppet "missed frames" mid-toss —
	# piledriver dropped 7 of 16). Every frame of the victim's slave animation must be shown,
	# in order, exactly because ANI_SUPERSLAVE2 names the victim frame per step independently.
	var sf: SpriteFrames = load("res://assets/sprites/doink/doink_frames.tres")
	for pair in [["hip_toss", "hip_tossed"], ["grab_fling", "flinged"],
			["piledriver", "piledrivered"], ["head_slam", "faceslamed"], ["joy_buzzer", "joy_buzzer"],
			["neck_grab", "headlocked"]]:
		var m: MoveSequence = load("res://assets/sequences/doink/%s.tres" % pair[0])
		var v: int = sf.get_frame_count(pair[1])
		var seen := {}
		var prev := -1
		for f in m.frames:
			assert_true(f.victim_anim_frame >= prev, "%s victim frames are monotonic (no jump back)" % pair[0])
			prev = f.victim_anim_frame
			seen[f.victim_anim_frame] = true
		for i in range(v):
			assert_true(seen.has(i), "%s victim shows slave frame %d (no dropped frame)" % [pair[0], i])

func test_neck_grab_reaches_then_grabs_mid_clip():
	# Arcade dnk_3_head_hold_anim: reach lead-in (no grab), grab window at the reach apex
	# (headlocks frame 4 = sprite 05), then puppet into the hold pose (frame 6 = sprite 07).
	var m: MoveSequence = load("res://assets/sequences/doink/neck_grab.tres")
	assert_eq(m.anim_name, "headlocks")
	assert_true(m.reverse_reach_on_whiff, "neck grab retracts on a whiff/block (flag set in the .tres)")
	# Lead-in frames 0-3 are plain reach (no grab command).
	for i in range(4):
		assert_eq(m.frames[i].anim_frame, i, "reach lead-in shows headlocks frame %d" % i)
		assert_eq(m.frames[i].command, SequenceFrame.Command.NONE, "reach frame %d has no grab command" % i)
	# The grab window sits at the reach apex (frame index 4).
	assert_eq(m.frames[4].command, SequenceFrame.Command.WAIT_HIT_OPP, "grab window at the reach apex")
	assert_eq(m.frames[4].anim_frame, 4, "grab window shows headlocks frame 4 (sprite 05)")
	assert_not_null(m.frames[4].attack_box, "grab window opens a grab box")
	# The connected pull-in ends on the hold pose (headlocks frame 6 = sprite 07).
	assert_eq(m.frames[m.frames.size() - 1].anim_frame, 6, "ends on the locked pose (sprite 07)")
	# A SET_ATTACH binds the victim once the grab connects.
	var has_attach := false
	for f in m.frames:
		if f.command == SequenceFrame.Command.SET_ATTACH:
			has_attach = true
	assert_true(has_attach, "binds the victim with SET_ATTACH after the connect")
	# It's a HOLD entry: no DAMAGE_OPP / DETACH (follow-ups drive those).
	for f in m.frames:
		assert_ne(f.command, SequenceFrame.Command.DAMAGE_OPP, "neck grab does not damage on entry")
		assert_ne(f.command, SequenceFrame.Command.DETACH, "neck grab does not detach on entry")

func test_hip_toss_victim_sweeps_front_to_back():
	# Arcade arc (DNKSEQ2.ASM:4643 #puppet_tbl #Doink), scaled to our world: the victim starts
	# a reach IN FRONT and is flung BEHIND on the slam. Robust to the offset scale knob.
	var m: MoveSequence = load("res://assets/sequences/doink/hip_toss.tres")
	assert_gt(m.frames[1].victim_offset.x, 20.0, "victim starts a reach in front (not glued on)")
	assert_lt(m.frames[m.frames.size() - 1].victim_offset.x, 0.0, "victim flung behind on the slam")

func test_reverse_reach_flag_defaults_false_and_throws_dont_reverse():
	# The flag is opt-in: defaults false, and no throw/follow-up reverses. (neck_grab is
	# asserted true in a later task, once its .tres is regenerated with the flag set.)
	var fresh := MoveSequence.new()
	assert_false(fresh.reverse_reach_on_whiff, "flag defaults to false")
	for id in ["hip_toss", "grab_fling", "piledriver", "head_slam", "joy_buzzer"]:
		var m: MoveSequence = load("res://assets/sequences/doink/%s.tres" % id)
		assert_false(m.reverse_reach_on_whiff, "%s does NOT reverse (throws/follow-ups end on whiff)" % id)
