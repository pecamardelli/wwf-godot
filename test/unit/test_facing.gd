extends "res://addons/gut/test.gd"

func test_state_of_maps_four_corners():
	assert_eq(Facing.state_of(1.0, Facing.FRONT), Facing.State.FR)
	assert_eq(Facing.state_of(1.0, Facing.BACK), Facing.State.BR)
	assert_eq(Facing.state_of(-1.0, Facing.BACK), Facing.State.BL)
	assert_eq(Facing.state_of(-1.0, Facing.FRONT), Facing.State.FL)

func test_horizontal_of_state():
	assert_eq(Facing.horizontal_of(Facing.State.FR), 1.0)
	assert_eq(Facing.horizontal_of(Facing.State.BR), 1.0)
	assert_eq(Facing.horizontal_of(Facing.State.BL), -1.0)
	assert_eq(Facing.horizontal_of(Facing.State.FL), -1.0)

func test_depth_of_state():
	assert_eq(Facing.depth_of(Facing.State.FR), Facing.FRONT)
	assert_eq(Facing.depth_of(Facing.State.FL), Facing.FRONT)
	assert_eq(Facing.depth_of(Facing.State.BR), Facing.BACK)
	assert_eq(Facing.depth_of(Facing.State.BL), Facing.BACK)

func test_desired_depth_front_when_opponent_nearer_camera():
	# larger screen Y = nearer the camera = FRONT
	assert_eq(Facing.desired_depth(400.0, 500.0), Facing.FRONT)
	assert_eq(Facing.desired_depth(400.0, 300.0), Facing.BACK)

func test_desired_depth_hysteresis_keeps_current_inside_deadzone():
	assert_eq(Facing.desired_depth(400.0, 410.0, Facing.BACK, 24.0), Facing.BACK)
	assert_eq(Facing.desired_depth(400.0, 430.0, Facing.BACK, 24.0), Facing.FRONT)
	assert_eq(Facing.desired_depth(400.0, 370.0, Facing.FRONT, 24.0), Facing.BACK)
