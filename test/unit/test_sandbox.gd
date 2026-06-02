extends "res://addons/gut/test.gd"

func test_sandbox_loads_with_player_and_two_enemies():
	var scene: PackedScene = load("res://scenes/Sandbox.tscn")
	assert_not_null(scene, "Sandbox.tscn should load")
	var root: Node = scene.instantiate()
	add_child_autofree(root)
	assert_true(root.y_sort_enabled, "Sandbox has Y-sort enabled")
	var p1: Node = root.get_node_or_null("Player1")
	assert_true(p1 is Player, "Player1 is a Player")
	assert_eq(p1.player_index, 0, "Player1 uses p1_* actions")
	# Player1 fights two AI enemies (the old idle co-op Player2 is now a second Enemy).
	var enemies := 0
	for child in root.get_children():
		if child is Enemy:
			enemies += 1
	assert_eq(enemies, 2, "Sandbox pits the player against two AI enemies")
