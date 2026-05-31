extends "res://addons/gut/test.gd"

func test_within_when_both_axes_inside():
	assert_true(Proximity.is_within(Vector2(100, 400), Vector2(140, 430), 50, 45))

func test_not_within_when_x_exceeds():
	assert_false(Proximity.is_within(Vector2(100, 400), Vector2(160, 400), 50, 45))

func test_not_within_when_z_exceeds():
	assert_false(Proximity.is_within(Vector2(100, 400), Vector2(100, 460), 50, 45))

func test_boundary_is_inclusive():
	assert_true(Proximity.is_within(Vector2(0, 0), Vector2(50, 45), 50, 45))

func test_symmetric_in_argument_order():
	# |Δ| means b-left-of-a is the same as b-right-of-a (guards a future sign flip).
	assert_true(Proximity.is_within(Vector2(150, 400), Vector2(110, 370), 50, 45))
	assert_false(Proximity.is_within(Vector2(150, 400), Vector2(90, 400), 50, 45))

func test_thresholds_are_the_arcade_values():
	assert_eq(Proximity.CLOSE_DX, 50.0)
	assert_eq(Proximity.CLOSE_DZ, 45.0)
	assert_eq(Proximity.GROUNDED_DX, 120.0)
	assert_eq(Proximity.GROUNDED_DZ, 120.0)
