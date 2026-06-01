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

func test_limb_bias_picks_kick_vs_punch():
	# roll < limb_bias -> kick family, else punch family
	assert_eq(AIController.pick_strike_button(0.8, 0.1), MoveTable.Btn.LOW_KICK)
	assert_eq(AIController.pick_strike_button(0.8, 0.9), MoveTable.Btn.LOW_PUNCH)
	assert_eq(AIController.pick_strike_button(0.0, 0.5), MoveTable.Btn.LOW_PUNCH)  # always fists
	assert_eq(AIController.pick_strike_button(1.0, 0.5), MoveTable.Btn.LOW_KICK)   # always legs

func test_attack_prob_long_band_never_attacks():
	for st in [AIController.Stance.SPACING, AIController.Stance.PRESSING,
			AIController.Stance.KAMIKAZE, AIController.Stance.CALCULATOR]:
		assert_eq(AIController.attack_prob(st, AIController.Band.LONG), 0.0)

func test_attack_prob_kamikaze_higher_than_spacing_in_short():
	var kam := AIController.attack_prob(AIController.Stance.KAMIKAZE, AIController.Band.SHORT)
	var spc := AIController.attack_prob(AIController.Stance.SPACING, AIController.Band.SHORT)
	assert_gt(kam, spc)

func test_choose_action_idle_when_attack_roll_above_prob():
	# PRESSING short prob < 1.0; roll_attack 1.0 -> never attacks -> IDLE
	assert_eq(AIController.choose_action(AIController.Stance.PRESSING, 0.5, AIController.Band.SHORT, 1.0, 0.0),
		AIIntent.Action.IDLE)

func test_choose_action_grab_vs_strike_by_special_frequency():
	# attack happens (roll_attack 0.0); special_frequency 1.0 + any roll_kind -> GRAB
	assert_eq(AIController.choose_action(AIController.Stance.PRESSING, 1.0, AIController.Band.SHORT, 0.0, 0.5),
		AIIntent.Action.GRAB)
	# special_frequency 0.0 -> STRIKE
	assert_eq(AIController.choose_action(AIController.Stance.PRESSING, 0.0, AIController.Band.SHORT, 0.0, 0.5),
		AIIntent.Action.STRIKE)

func test_choose_action_grab_only_in_short_band():
	# grapples need to be close: MID band with special_frequency 1.0 still STRIKEs
	assert_eq(AIController.choose_action(AIController.Stance.PRESSING, 1.0, AIController.Band.MID, 0.0, 0.0),
		AIIntent.Action.STRIKE)

func test_desired_distance_by_preferred_range_then_stance():
	# CLOSE base small; SPACING/CALCULATOR push it out; KAMIKAZE rushes to ~0
	var close_press := AIController.desired_distance(AIController.Stance.PRESSING, AIProfile.PreferredRange.CLOSE)
	var close_space := AIController.desired_distance(AIController.Stance.SPACING, AIProfile.PreferredRange.CLOSE)
	var close_kam := AIController.desired_distance(AIController.Stance.KAMIKAZE, AIProfile.PreferredRange.CLOSE)
	assert_gt(close_space, close_press)
	assert_lt(close_kam, close_press)

func test_seek_dir_moves_toward_when_too_far():
	# self at 0, target at +300 x, desired 40 -> move +x (toward)
	var d := AIController.seek_dir(0, 0, 300, 0, 40.0)
	assert_gt(d.x, 0.0)

func test_seek_dir_backs_off_when_too_close():
	# self at 0, target at +20 x, desired 100 -> move -x (away)
	var d := AIController.seek_dir(0, 0, 20, 0, 100.0)
	assert_lt(d.x, 0.0)

func test_seek_dir_holds_inside_deadzone():
	var d := AIController.seek_dir(0, 0, 42, 0, 40.0)  # within deadzone of desired
	assert_eq(d, Vector2.ZERO)
