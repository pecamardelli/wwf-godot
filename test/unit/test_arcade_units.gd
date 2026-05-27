extends "res://addons/gut/test.gd"

func test_ticks_to_seconds_uses_53():
	assert_almost_eq(ArcadeUnits.ticks_to_seconds(53.0), 1.0, 0.0001)

func test_vel_hex_to_px_per_sec_walk_cardinal():
	# 0x3a000 = 3.625 px/tick; * 53 ticks/s = 192.125 px/s
	assert_almost_eq(ArcadeUnits.vel_to_px_per_sec(0x3a000), 192.125, 0.01)

func test_vel_hex_to_px_per_sec_run():
	# 0x64000 = 6.25 px/tick; * 53 = 331.25 px/s
	assert_almost_eq(ArcadeUnits.vel_to_px_per_sec(0x64000), 331.25, 0.01)

func test_derived_constants():
	assert_almost_eq(ArcadeUnits.WALK_CARDINAL, 192.125, 0.01)
	assert_almost_eq(ArcadeUnits.WALK_DIAGONAL_AXIS, 162.3125, 0.01)
	assert_almost_eq(ArcadeUnits.RUN_SPEED, 331.25, 0.01)
