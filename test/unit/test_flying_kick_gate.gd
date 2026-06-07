extends "res://addons/gut/test.gd"
## FlyingKick.gate: standing foe OUTSIDE the 60x60 close box -> flying kick (arcade #super_kick).

func test_far_standing_foe_triggers():
	# dx 120 (>= 60) -> outside the close box -> flying kick.
	assert_true(FlyingKick.gate(Vector2(0, 400), Vector2(120, 400), Fighter.Mode.NORMAL))

func test_close_foe_within_box_rejects():
	# dx 40, dz 0 -> within 60x60 -> close super (not a flying kick).
	assert_false(FlyingKick.gate(Vector2(0, 400), Vector2(40, 400), Fighter.Mode.NORMAL))

func test_far_in_depth_only_triggers():
	# dx 0 but dz 80 (>= 60) -> outside the box (OR semantics) -> flying kick.
	assert_true(FlyingKick.gate(Vector2(0, 400), Vector2(0, 480), Fighter.Mode.NORMAL))

func test_downed_foe_rejects():
	# ONGROUND -> arcade routes to the stomp branch, never the flying kick.
	assert_false(FlyingKick.gate(Vector2(0, 400), Vector2(120, 400), Fighter.Mode.ONGROUND))
