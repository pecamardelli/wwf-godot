extends "res://addons/gut/test.gd"

const FRAME := 1.0 / 60.0

func test_fighter_defaults_to_player_side():
	var f := Fighter.new()
	add_child_autofree(f)
	assert_eq(f.side, Fighter.Side.PLAYER)

func test_is_dead_when_health_zero():
	var f := Fighter.new()
	add_child_autofree(f)
	assert_false(f.is_dead())
	f.health = 0
	assert_true(f.is_dead())
