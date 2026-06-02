extends "res://addons/gut/test.gd"

func test_punch_maps_to_head_hit():
	assert_eq(AMode.reaction_for(AMode.PUNCH), AMode.Family.HEAD_HIT)

func test_kick_maps_to_body_hit():
	assert_eq(AMode.reaction_for(AMode.KICK), AMode.Family.BODY_HIT)

func test_bigboot_is_a_knockdown():
	assert_eq(AMode.reaction_for(AMode.BIGBOOT), AMode.Family.KNOCKDOWN)

func test_uppercut_falls_back():
	assert_eq(AMode.reaction_for(AMode.UPRCUT), AMode.Family.FALL_BACK)

func test_knockdown_getup_is_near_instant_genesis_override():
	# Genesis override: arcade STAY_TIME (270) is NOT ported (no recovery system); fighters pop up
	# almost instantly, with just a small beat before the getup rise.
	assert_eq(AMode.getup_ticks(AMode.Family.KNOCKDOWN), 12)

func test_most_moves_get_right_up():
	assert_eq(AMode.getup_ticks(AMode.Family.HEAD_HIT), 0)

func test_new_strike_modes_have_reaction_families():
	assert_eq(AMode.reaction_for(AMode.SLAP), AMode.Family.HEAD_HIT)
	assert_eq(AMode.reaction_for(AMode.SPINKICK), AMode.Family.STAGGER)
	assert_eq(AMode.reaction_for(AMode.EARSLAP), AMode.Family.HEAD_HIT)
	assert_eq(AMode.reaction_for(AMode.HAMMER), AMode.Family.KNOCKDOWN)
	assert_eq(AMode.reaction_for(AMode.BOXGLOVE), AMode.Family.KNOCKDOWN)
