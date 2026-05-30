extends "res://addons/gut/test.gd"

func _make() -> Fighter:
	var f := Fighter.new(); add_child_autofree(f); return f

func _neck_seq() -> MoveSequence:
	return load("res://assets/sequences/doink/neck_grab.tres")

func test_neck_grab_enters_head_hold():
	var atk := _make(); var vic := _make()
	atk.start_move(_neck_seq())
	atk._player.advance(1.0 / 60.0)         # into the reach lead-in
	# Force the connect directly (the timing path — reach -> grab window at frame 4 -> connect
	# -> head hold — is covered end-to-end by test_grapple_integration.gd).
	vic.receive_grab(atk, atk.current_move())
	atk._player.notify_grab_connected()
	for _i in range(6):                      # advance into SET_ATTACH then finish
		atk._physics_process(1.0 / 60.0)
	assert_eq(atk.mode, Fighter.Mode.HEADHOLD)
	assert_eq(vic.mode, Fighter.Mode.HEADHELD)

func test_immobilize_time_counts_down():
	var f := _make()
	f.set_immobilize_ticks(15)
	assert_true(f.is_immobilized())
	for _i in range(20):
		f._physics_process(1.0 / 60.0)
	assert_false(f.is_immobilized(), "immobilize wears off")

func test_head_hold_auto_breaks_after_timeout():
	var atk := _make(); var vic := _make()
	# Enter the hold directly with a short break window.
	atk.mode = Fighter.Mode.HEADHOLD; atk._grappling = vic; atk._set_headhold_break_ticks(60)
	vic.mode = Fighter.Mode.HEADHELD; vic._grappled_by = atk
	for _i in range(80):
		atk._physics_process(1.0 / 60.0)
		vic._physics_process(1.0 / 60.0)
	assert_eq(atk.mode, Fighter.Mode.NORMAL, "holder released")
	assert_eq(vic.mode, Fighter.Mode.NORMAL, "victim released")
	assert_null(atk._grappling)
	assert_null(vic._grappled_by)

func test_static_hold_keeps_victim_attached_and_facing():
	var atk := _make(); var vic := _make()
	atk.global_position = Vector2(200, 400); atk._set_facing(1.0)
	atk.mode = Fighter.Mode.HEADHOLD; atk._grappling = vic
	atk._set_headhold_break_ticks(600)   # long window so it doesn't auto-break mid-test
	vic.mode = Fighter.Mode.HEADHELD; vic._grappled_by = atk
	vic._set_facing(-1.0); vic.global_position = Vector2(999, 999)   # drifted off
	atk._physics_process(1.0 / 60.0)
	# captor.x (200) + the arcade-matched hold offset, facing right.
	var expected_x: float = 200.0 + Fighter._HEADHOLD_VICTIM_X
	assert_almost_eq(vic.global_position.x, expected_x, 0.5, "held victim is pulled to captor.x + offset each tick")
	assert_eq(vic._facing, atk._facing, "held victim faces with the captor")

