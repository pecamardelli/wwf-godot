extends "res://addons/gut/test.gd"

func _grab_seq() -> MoveSequence:
	var m := MoveSequence.new(); m.id = "g"; m.anim_name = "hip_toss"; m.is_grapple = true
	m.attack_mode = AMode.PUNCH
	var attach := SequenceFrame.new()
	attach.duration_ticks = 2; attach.command = SequenceFrame.Command.SET_ATTACH; attach.slave_anim = "hip_tossed"
	m.frames = [attach]
	return m

func _make() -> Fighter:
	var f := Fighter.new()
	add_child_autofree(f)
	return f

func test_new_modes_exist():
	assert_eq(Fighter.Mode.GRABBING, 6)
	assert_eq(Fighter.Mode.GRABBED, 7)
	assert_eq(Fighter.Mode.HEADHOLD, 8)
	assert_eq(Fighter.Mode.HEADHELD, 9)

func test_receive_grab_binds_modes_and_refs():
	var atk := _make(); var vic := _make()
	atk.start_move(_grab_seq())
	vic.receive_grab(atk, atk.current_move())
	assert_eq(atk.mode, Fighter.Mode.GRABBING)
	assert_eq(vic.mode, Fighter.Mode.GRABBED)
	assert_eq(atk._grappling, vic)
	assert_eq(vic._grappled_by, atk)

func test_grabbed_victim_does_not_read_input():
	assert_false(Fighter.input_allowed(Fighter.Mode.GRABBED))
	assert_false(Fighter.input_allowed(Fighter.Mode.GRABBING))
	assert_false(Fighter.input_allowed(Fighter.Mode.HEADHELD))
