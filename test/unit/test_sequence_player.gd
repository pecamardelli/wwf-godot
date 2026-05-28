extends "res://addons/gut/test.gd"

func test_punch_sequence_loads_and_has_an_attack_window():
	var m: MoveSequence = load("res://assets/sequences/doink/punch.tres")
	assert_not_null(m, "punch.tres loads")
	assert_eq(m.attack_mode, AMode.PUNCH)
	var has_on := false
	var has_off := false
	for f in m.frames:
		if f.command == SequenceFrame.Command.ATTACK_ON: has_on = true
		if f.command == SequenceFrame.Command.ATTACK_OFF: has_off = true
	assert_true(has_on and has_off, "has ATTACK_ON and ATTACK_OFF frames")

func test_headbutt_causes_dizzy():
	var m: MoveSequence = load("res://assets/sequences/doink/headbutt.tres")
	assert_true(m.causes_dizzy)

const FRAME := 1.0 / 60.0

func _two_frame_move() -> MoveSequence:
	# frame0: 2 ticks, ATTACK_ON; frame1: 2 ticks, ATTACK_OFF
	var m := MoveSequence.new()
	m.id = "t"; m.anim_name = "mid_punch_front"; m.attack_mode = AMode.PUNCH
	var box := Box3.new(); box.size = Vector3(10, 10, 10)
	var f0 := SequenceFrame.new(); f0.duration_ticks = 2; f0.command = SequenceFrame.Command.ATTACK_ON; f0.attack_box = box
	var f1 := SequenceFrame.new(); f1.duration_ticks = 2; f1.command = SequenceFrame.Command.ATTACK_OFF
	m.frames = [f0, f1]
	return m

func test_attack_goes_live_on_attack_on_frame():
	var sp := SequencePlayer.new()
	sp.play(_two_frame_move())
	sp.advance(FRAME)   # enters frame 0 (ATTACK_ON)
	assert_true(sp.attack_live, "attack box live on ATTACK_ON frame")
	assert_not_null(sp.active_attack_box)

func test_attack_dies_on_attack_off_frame():
	var sp := SequencePlayer.new()
	sp.play(_two_frame_move())
	# 2 ticks ~= 2/53 s ~= 0.0377s -> ~3 frames at 1/60 to leave frame 0
	for _i in range(4):
		sp.advance(FRAME)
	assert_false(sp.attack_live, "attack dead after ATTACK_OFF frame begins")

func test_sequence_finishes_after_total_duration():
	var sp := SequencePlayer.new()
	sp.play(_two_frame_move())   # 4 ticks total ~= 0.0755s
	var finished := false
	for _i in range(8):
		if sp.advance(FRAME):
			finished = true
	assert_true(finished, "advance() returns true on the frame it completes")
	assert_false(sp.is_playing())

func test_move_sequence_is_grapple_defaults_false():
	var m := MoveSequence.new()
	assert_false(m.is_grapple, "strikes are not grapples by default")
	m.is_grapple = true
	assert_true(m.is_grapple)
