extends "res://addons/gut/test.gd"
## SequencePlayer surfaces a SET_LAUNCH frame as a one-shot consume_launch() + param getters.

func _launch_seq() -> MoveSequence:
	var m := MoveSequence.new()
	m.id = "t"; m.anim_name = "x"
	var f0 := SequenceFrame.new()
	f0.duration_ticks = 2; f0.anim_frame = 0
	f0.command = SequenceFrame.Command.SET_LAUNCH
	f0.launch_yvel = 0x90000
	f0.launch_homing = true
	f0.leap_ticks = 11
	f0.leap_cap_x = 0x50000
	f0.leap_cap_z = 0x50000
	var f1 := SequenceFrame.new()
	f1.duration_ticks = 2; f1.anim_frame = 1
	m.frames = [f0, f1]
	return m

func test_launch_fires_once_then_clears():
	var sp := SequencePlayer.new()
	sp.play(_launch_seq())
	sp.advance(1.0 / 60.0)            # enters frame 0 -> SET_LAUNCH
	assert_true(sp.consume_launch(), "launch intent set on the SET_LAUNCH frame")
	assert_false(sp.consume_launch(), "read-and-clear: second read is false")

func test_launch_params_exposed():
	var sp := SequencePlayer.new()
	sp.play(_launch_seq())
	sp.advance(1.0 / 60.0)
	assert_eq(sp.launch_yvel(), 0x90000)
	assert_true(sp.launch_homing())
	assert_eq(sp.leap_ticks(), 11)
	assert_eq(sp.leap_cap_x(), 0x50000)
	assert_eq(sp.leap_cap_z(), 0x50000)
