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

func test_fall_orientation_defaults_face_up():
	assert_eq(Reaction.fall_orientation(AMode.Family.KNOCKDOWN, "big_boot"), Fighter.Fall.FACE_UP)
	assert_eq(Reaction.fall_orientation(AMode.Family.FALL_BACK, "uppercut"), Fighter.Fall.FACE_UP)

func test_fall_orientation_roll_moves_are_face_down_roll():
	# NOTE: "faceslam"/"flying_clothesline" are FORWARD-LOOKING ids not yet wired as moves,
	# so this verifies the lookup logic only — no shipping move produces a face-down getup yet.
	assert_eq(Reaction.fall_orientation(AMode.Family.KNOCKDOWN, "faceslam"), Fighter.Fall.FACE_DOWN_ROLL)
	assert_eq(Reaction.fall_orientation(AMode.Family.KNOCKDOWN, "flying_clothesline"), Fighter.Fall.FACE_DOWN_ROLL)
