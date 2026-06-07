extends "res://addons/gut/test.gd"
## Vertical-axis constants derived straight from the arcade hex (wrestler_veladd).

func test_accel_helper_scales_by_ticks_squared():
	# 0x08000 = 0.5 px/tick^2 -> 0.5 * 53^2 px/s^2.
	assert_almost_eq(ArcadeUnits.accel_to_px_per_sec2(0x08000), 0.5 * 53.0 * 53.0, 0.01)

func test_gravity_constant_matches_arcade_hex():
	# GAME.EQU:436 GRAVITY = 0x08000.
	assert_almost_eq(ArcadeUnits.GRAVITY, ArcadeUnits.accel_to_px_per_sec2(0x08000), 0.01)

func test_max_fall_matches_arcade_hex():
	# WRESTLE2.ASM:2280 MAX_YVEL = -0x1000000 (a velocity).
	assert_almost_eq(ArcadeUnits.MAX_FALL, -ArcadeUnits.vel_to_px_per_sec(0x1000000), 0.01)

func test_flykick_launch_matches_arcade_hex():
	# DNKSEQ2.ASM:902 LEAPATOPP hiYvel = 0x90000.
	assert_almost_eq(ArcadeUnits.FLYKICK_YVEL, ArcadeUnits.vel_to_px_per_sec(0x90000), 0.01)

func test_clothesline_launch_matches_arcade_hex():
	# DNKSEQ2.ASM:2401-2402 ANI_SET_YVEL 0x64000 / ANI_SET_XVEL 0x5c000.
	assert_almost_eq(ArcadeUnits.CLINE_YVEL, ArcadeUnits.vel_to_px_per_sec(0x64000), 0.01)
	assert_almost_eq(ArcadeUnits.CLINE_XVEL, ArcadeUnits.vel_to_px_per_sec(0x5c000), 0.01)
