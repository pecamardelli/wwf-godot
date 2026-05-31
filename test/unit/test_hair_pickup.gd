extends "res://addons/gut/test.gd"
## HairPickup.gate: ONGROUND + |dx|>=32 + opposite facing (at the head) -> true.

func test_aligned_at_head_triggers():
	# dx 50 >= 32, attacker faces right (+1), victim faces left (-1) = opposite = head side.
	assert_true(HairPickup.gate(100, 1.0, 150, -1.0, Fighter.Mode.ONGROUND))

func test_too_close_rejects():
	# dx 20 < 32 -> elbow drop wins (the `jrlt #no` case).
	assert_false(HairPickup.gate(100, 1.0, 120, -1.0, Fighter.Mode.ONGROUND))

func test_boundary_32_triggers():
	# dx exactly 32: arcade `jrlt` rejects strictly < 32, so >= 32 passes.
	assert_true(HairPickup.gate(100, 1.0, 132, -1.0, Fighter.Mode.ONGROUND))

func test_same_facing_at_feet_rejects():
	# Same facing = attacker at the feet -> elbow drop.
	assert_false(HairPickup.gate(100, 1.0, 150, 1.0, Fighter.Mode.ONGROUND))

func test_standing_victim_rejects():
	assert_false(HairPickup.gate(100, 1.0, 150, -1.0, Fighter.Mode.NORMAL))

func test_held_victim_rejects():
	assert_false(HairPickup.gate(100, 1.0, 150, -1.0, Fighter.Mode.HEADHELD))

func test_symmetric_from_the_left():
	# Attacker on the right facing left (-1), victim faces right (+1) = opposite, dx 50.
	assert_true(HairPickup.gate(200, -1.0, 150, 1.0, Fighter.Mode.ONGROUND))

func test_threshold_is_the_arcade_value():
	assert_eq(HairPickup.HEAD_REACH_MIN, 32.0)
