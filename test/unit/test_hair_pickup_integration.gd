extends "res://addons/gut/test.gd"
## End-to-end: a downed foe is hair-picked into the head hold, and an existing head-hold
## follow-up (piledriver) fires from the resulting hold — proving the reuse.

func _player() -> Player:
	var p := Player.new(); add_child_autofree(p); return p

func test_lift_then_follow_up_fires_from_the_hold():
	var atk := _player(); var vic := _player()
	atk.global_position = Vector2(100, 400); atk._set_facing(1.0)
	vic.global_position = Vector2(150, 400); vic.mode = Fighter.Mode.ONGROUND; vic._set_facing(-1.0)
	# Lift: start the sequence, connect the grab, then run until the (uninterruptable) lift ends.
	atk.start_move(load("res://assets/sequences/doink/hair_pickup.tres"))
	atk._player.advance(1.0 / 60.0)
	vic.receive_grab(atk, atk.current_move())
	atk._player.notify_grab_connected()
	for _i in range(150):
		atk._physics_process(1.0 / 60.0)
		if not atk.is_attacking():
			break
	assert_false(atk.is_attacking(), "the uninterruptable lift sequence completed")
	assert_eq(atk.mode, Fighter.Mode.HEADHOLD, "attacker ended in the head hold")
	assert_eq(vic.mode, Fighter.Mode.HEADHELD, "victim held standing")
	assert_eq(atk._grappling, vic, "victim still attached after the lift")
	# Reuse: a buffered piledriver follow-up fires from the hold (same buffer pattern proven by
	# test_headhold_dispatch.gd). This proves the hair-pickup hold feeds the existing follow-up path.
	atk.motion_buffer.push(MotionBuffer.J_TOWARD | MotionBuffer.J_RIGHT, 1)
	atk.motion_buffer.push(MotionBuffer.J_TOWARD | MotionBuffer.J_RIGHT, 2)
	atk.motion_buffer.push(MotionBuffer.B_SPUNCH | MotionBuffer.J_TOWARD | MotionBuffer.J_RIGHT, 3)
	atk._input_tick = 3
	assert_true(atk.scan_headhold_followups(), "a follow-up fires from a hair-pickup hold")
	assert_eq(atk.current_move().id, "piledriver")
