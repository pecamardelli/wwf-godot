extends "res://addons/gut/test.gd"

func _make() -> Fighter:
	var f := Fighter.new(); add_child_autofree(f); return f

func _neck_seq() -> MoveSequence:
	return load("res://assets/sequences/doink/neck_grab.tres")

func test_neck_grab_enters_head_hold():
	var atk := _make(); var vic := _make()
	atk.start_move(_neck_seq())
	atk._player.advance(1.0 / 60.0)         # WAIT_HIT_OPP
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
	assert_almost_eq(vic.global_position.x, 230.0, 0.5, "held victim is pulled to captor.x + offset each tick")
	assert_eq(vic._facing, atk._facing, "held victim faces with the captor")

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
