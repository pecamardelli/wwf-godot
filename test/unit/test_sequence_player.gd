extends "res://addons/gut/test.gd"

func test_punch_sequence_loads_and_has_an_attack_window():
	var m: MoveSequence = load("res://assets/sequences/doink/punch.tres")
	assert_not_null(m, "punch.tres loads")
	assert_eq(m.attack_mode, AMode.PUNCH)
	var has_on := false
	var has_off := false
	for f in m.frames:
		if f.command == 2: has_on = true
		if f.command == 3: has_off = true
	assert_true(has_on and has_off, "has ATTACK_ON and ATTACK_OFF frames")

func test_headbutt_causes_dizzy():
	var m: MoveSequence = load("res://assets/sequences/doink/headbutt.tres")
	assert_true(m.causes_dizzy)
