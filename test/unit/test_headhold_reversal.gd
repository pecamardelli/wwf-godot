extends "res://addons/gut/test.gd"

func _player() -> Player:
	var p := Player.new()
	add_child_autofree(p)
	return p

func _buffer_piledriver(p: Player):
	p.motion_buffer.push(MotionBuffer.J_TOWARD | MotionBuffer.J_RIGHT, 1)
	p.motion_buffer.push(MotionBuffer.J_TOWARD | MotionBuffer.J_RIGHT, 2)
	p.motion_buffer.push(MotionBuffer.B_SPUNCH | MotionBuffer.J_TOWARD | MotionBuffer.J_RIGHT, 3)
	p._input_tick = 3

func test_held_wrestler_reverses_into_holder():
	var captor := _player(); var held := _player()
	captor.mode = Fighter.Mode.HEADHOLD; captor._grappling = held
	held.mode = Fighter.Mode.HEADHELD; held._grappled_by = captor
	_buffer_piledriver(held)
	assert_true(held.scan_headhold_reversal(), "reversal fired")
	assert_eq(held._grappling, captor, "roles swapped: held now drives the captor")
	assert_eq(captor._grappled_by, held)
	assert_true(captor.is_immobilized(), "former captor immobilized")
	assert_eq(held.current_move().id, "piledriver", "reverser runs the follow-up")

func test_immobilized_held_cannot_reverse():
	var captor := _player(); var held := _player()
	captor.mode = Fighter.Mode.HEADHOLD; captor._grappling = held
	held.mode = Fighter.Mode.HEADHELD; held._grappled_by = captor
	held.set_immobilize_ticks(15)
	_buffer_piledriver(held)
	assert_false(held.scan_headhold_reversal(), "immobilized held wrestler can't counter")
