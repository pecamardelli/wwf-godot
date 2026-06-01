extends "res://addons/gut/test.gd"

func test_defaults_are_in_range():
	var p := AIProfile.new()
	assert_between(p.skill, 0, 29)
	assert_between(p.aggression, 0.0, 1.0)
	assert_between(p.limb_bias, 0.0, 1.0)
	assert_eq(p.preferred_range, AIProfile.PreferredRange.CLOSE)
	assert_true(p.reaction_delay.x <= p.reaction_delay.y)

func test_stance_config_assignable():
	var p := AIProfile.new()
	p.enabled_stances = [AIController.Stance.PRESSING, AIController.Stance.SPACING]
	p.stance_weights = {AIController.Stance.PRESSING: 3.0, AIController.Stance.SPACING: 1.0}
	assert_eq(p.stance_weights[AIController.Stance.PRESSING], 3.0)
	assert_eq(p.enabled_stances.size(), 2)

func test_basic_doink_loads_with_expected_personality():
	var p: AIProfile = load("res://assets/ai_profiles/basic_doink.tres")
	assert_not_null(p)
	assert_between(p.skill, 0, 12)                       # a beatable first opponent
	assert_true(p.enabled_stances.has(AIController.Stance.PRESSING))
	assert_true(p.enabled_stances.has(AIController.Stance.SPACING))
	# PRESSING is the dominant mood
	var press_w: float = p.stance_weights.get(AIController.Stance.PRESSING, 0.0)
	for st in p.enabled_stances:
		assert_true(press_w >= float(p.stance_weights.get(st, 0.0)))
