extends "res://addons/gut/test.gd"
## Proves the authored .tres patterns fire on realistic edge sequences (arcade-faithful:
## a held direction on the trigger frame is tolerated).

# --- Helpers for the per-file pattern tests (old style, load individual .tres) ---

func _buf_double_dir_then_button(dir_bit: int, real_lr: int, btn: int) -> MotionBuffer:
	var b := MotionBuffer.new()
	b.push(dir_bit | real_lr, 1)                 # first tap
	b.push(0, 2)                                 # released to neutral (stick change)
	b.push(dir_bit | real_lr, 3)                 # second tap (still holding at press)
	b.push(btn | dir_bit | real_lr, 4)           # button trigger WHILE holding the dir
	return b

func test_hip_toss_pattern_fires_with_held_direction():
	var m: MotionMove = load("res://assets/motions/doink/hip_toss.tres")
	var b := _buf_double_dir_then_button(MotionBuffer.J_AWAY, MotionBuffer.J_LEFT, MotionBuffer.B_PUNCH)
	assert_true(MotionMatcher.matches(m, b, 4))

func test_neck_grab_pattern_fires_with_held_direction():
	var m: MotionMove = load("res://assets/motions/doink/neck_grab.tres")
	var b := _buf_double_dir_then_button(MotionBuffer.J_TOWARD, MotionBuffer.J_RIGHT, MotionBuffer.B_SPUNCH)
	assert_true(MotionMatcher.matches(m, b, 4))

func test_hip_toss_does_not_fire_on_toward():
	var m: MotionMove = load("res://assets/motions/doink/hip_toss.tres")
	var b := _buf_double_dir_then_button(MotionBuffer.J_TOWARD, MotionBuffer.J_RIGHT, MotionBuffer.B_PUNCH)
	assert_false(MotionMatcher.matches(m, b, 4), "hip toss needs AWAY, not TOWARD")

func test_grab_fling_needs_spunch_not_punch():
	var m: MotionMove = load("res://assets/motions/doink/grab_fling.tres")
	var b := _buf_double_dir_then_button(MotionBuffer.J_AWAY, MotionBuffer.J_LEFT, MotionBuffer.B_PUNCH)
	assert_false(MotionMatcher.matches(m, b, 4), "grab-fling trigger is SPUNCH")

# --- Table-level tests driven through the real MotionTable (new specials) ---

func _get_mt() -> MotionTable:
	return load("res://assets/motions/doink_motions.tres")

func _buf(seq: Array) -> MotionBuffer:
	# seq is oldest-first; push with increasing ticks (newest last, like Player.feed_input).
	var b := MotionBuffer.new()
	var tick := 1
	for code in seq:
		b.push(code, tick); tick += 1
	return b

func _fires(move_id: String, seq: Array) -> bool:
	var mt := _get_mt()
	var b := _buf(seq)
	var tick: int = b.newest_tick()
	for m in mt.moves():
		if m.move_id == move_id:
			return MotionMatcher.matches(m, b, tick)
	return false

func test_hammer_skick_toward_toward():
	assert_true(_fires("hammer", [MotionBuffer.J_TOWARD, MotionBuffer.J_TOWARD, MotionBuffer.B_SKICK | MotionBuffer.J_TOWARD]))

func test_neck_grab_spunch_toward_toward():
	assert_true(_fires("neck_grab", [MotionBuffer.J_TOWARD, MotionBuffer.J_TOWARD, MotionBuffer.B_SPUNCH | MotionBuffer.J_TOWARD]))

func test_boxing_glove_seven_punches():
	var seq := []
	for i in range(7): seq.append(MotionBuffer.B_PUNCH)
	assert_true(_fires("boxing_glove", seq))

func test_boxing_glove_six_punches_does_not_fire():
	var seq := []
	for i in range(6): seq.append(MotionBuffer.B_PUNCH)
	assert_false(_fires("boxing_glove", seq))
