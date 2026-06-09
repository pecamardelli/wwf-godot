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

# --- Bug fix: a homing leap must land ON the target, not ~3x past it ---
# airtime_seconds is the real gravity arc; sizing the planar velocity to it means the leap
# covers exactly the distance to the target over the WHOLE flight (the old code sized it to an
# unrelated leap_ticks window, so the kick sailed far past the foe).
func test_airtime_is_the_full_gravity_arc():
	# up at yvel, back to launch height: t = 2*yvel/gravity.
	assert_almost_eq(AerialLaunch.airtime_seconds(477.0, 1404.5), 2.0 * 477.0 / 1404.5, 0.0001)

func test_airtime_guards_against_bad_input():
	assert_eq(AerialLaunch.airtime_seconds(0.0, 1404.5), 0.0)
	assert_eq(AerialLaunch.airtime_seconds(477.0, 0.0), 0.0)

func test_homing_leap_lands_on_target_over_the_full_arc():
	var to := Vector2(120, 0)   # within cap
	var t := AerialLaunch.airtime_seconds(ArcadeUnits.FLYKICK_YVEL, ArcadeUnits.GRAVITY)
	var v := AerialLaunch.leap_velocity(Vector2.ZERO, to, t, 9999.0, 9999.0)
	# planar distance travelled over the whole flight == distance to the target (no overshoot).
	assert_almost_eq(v.x * t, 120.0, 0.5, "lands on the target, not past it")

# --- Bug fix: the flying clothesline must use its OWN clip, not the boxing-glove placeholder ---
func test_flying_clothesline_uses_its_own_animation():
	var seq: MoveSequence = load("res://assets/sequences/doink/flying_clothesline.tres")
	assert_eq(seq.anim_name, "flying_clothesline", "body-check clip, not the boxing-glove smash")

# --- Bug fix: the flying clothesline lands FLAT and gets up (does not snap to a standing idle) ---
func test_flying_clothesline_lands_prone():
	var seq: MoveSequence = load("res://assets/sequences/doink/flying_clothesline.tres")
	assert_true(seq.lands_prone, "clothesline body-check ends on the mat, then gets up")

func test_flying_kick_does_not_land_prone():
	var seq: MoveSequence = load("res://assets/sequences/doink/flying_kick.tres")
	assert_false(seq.lands_prone, "the flying kick recovers on its feet")
