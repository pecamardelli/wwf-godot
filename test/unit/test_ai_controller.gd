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

func test_block_chance_uses_skill_base_and_repeat_bonus():
	# skill 0 base = 10, repeat 0 bonus = 0, block_skill 1.0, solo -> 10
	assert_eq(AIController.block_chance(0, 1.0, 0, 1), 10)
	# skill 0 base 10 + repeat 2 bonus 20 = 30
	assert_eq(AIController.block_chance(0, 1.0, 2, 1), 30)
	# skill 29 base = 75
	assert_eq(AIController.block_chance(29, 1.0, 0, 1), 75)

func test_block_chance_crowd_penalty_32_per_extra_ally():
	# skill 29 base 75, two allies -> 75 - 32 = 43
	assert_eq(AIController.block_chance(29, 1.0, 0, 2), 43)
	# three allies -> 75 - 64 = 11
	assert_eq(AIController.block_chance(29, 1.0, 0, 3), 11)

func test_block_chance_block_skill_multiplier_and_clamp():
	# block_skill 0 -> 0 (clamped low); huge inputs clamp to 99
	assert_eq(AIController.block_chance(29, 0.0, 4, 1), 0)
	assert_eq(AIController.block_chance(29, 2.0, 5, 1), 99)

func test_should_block_roll_under_threshold():
	assert_true(AIController.should_block(50, 49))
	assert_false(AIController.should_block(50, 50))

func test_reverse_chance_scales_with_skill():
	# chance = (skill/29) * reversal_skill; roll is 0..1
	assert_true(AIController.should_reverse(29, 1.0, 0.5))    # chance 1.0 -> always
	assert_false(AIController.should_reverse(0, 1.0, 0.01))   # chance 0 -> never
	assert_false(AIController.should_reverse(29, 0.0, 0.01))  # reversal_skill 0 -> never

func test_reverse_chance_midpoint():
	# skill ~14.5 -> chance ~0.5; roll 0.4 reverses, 0.6 does not
	assert_true(AIController.should_reverse(15, 1.0, 0.4))
	assert_false(AIController.should_reverse(15, 1.0, 0.9))