func test_headlocked_per_frame_anchor_pins_the_grip():
	# The held victim's neck (grip) must not drift frame-to-frame: each headlocked frame gets a
	# baked X render offset so the grip stays put. Unflipped, offset = the table value; flipped,
	# it negates (the texture mirrors, grip must still hold in world space).
	var tbl: Array = Fighter._ANIM_FRAME_X_OFFSET["headlocked"]
	var f := _make()
	if f.sprite == null or f.sprite.sprite_frames == null or not f.sprite.sprite_frames.has_animation("headlocked"):
		pass_test("no headlocked sprite frames available in this build")
		return
	f.sprite.animation = "headlocked"
	# Record the per-frame offset for each facing; flip must negate it so the grip holds in world.
	var off_by_flip := {}
	for facing in [1.0, -1.0]:
		f._set_facing(facing)
		var offs: Array = []
		for i in range(tbl.size()):
			f.sprite.frame = i
			f._refresh_flip()
			offs.append(f.sprite.offset.x)
		off_by_flip[f.sprite.flip_h] = offs
	# One facing is flipped, the other isn't; their offsets must be exact negations.
	assert_true(off_by_flip.has(true) and off_by_flip.has(false), "headlocked flips with facing")
	var raw: Array = off_by_flip[false]   # unflipped = the raw table
	var flipped: Array = off_by_flip[true]
	for i in range(tbl.size()):
		assert_almost_eq(raw[i], float(tbl[i]), 0.01, "unflipped frame %d == table value" % i)
		assert_almost_eq(flipped[i], -float(tbl[i]), 0.01, "flipped frame %d negates the table value" % i)
	# The offset actually VARIES across frames (it pins a drifting grip, not a constant).
	assert_true(raw[0] != raw[6], "per-frame offset varies (grip correction, not a constant)")
	# A non-headlocked animation gets no horizontal correction.
	if f.sprite.sprite_frames.has_animation("idle_front"):
		f.sprite.animation = "idle_front"; f.sprite.frame = 0
		f._refresh_flip()
		assert_almost_eq(f.sprite.offset.x, 0.0, 0.01, "untabled anim has no grip offset")

func test_release_staggers_the_victim_not_instant_idle():
	# Arcade dnk_3_head_held_brk_anim: on release the victim is shoved away and plays a head-hit
	# reaction (a stagger), not an instant snap to idle.
	var atk := _make(); var vic := _make()
	atk.global_position = Vector2(200, 400); atk._set_facing(1.0)
	atk.mode = Fighter.Mode.HEADHOLD; atk._grappling = vic
	atk._set_headhold_break_ticks(1)   # auto-break almost immediately
	vic.mode = Fighter.Mode.HEADHELD; vic._grappled_by = atk
	vic.global_position = Vector2(251, 400)
	for _i in range(10):
		atk._physics_process(1.0 / 60.0)
		if atk.mode != Fighter.Mode.HEADHOLD:
			break
	assert_ne(atk.mode, Fighter.Mode.HEADHOLD, "the hold auto-broke")
	assert_gt(vic._react_timer, 0.0, "released victim staggers (in a reaction), not instant idle")
	assert_eq(vic.mode, Fighter.Mode.NORMAL, "victim staggers standing (not knocked down)")
	assert_gt(vic.global_position.x, 251.0, "victim is shoved away from the captor")

func test_blocked_grab_recoils_the_attacker_backward():
	var atk := _make(); var vic := _make()
	atk.global_position = Vector2(100, 400)
	vic.global_position = Vector2(140, 400)
	atk._set_facing(1.0)                      # facing right (toward the victim)
	var seq := MoveSequence.new(); seq.id = "neck_grab"; seq.is_grapple = true
	seq.anim_name = "headlocks"; seq.reverse_reach_on_whiff = true
	var wait := SequenceFrame.new(); wait.duration_ticks = 3; wait.anim_frame = 0
	wait.command = SequenceFrame.Command.WAIT_HIT_OPP
	wait.attack_box = Box3.new(); wait.attack_box.size = Vector3(40, 60, 10); wait.wait_hit_max_ticks = 16
	var r := SequenceFrame.new(); r.duration_ticks = 3; r.anim_frame = 1; r.command = SequenceFrame.Command.NONE
	# reach frame BEFORE the window so the reverse has somewhere to retract to
	seq.frames = [r, wait]
	atk.start_move(seq)
	# Advance until the player reaches the WAIT_HIT_OPP hold (needs _waiting_for_hit == true).
	for _i in range(6):
		atk._physics_process(1.0 / 60.0)
	assert_true(atk._player.is_waiting_for_hit(), "precondition: must be in the grab window before blocking")
	var x0 := atk.global_position.x
	atk._player.notify_grab_blocked()         # blocked -> reverse + recoil latch
	for _i in range(20):
		atk._physics_process(1.0 / 60.0)
	assert_lt(atk.global_position.x, x0, "a blocked grab recoils the attacker backward (away from the victim)")
