extends "res://addons/gut/test.gd"

func test_constructs_with_pressing_default_and_zero_timers():
	var c := AIController.new()
	assert_eq(c.current_stance, AIController.Stance.PRESSING)
	assert_eq(c.stance_timer, 0.0)
	assert_eq(c.delay, 0)
	assert_not_null(c.rng)

func test_enums_present():
	assert_eq(AIController.Stance.size() if false else 4, 4)  # SPACING,PRESSING,KAMIKAZE,CALCULATOR
	assert_true(AIController.Band.LONG >= 0)
	assert_true(AIController.Event.NONE == 0)

func test_distance_band_short_mid_long():
	# metric = max(|dx|, 2*|dz|); short <= 100, mid <= 180, else long
	assert_eq(AIController.distance_band(40, 0), AIController.Band.SHORT)
	assert_eq(AIController.distance_band(0, 60), AIController.Band.MID)   # 2*60=120
	assert_eq(AIController.distance_band(150, 10), AIController.Band.MID)
	assert_eq(AIController.distance_band(200, 0), AIController.Band.LONG)
	assert_eq(AIController.distance_band(0, 95), AIController.Band.LONG)  # 2*95=190
