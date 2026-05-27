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

func test_no_separation_push_when_far_apart():
	assert_eq(MovementMath.separation_push(Vector2(0, 0), Vector2(200, 0), Vector2(60, 60)), Vector2.ZERO)

func test_separation_push_is_half_the_overlap():
	# 40 apart on x, radius 60 -> this body takes half the closing distance (10) along +x
	var p: Vector2 = MovementMath.separation_push(Vector2(40, 0), Vector2(0, 0), Vector2(60, 60))
	assert_almost_eq(p.x, 10.0, 0.01)
	assert_almost_eq(p.y, 0.0, 0.01)

func test_separation_push_points_away_from_other():
	var p: Vector2 = MovementMath.separation_push(Vector2(0, 0), Vector2(40, 0), Vector2(60, 60))
	assert_true(p.x < 0.0, "self left of other pushes left")

func test_exact_overlap_gives_nonzero_push():
	var p: Vector2 = MovementMath.separation_push(Vector2(0, 0), Vector2(0, 0), Vector2(60, 60))
	assert_gt(p.length(), 0.0, "fully overlapping bodies still separate")

func test_small_depth_radius_allows_closer_on_y_than_x():
	# depth (y) radius 20: bodies 40 apart on y are outside tolerance -> no push
	assert_eq(MovementMath.separation_push(Vector2(0, 40), Vector2(0, 0), Vector2(60, 20)), Vector2.ZERO)
	# same 40 apart on x with x-radius 60 -> still overlapping -> pushes
	assert_gt(MovementMath.separation_push(Vector2(40, 0), Vector2(0, 0), Vector2(60, 20)).length(), 0.0)
