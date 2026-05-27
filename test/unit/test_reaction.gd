extends "res://addons/gut/test.gd"

func test_head_hit_stays_standing_and_plays_facepunched():
	var r := Reaction.resolve(AMode.Family.HEAD_HIT, 1, false)  # side +1 (front)
	assert_eq(r.anim, "facepunched_front")
	assert_eq(r.mode, Fighter.Mode.NORMAL)
	assert_eq(r.getup_ticks, 0)

func test_knockdown_goes_onground_with_long_getup():
	var r := Reaction.resolve(AMode.Family.KNOCKDOWN, 1, false)
	assert_eq(r.mode, Fighter.Mode.ONGROUND)
	assert_eq(r.getup_ticks, 270)
	assert_eq(r.anim, "droped")

func test_dizzy_overrides_to_stuned():
	var r := Reaction.resolve(AMode.Family.HEAD_HIT, 1, true)   # causes_dizzy = true
	assert_eq(r.mode, Fighter.Mode.DIZZY)
	assert_eq(r.anim, "stuned")
	assert_eq(r.getup_ticks, 120)

func test_back_side_uses_back_anim():
	var r := Reaction.resolve(AMode.Family.HEAD_HIT, -1, false)
	assert_eq(r.anim, "facepunched_back")

func test_block_plays_defence():
	var r := Reaction.resolve(AMode.Family.BLOCK, 1, false)
	assert_eq(r.anim, "defence")
	assert_eq(r.mode, Fighter.Mode.BLOCK)
