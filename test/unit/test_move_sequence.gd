extends "res://addons/gut/test.gd"

func test_defaults():
	var m := MoveSequence.new()
	assert_false(m.victim_pop, "victim_pop defaults false")
	assert_eq(m.damage_override, 0, "damage_override defaults 0")
