extends "res://addons/gut/test.gd"

# Ported from GMS update_sprites. facing +1 = right; depth FRONT (+1) / BACK (-1).

func test_idle_when_no_movement():
	assert_eq(AnimSelector.select(Vector2.ZERO, 1.0, Facing.FRONT).anim, "idle_front")
	assert_eq(AnimSelector.select(Vector2.ZERO, 1.0, Facing.BACK).anim, "idle_back")
	assert_false(AnimSelector.select(Vector2.ZERO, 1.0, Facing.FRONT).reverse)

func test_pure_horizontal_reverse_on_backpedal():
	var fwd: Dictionary = AnimSelector.select(Vector2(1, 0), 1.0, Facing.FRONT)
	assert_eq(fwd.anim, "walk_horisontal_front")
	assert_false(fwd.reverse, "walking right while facing right = forward")
	assert_true(AnimSelector.select(Vector2(-1, 0), 1.0, Facing.FRONT).reverse, "backpedal left = reverse")
	assert_eq(AnimSelector.select(Vector2(-1, 0), 1.0, Facing.BACK).anim, "walk_horisontal_back")

func test_pure_vertical_reverse_depends_on_depth():
	# FRONT (body toward camera/down): down = forward, up = reverse
	assert_eq(AnimSelector.select(Vector2(0, 1), 1.0, Facing.FRONT).anim, "walk_vertical_front")
	assert_false(AnimSelector.select(Vector2(0, 1), 1.0, Facing.FRONT).reverse)
	assert_true(AnimSelector.select(Vector2(0, -1), 1.0, Facing.FRONT).reverse)
	# BACK (body away/up): up = forward, down = reverse
	assert_eq(AnimSelector.select(Vector2(0, -1), 1.0, Facing.BACK).anim, "walk_vertical_back")
	assert_false(AnimSelector.select(Vector2(0, -1), 1.0, Facing.BACK).reverse)
	assert_true(AnimSelector.select(Vector2(0, 1), 1.0, Facing.BACK).reverse)

func test_diagonal_clip_used_only_on_its_own_axis():
	# facing right, FRONT: the diagonal sprite's axis is up-right / down-left.
	var ur: Dictionary = AnimSelector.select(Vector2(1, -1), 1.0, Facing.FRONT)  # up-right
	assert_eq(ur.anim, "walk_diagonal_front")
	assert_false(ur.reverse)
	var dl: Dictionary = AnimSelector.select(Vector2(-1, 1), 1.0, Facing.FRONT)  # down-left
	assert_eq(dl.anim, "walk_diagonal_front")
	assert_true(dl.reverse)

func test_perpendicular_diagonal_falls_back_to_horizontal():
	# facing right, FRONT: down-right and up-left are NOT the diagonal sprite's axis -> horizontal
	assert_eq(AnimSelector.select(Vector2(1, 1), 1.0, Facing.FRONT).anim, "walk_horisontal_front")
	assert_eq(AnimSelector.select(Vector2(-1, -1), 1.0, Facing.FRONT).anim, "walk_horisontal_front")

func test_uses_sign_only():
	assert_eq(AnimSelector.select(Vector2(0.2, 0.0), 1.0, Facing.FRONT).anim, "walk_horisontal_front")
