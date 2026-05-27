extends "res://addons/gut/test.gd"

func test_fighter_scene_instantiates_as_fighter():
	var packed: PackedScene = load("res://scenes/Fighter.tscn")
	assert_not_null(packed, "Fighter.tscn should load")
	var f: Node = packed.instantiate()
	add_child_autofree(f)
	assert_true(f is Fighter, "root should be a Fighter")
	assert_not_null(f.get_node_or_null("AnimatedSprite2D"), "has AnimatedSprite2D child")
	assert_not_null(f.get_node_or_null("CollisionShape2D"), "has CollisionShape2D child")

func test_fighter_has_idle_and_walk_animations():
	var f: Node = load("res://scenes/Fighter.tscn").instantiate()
	add_child_autofree(f)
	var spr: AnimatedSprite2D = f.get_node("AnimatedSprite2D")
	assert_not_null(spr.sprite_frames, "AnimatedSprite2D has SpriteFrames")
	assert_true(spr.sprite_frames.has_animation("idle"), "has 'idle' animation")
	assert_true(spr.sprite_frames.has_animation("walk"), "has 'walk' animation")
	assert_eq(spr.sprite_frames.get_frame_count("walk"), 18, "walk has 18 frames")
