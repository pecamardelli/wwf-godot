extends "res://addons/gut/test.gd"
## FlyingKick.gate: any STANDING foe leaps (arcade dnk_2_spin_kick always LEAPATOPPs); only a downed
## foe stays grounded (stomp branch).

func test_far_standing_foe_triggers():
	assert_true(FlyingKick.gate(Vector2(0, 400), Vector2(120, 400), Fighter.Mode.NORMAL))

func test_close_standing_foe_also_leaps():
	# dx 40 (close): the arcade still leaps (short "close super" hop), so the kick jumps a little.
	assert_true(FlyingKick.gate(Vector2(0, 400), Vector2(40, 400), Fighter.Mode.NORMAL))

func test_point_blank_standing_foe_leaps():
	assert_true(FlyingKick.gate(Vector2(0, 400), Vector2(0, 400), Fighter.Mode.NORMAL))

func test_downed_foe_rejects():
	# ONGROUND -> arcade routes to the stomp branch, never the flying kick.
	assert_false(FlyingKick.gate(Vector2(0, 400), Vector2(120, 400), Fighter.Mode.ONGROUND))
