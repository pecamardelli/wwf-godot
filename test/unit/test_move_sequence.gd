extends "res://addons/gut/test.gd"

func test_defaults():
	var m := MoveSequence.new()
	assert_false(m.victim_pop, "victim_pop defaults false")
	assert_eq(m.damage_override, 0, "damage_override defaults 0")
	assert_false(m.locks_victim, "locks_victim defaults false")

func test_headbutt_is_slow_strong_popping():
	var m: MoveSequence = load("res://assets/sequences/doink/headbutt.tres")
	assert_eq(m.attack_mode, AMode.HDBUTT)
	assert_true(m.causes_dizzy)
	assert_true(m.victim_pop, "single low-punch headbutt pops")
	assert_gt(m.damage_override, 12, "stronger than a default headbutt")

func test_headbutt_burst_is_nonpop_dizzy_and_pins():
	var m: MoveSequence = load("res://assets/sequences/doink/headbutt_burst.tres")
	assert_eq(m.attack_mode, AMode.HDBUTT)
	assert_true(m.causes_dizzy)
	assert_false(m.victim_pop, "burst hits do not pop; the ender pop is applied by the chain")
	assert_true(m.locks_victim, "burst hits pin the victim in place")

func test_single_headbutt_does_not_pin():
	var m: MoveSequence = load("res://assets/sequences/doink/headbutt.tres")
	assert_false(m.locks_victim, "the single low-punch headbutt knocks back normally")
