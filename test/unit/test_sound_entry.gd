extends "res://addons/gut/test.gd"

func test_category_voice_constants_are_above_amode_range():
	# Impact categories ARE AMode values (0..12). Voice/event cats must not collide.
	assert_gt(SoundCategory.PAIN, AMode.BOXGLOVE)
	assert_gt(SoundCategory.EFFORT, AMode.BOXGLOVE)
	assert_gt(SoundCategory.TAUNT, AMode.BOXGLOVE)
	assert_gt(SoundCategory.BODY_DROP, AMode.BOXGLOVE)
	# distinct
	var ids := [SoundCategory.PAIN, SoundCategory.EFFORT, SoundCategory.TAUNT, SoundCategory.BODY_DROP]
	assert_eq(ids.size(), 4)
	assert_eq(ids, [SoundCategory.PAIN, SoundCategory.EFFORT, SoundCategory.TAUNT, SoundCategory.BODY_DROP])

func test_sound_entry_defaults():
	var e := SoundEntry.new()
	assert_eq(e.streams.size(), 0)
	assert_eq(e.priority, 0)
	assert_eq(e.bus, &"SFX")
	assert_eq(e.volume_db, 0.0)
	assert_eq(e.pitch_jitter, 0.0)
