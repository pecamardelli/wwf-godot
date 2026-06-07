extends "res://addons/gut/test.gd"
## AerialLaunch.leap_velocity: planar velocity to reach `to` from `from` in `seconds`,
## clamped per-axis. Mirrors arcade LEAPATOPP (ANIM.EQU:156).

func test_reaches_target_in_time_when_under_cap():
	# 200px in 0.5s = 400 px/s, under a 999 cap -> exact.
	var v := AerialLaunch.leap_velocity(Vector2(0, 0), Vector2(200, 0), 0.5, 9999.0, 9999.0)
	assert_almost_eq(v.x, 400.0, 0.01)
	assert_almost_eq(v.y, 0.0, 0.01)

func test_clamps_to_per_axis_cap():
	# 1000px in 0.1s = 10000 px/s, capped at 477.
	var v := AerialLaunch.leap_velocity(Vector2(0, 0), Vector2(1000, 0), 0.1, 477.0, 477.0)
	assert_almost_eq(v.x, 477.0, 0.01)

func test_negative_direction_keeps_sign_under_cap():
	var v := AerialLaunch.leap_velocity(Vector2(300, 0), Vector2(0, 0), 0.5, 9999.0, 9999.0)
	assert_almost_eq(v.x, -600.0, 0.01)

func test_depth_axis_independent():
	var v := AerialLaunch.leap_velocity(Vector2(0, 100), Vector2(0, 160), 0.5, 9999.0, 9999.0)
	assert_almost_eq(v.x, 0.0, 0.01)
	assert_almost_eq(v.y, 120.0, 0.01)

func test_zero_time_yields_zero():
	var v := AerialLaunch.leap_velocity(Vector2(0, 0), Vector2(200, 0), 0.0, 999.0, 999.0)
	assert_eq(v, Vector2.ZERO)
