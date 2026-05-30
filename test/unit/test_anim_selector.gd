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

func test_reverse_when_moving_against_facing_right_front():
	# facing right (+1), front (+1, body toward camera/down)
	assert_false(AnimSelector.is_reverse(Vector2(1, 0), 1.0, Facing.FRONT), "walk right = forward")
	assert_true(AnimSelector.is_reverse(Vector2(-1, 0), 1.0, Facing.FRONT), "backpedal left = reverse")
	assert_false(AnimSelector.is_reverse(Vector2(0, 1), 1.0, Facing.FRONT), "down (toward camera) = forward")
	assert_true(AnimSelector.is_reverse(Vector2(0, -1), 1.0, Facing.FRONT), "up (away) while front = reverse")

func test_reverse_depends_on_depth_facing():
	# facing back (away/up): moving down is moving away-from-facing -> reverse; up -> forward
	assert_true(AnimSelector.is_reverse(Vector2(0, 1), 1.0, Facing.BACK), "down while back = reverse")
	assert_false(AnimSelector.is_reverse(Vector2(0, -1), 1.0, Facing.BACK), "up while back = forward")

func test_idle_is_not_reverse():
	assert_false(AnimSelector.is_reverse(Vector2.ZERO, 1.0, Facing.FRONT))
