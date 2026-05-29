extends "res://addons/gut/test.gd"

func _player() -> Player:
	var p := Player.new()
	add_child_autofree(p)
	return p

func test_holder_piledriver_launches_with_victim_attached():
	var atk := _player(); var vic := _player()
	atk.mode = Fighter.Mode.HEADHOLD; atk._grappling = vic
	vic.mode = Fighter.Mode.HEADHELD; vic._grappled_by = atk
	# Buffer the piledriver follow-up: toward, toward, SPUNCH (held toward).
	atk.motion_buffer.push(MotionBuffer.J_TOWARD | MotionBuffer.J_RIGHT, 1)
	atk.motion_buffer.push(MotionBuffer.J_TOWARD | MotionBuffer.J_RIGHT, 2)
	atk.motion_buffer.push(MotionBuffer.B_SPUNCH | MotionBuffer.J_TOWARD | MotionBuffer.J_RIGHT, 3)
	atk._input_tick = 3
	assert_true(atk.scan_headhold_followups(), "piledriver launched from the hold")
	assert_eq(atk.current_move().id, "piledriver")
	assert_eq(atk._grappling, vic, "victim still attached for the follow-up")
	assert_true(vic.is_immobilized(), "victim immobilized during the follow-up")

func test_no_followup_without_match():
	var atk := _player(); var vic := _player()
	atk.mode = Fighter.Mode.HEADHOLD; atk._grappling = vic
	vic.mode = Fighter.Mode.HEADHELD; vic._grappled_by = atk
	assert_false(atk.scan_headhold_followups(), "no buffered motion -> no follow-up")
