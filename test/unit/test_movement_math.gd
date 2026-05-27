extends "res://addons/gut/test.gd"

func test_zero_input_gives_zero_velocity():
	assert_eq(MovementMath.move_velocity(Vector2.ZERO, 100.0), Vector2.ZERO)

func test_right_input_gives_rightward_velocity():
	assert_eq(MovementMath.move_velocity(Vector2.RIGHT, 100.0), Vector2(100.0, 0.0))

func test_diagonal_input_is_normalized_to_speed():
	var v: Vector2 = MovementMath.move_velocity(Vector2(1.0, 1.0), 100.0)
	assert_almost_eq(v.length(), 100.0, 0.01)

func test_clamp_below_band_snaps_to_max_y():
	assert_eq(MovementMath.clamp_to_floor(Vector2(50.0, 999.0), 200.0, 400.0), Vector2(50.0, 400.0))

func test_clamp_above_band_snaps_to_min_y():
	assert_eq(MovementMath.clamp_to_floor(Vector2(50.0, 0.0), 200.0, 400.0), Vector2(50.0, 200.0))

func test_clamp_within_band_unchanged():
	assert_eq(MovementMath.clamp_to_floor(Vector2(50.0, 300.0), 200.0, 400.0), Vector2(50.0, 300.0))
