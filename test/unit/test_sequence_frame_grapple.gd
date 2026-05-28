extends "res://addons/gut/test.gd"

func test_grapple_commands_exist():
	assert_eq(SequenceFrame.Command.WAIT_HIT_OPP, 4)
	assert_eq(SequenceFrame.Command.SET_ATTACH, 5)
	assert_eq(SequenceFrame.Command.SLAVE_ANIM, 6)
	assert_eq(SequenceFrame.Command.DAMAGE_OPP, 7)
	assert_eq(SequenceFrame.Command.DETACH, 8)
	assert_eq(SequenceFrame.Command.SET_OPP_MODE, 9)
	assert_eq(SequenceFrame.Command.CLR_OPP_MODE, 10)

func test_victim_track_fields_default():
	var f := SequenceFrame.new()
	assert_eq(f.victim_anim_frame, 0)
	assert_eq(f.victim_offset, Vector3.ZERO)
	assert_eq(f.slave_anim, "")
	assert_eq(f.opp_mode, Fighter.Mode.NORMAL)
	assert_eq(f.victim_amode, AMode.PUNCH)
	assert_false(f.victim_dizzy)
	assert_eq(f.wait_hit_max_ticks, 16)
