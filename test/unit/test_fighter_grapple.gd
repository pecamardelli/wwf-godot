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

func _attach_drive_seq() -> MoveSequence:
	# SET_ATTACH(offset/anim) -> SLAVE_ANIM frame with offset -> DAMAGE_OPP -> DETACH
	var m := MoveSequence.new(); m.id = "g2"; m.anim_name = "hip_toss"; m.is_grapple = true
	var attach := SequenceFrame.new()
	attach.duration_ticks = 2; attach.command = SequenceFrame.Command.SET_ATTACH
	attach.slave_anim = "hip_tossed"; attach.victim_offset = Vector3(30, 0, 0); attach.victim_anim_frame = 1
	var dmg := SequenceFrame.new()
	dmg.duration_ticks = 2; dmg.command = SequenceFrame.Command.DAMAGE_OPP; dmg.victim_amode = AMode.BIGBOOT
	dmg.victim_offset = Vector3(30, 0, 0)
	var detach := SequenceFrame.new()
	detach.duration_ticks = 2; detach.command = SequenceFrame.Command.DETACH
	m.frames = [attach, dmg, detach]
	return m

func test_puppet_position_follows_attacker():
	var atk := _make(); var vic := _make()
	atk.global_position = Vector2(100, 400); atk._set_facing(1.0)
	atk.start_move(_attach_drive_seq())
	vic.receive_grab(atk, atk.current_move())
	atk._physics_process(1.0 / 60.0)   # enters SET_ATTACH, drives victim
	assert_almost_eq(vic.global_position.x, 130.0, 0.5, "victim at attacker.x + offset.x")

func test_puppet_offset_mirrors_with_facing():
	var atk := _make(); var vic := _make()
	atk.global_position = Vector2(100, 400); atk._set_facing(-1.0)
	atk.start_move(_attach_drive_seq())
	vic.receive_grab(atk, atk.current_move())
	atk._physics_process(1.0 / 60.0)
	assert_almost_eq(vic.global_position.x, 70.0, 0.5, "offset.x mirrored when facing left")

func test_puppet_faces_same_way_as_attacker():
	var atk := _make(); var vic := _make()
	atk.global_position = Vector2(100, 400); atk._set_facing(1.0)
	vic._set_facing(-1.0)   # victim was facing the attacker (opposite) before the grab
	atk.start_move(_attach_drive_seq())
	vic.receive_grab(atk, atk.current_move())
	atk._physics_process(1.0 / 60.0)
	assert_eq(vic._facing, atk._facing, "grabbed victim is oriented to the attacker, not facing away")
	atk._set_facing(-1.0)   # attacker turns; the puppet follows
	atk._physics_process(1.0 / 60.0)
	assert_eq(vic._facing, -1.0, "victim re-orients with the attacker each tick")

func test_damage_opp_applies_once_and_detach_knocks_down():
	var atk := _make(); var vic := _make()
	atk.global_position = Vector2(100, 400)
	var before := vic.health
	atk.start_move(_attach_drive_seq())
	vic.receive_grab(atk, atk.current_move())
	for _i in range(20):
		atk._physics_process(1.0 / 60.0)
	assert_lt(vic.health, before, "puppet damage applied")
	assert_eq(vic.mode, Fighter.Mode.ONGROUND, "DETACH knocks the victim down")
	assert_null(atk._grappling, "attacker ref cleared on detach")
	assert_null(vic._grappled_by, "victim ref cleared on detach")
	assert_eq(atk.mode, Fighter.Mode.NORMAL, "attacker freed to NORMAL after the throw completes")
	assert_false(atk.is_attacking(), "attacker's sequence is done")
