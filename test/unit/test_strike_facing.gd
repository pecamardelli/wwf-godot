extends "res://addons/gut/test.gd"
## Tests that _play_sequence_anim() picks the back-facing clip when _depth_facing == BACK.

const FIGHTER_SCENE_SF := preload("res://scenes/Fighter.tscn")

func _spawn_fighter() -> Fighter:
	var f: Fighter = FIGHTER_SCENE_SF.instantiate()
	add_child_autofree(f)
	f.global_position = Vector2(100, 400)
	f.separation_radii = Vector2.ZERO
	return f

func test_strike_plays_back_clip_when_facing_back():
	var f := _spawn_fighter()
	f._depth_facing = Facing.BACK
	f.start_move(load("res://assets/sequences/doink/punch.tres"))
	f._play_sequence_anim()
	assert_eq(f.sprite.animation, "mid_punch_back", "back-facing punch uses the back clip")

func test_strike_plays_front_clip_when_facing_front():
	var f := _spawn_fighter()
	f._depth_facing = Facing.FRONT
	f.start_move(load("res://assets/sequences/doink/punch.tres"))
	f._play_sequence_anim()
	assert_eq(f.sprite.animation, "mid_punch_front", "front-facing punch uses the front clip")

func test_strike_without_back_variant_falls_back_to_front():
	var f := _spawn_fighter()
	f._depth_facing = Facing.BACK
	f.start_move(load("res://assets/sequences/doink/uppercut.tres"))
	f._play_sequence_anim()
	assert_eq(f.sprite.animation, "uppercut", "no back clip -> front clip is used for both")
