extends "res://addons/gut/test.gd"

func test_idle_when_no_movement():
	assert_eq(AnimSelector.walk_anim(Vector2.ZERO, Facing.FRONT), "idle_front")
	assert_eq(AnimSelector.walk_anim(Vector2.ZERO, Facing.BACK), "idle_back")

func test_horizontal_only():
	assert_eq(AnimSelector.walk_anim(Vector2(1, 0), Facing.FRONT), "walk_horisontal_front")
	assert_eq(AnimSelector.walk_anim(Vector2(-1, 0), Facing.BACK), "walk_horisontal_back")

func test_vertical_only():
	assert_eq(AnimSelector.walk_anim(Vector2(0, 1), Facing.FRONT), "walk_vertical_front")
	assert_eq(AnimSelector.walk_anim(Vector2(0, -1), Facing.BACK), "walk_vertical_back")

func test_diagonal():
	assert_eq(AnimSelector.walk_anim(Vector2(1, 1), Facing.FRONT), "walk_diagonal_front")
	assert_eq(AnimSelector.walk_anim(Vector2(-1, -1), Facing.BACK), "walk_diagonal_back")

func test_uses_sign_only():
	assert_eq(AnimSelector.walk_anim(Vector2(0.2, 0.0), Facing.FRONT), "walk_horisontal_front")
