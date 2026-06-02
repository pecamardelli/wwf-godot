extends "res://addons/gut/test.gd"

func test_announcer_categories_above_voice_range_and_distinct():
	# voice/event cats are 100-103; announcer cats live at 200+ (no collision).
	assert_gt(SoundCategory.ANNC_IMPRESSIVE, SoundCategory.BODY_DROP)
	assert_gt(SoundCategory.ANNC_KO, SoundCategory.BODY_DROP)
	assert_gt(SoundCategory.ANNC_NEAR_KO, SoundCategory.BODY_DROP)
	var ids := [SoundCategory.ANNC_IMPRESSIVE, SoundCategory.ANNC_KO, SoundCategory.ANNC_NEAR_KO]
	var unique := {}
	for id in ids:
		unique[id] = true
	assert_eq(unique.size(), 3, "announcer categories must be distinct")
