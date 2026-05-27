extends "res://addons/gut/test.gd"

func test_fighter_scene_instantiates_as_fighter():
	var packed: PackedScene = load("res://scenes/Fighter.tscn")
	assert_not_null(packed, "Fighter.tscn should load")
	var f: Node = packed.instantiate()
	add_child_autofree(f)
	assert_true(f is Fighter, "root should be a Fighter")
	assert_not_null(f.get_node_or_null("AnimatedSprite2D"), "has AnimatedSprite2D child")
	assert_not_null(f.get_node_or_null("CollisionShape2D"), "has CollisionShape2D child")
