extends "res://addons/gut/test.gd"

func test_sandbox_loads_with_two_players():
	var scene: PackedScene = load("res://scenes/Sandbox.tscn")
	assert_not_null(scene, "Sandbox.tscn should load")
	var root: Node = scene.instantiate()
	add_child_autofree(root)
	assert_true(root.y_sort_enabled, "Sandbox has Y-sort enabled")
	var p1: Node = root.get_node_or_null("Player1")
	var p2: Node = root.get_node_or_null("Player2")
	assert_true(p1 is Player, "Player1 is a Player")
	assert_true(p2 is Player, "Player2 is a Player")
	assert_eq(p1.player_index, 0, "Player1 uses p1_* actions")
	assert_eq(p2.player_index, 1, "Player2 uses p2_* actions")
