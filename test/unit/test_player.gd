extends "res://addons/gut/test.gd"

func test_player_is_a_fighter():
	var p := Player.new()
	add_child_autofree(p)
	assert_true(p is Fighter, "Player extends Fighter")

func test_prefix_follows_player_index():
	var p := Player.new()
	add_child_autofree(p)
	p.player_index = 0
	assert_eq(p._action_prefix(), "p1_")
	p.player_index = 1
	assert_eq(p._action_prefix(), "p2_")

func test_no_input_gives_zero_direction():
	var p := Player.new()
	add_child_autofree(p)
	assert_eq(p.get_input_direction(), Vector2.ZERO, "no keys pressed -> no movement")
