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
