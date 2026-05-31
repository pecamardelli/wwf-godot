extends "res://addons/gut/test.gd"

func test_fighter_scene_instantiates_as_fighter():
	var packed: PackedScene = load("res://scenes/Fighter.tscn")
	assert_not_null(packed, "Fighter.tscn should load")
	var f: Node = packed.instantiate()
	add_child_autofree(f)
	assert_true(f is Fighter, "root should be a Fighter")
	assert_not_null(f.get_node_or_null("AnimatedSprite2D"), "has AnimatedSprite2D child")
	assert_not_null(f.get_node_or_null("CollisionShape2D"), "has CollisionShape2D child")

func test_fighter_has_core_doink_animations():
	var f: Node = load("res://scenes/Fighter.tscn").instantiate()
	add_child_autofree(f)
	var spr: AnimatedSprite2D = f.get_node("AnimatedSprite2D")
	assert_not_null(spr.sprite_frames, "AnimatedSprite2D has SpriteFrames")
	for anim in ["idle_front", "walk_horisontal_front", "mid_punch_front", "mid_kick_front", "big_boot"]:
		assert_true(spr.sprite_frames.has_animation(anim), "has animation: " + anim)

func test_fighters_do_not_block_each_other():
	# Co-op partners overlap freely; depth-sort handles ordering.
	var f: CharacterBody2D = load("res://scenes/Fighter.tscn").instantiate()
	add_child_autofree(f)
	assert_eq(f.collision_mask, 0, "Fighter collides with nothing (no body blocking)")

func test_sandbox_player1_has_motion_registry():
	var scene: Node = load("res://scenes/Sandbox.tscn").instantiate()
	add_child_autofree(scene)
	var p1: Player = scene.get_node("Player1")
	assert_not_null(p1, "Sandbox has Player1")
	assert_not_null(p1.motions, "Player1 has a grapple MotionTable assigned")
	assert_eq(p1.motions.lookup("hip_toss").id, "hip_toss", "registry maps the hip toss")
	# 3 grab initiators + 3 secret-move strikes (hammer, ear_slap, boxing_glove).
	assert_eq(p1.motions.moves().size(), 6, "registry has 6 entries (3 initiators + 3 secret strikes)")

func test_new_doink_strike_sequences_load():
	for id in ["knee", "stomp", "elbow_drop", "slap", "spin_kick"]:
		var seq: MoveSequence = load("res://assets/sequences/doink/%s.tres" % id)
		assert_not_null(seq, "%s.tres loads" % id)
		assert_eq(seq.id, id)
		assert_gt(seq.frames.size(), 0, "%s has frames" % id)
