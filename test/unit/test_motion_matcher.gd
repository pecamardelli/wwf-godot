extends "res://addons/gut/test.gd"

# Hip toss = PUNCH (trigger) ; AWAY ; AWAY  (newest-first), within 32 arcade ticks.
# RESEARCH §A.4: trigger masks the button cleanly (J_ALL); direction steps mask real-LR.
func _hip_toss() -> MotionMove:
	var m := MotionMove.new()
	m.move_id = "hip_toss"
	m.values = PackedInt32Array([MotionBuffer.B_PUNCH, MotionBuffer.J_AWAY, MotionBuffer.J_AWAY])
	# Trigger: require EXACTLY this button, no other input bits (incl. screen L/R).
	var all := MotionBuffer.J_UP | MotionBuffer.J_DOWN | MotionBuffer.J_AWAY | MotionBuffer.J_TOWARD \
		| MotionBuffer.B_PUNCH | MotionBuffer.B_BLOCK | MotionBuffer.B_SPUNCH | MotionBuffer.B_KICK | MotionBuffer.B_SKICK \
		| MotionBuffer.J_LEFT | MotionBuffer.J_RIGHT
	# Direction steps: match the relative direction, ignore real screen L/R bits.
	var dir_mask := MotionBuffer.J_AWAY | MotionBuffer.J_TOWARD | MotionBuffer.J_UP | MotionBuffer.J_DOWN
	m.masks = PackedInt32Array([all, dir_mask, dir_mask])
	m.max_ticks = 32
	return m

func test_ticks_to_frames_rounds_up():
	assert_eq(ArcadeUnits.ticks_to_frames(32), 37, "ceil(32*60/53)")

func test_matches_a_clean_motion_within_window():
	var b := MotionBuffer.new()
	b.push(MotionBuffer.J_AWAY | MotionBuffer.J_LEFT, 0)            # away (older)
	b.push(MotionBuffer.J_AWAY | MotionBuffer.J_LEFT, 2)            # away
	b.push(MotionBuffer.B_PUNCH, 4)                                 # PUNCH trigger (newest)
	assert_true(MotionMatcher.matches(_hip_toss(), b, 4))

func test_rejects_when_not_fresh():
	var b := MotionBuffer.new()
	b.push(MotionBuffer.J_AWAY, 0)
	b.push(MotionBuffer.J_AWAY, 2)
	b.push(MotionBuffer.B_PUNCH, 4)
	# Current tick has advanced past the trigger -> player let go a frame, no fire.
	assert_false(MotionMatcher.matches(_hip_toss(), b, 6))

func test_rejects_when_too_slow():
	var b := MotionBuffer.new()
	b.push(MotionBuffer.J_AWAY, 0)
	b.push(MotionBuffer.J_AWAY, 1)
	b.push(MotionBuffer.B_PUNCH, 100)   # PUNCH long after the aways -> outside 37-frame window
	assert_false(MotionMatcher.matches(_hip_toss(), b, 100))

func test_rejects_trigger_with_noise():
	var b := MotionBuffer.new()
	b.push(MotionBuffer.J_AWAY, 0)
	b.push(MotionBuffer.J_AWAY, 2)
	b.push(MotionBuffer.B_PUNCH | MotionBuffer.J_TOWARD, 4)   # pressed PUNCH while holding toward
	assert_false(MotionMatcher.matches(_hip_toss(), b, 4), "trigger must be a clean PUNCH")

func test_tolerates_bounded_noise_between_steps():
	var b := MotionBuffer.new()
	b.push(MotionBuffer.J_AWAY, 0)
	b.push(MotionBuffer.J_UP, 1)                  # 1 noise entry between the two aways
	b.push(MotionBuffer.J_AWAY, 2)
	b.push(MotionBuffer.B_PUNCH, 4)
	assert_true(MotionMatcher.matches(_hip_toss(), b, 4))

func test_rejects_when_step_missing():
	var b := MotionBuffer.new()
	b.push(MotionBuffer.J_AWAY, 2)                # only one AWAY, need two
	b.push(MotionBuffer.B_PUNCH, 4)
	assert_false(MotionMatcher.matches(_hip_toss(), b, 4))

func test_empty_buffer_no_match():
	assert_false(MotionMatcher.matches(_hip_toss(), MotionBuffer.new(), 0))

# 2-step move (PUNCH trigger ; AWAY) with a huge window, to isolate the skip budget.
func _punch_then_away() -> MotionMove:
	var m := MotionMove.new()
	m.move_id = "punch_then_away"
	var all := MotionBuffer.J_UP | MotionBuffer.J_DOWN | MotionBuffer.J_AWAY | MotionBuffer.J_TOWARD \
		| MotionBuffer.B_PUNCH | MotionBuffer.B_BLOCK | MotionBuffer.B_SPUNCH | MotionBuffer.B_KICK | MotionBuffer.B_SKICK \
		| MotionBuffer.J_LEFT | MotionBuffer.J_RIGHT
	var dir_mask := MotionBuffer.J_AWAY | MotionBuffer.J_TOWARD | MotionBuffer.J_UP | MotionBuffer.J_DOWN
	m.values = PackedInt32Array([MotionBuffer.B_PUNCH, MotionBuffer.J_AWAY])
	m.masks = PackedInt32Array([all, dir_mask])
	m.max_ticks = 999
	return m

func test_skip_budget_tolerates_eight_then_rejects_nine():
	# 8 noise entries between the AWAY step and the trigger -> tolerated.
	var b8 := MotionBuffer.new()
	b8.push(MotionBuffer.J_AWAY, 0)
	for i in range(8):
		b8.push(MotionBuffer.J_UP, 1 + i)
	b8.push(MotionBuffer.B_PUNCH, 100)
	assert_true(MotionMatcher.matches(_punch_then_away(), b8, 100), "8 skipped entries tolerated")
	# 9 noise entries -> the AWAY is out of reach, rejected.
	var b9 := MotionBuffer.new()
	b9.push(MotionBuffer.J_AWAY, 0)
	for i in range(9):
		b9.push(MotionBuffer.J_UP, 1 + i)
	b9.push(MotionBuffer.B_PUNCH, 100)
	assert_false(MotionMatcher.matches(_punch_then_away(), b9, 100), "9 skipped entries rejected")

func test_trigger_must_be_neutral_stick():
	# Pressing PUNCH while still holding a direction (compound edge) is NOT a clean
	# trigger -> the grab does not fire (player must neutral the stick first).
	var b := MotionBuffer.new()
	b.push(MotionBuffer.J_AWAY | MotionBuffer.J_LEFT, 0)
	b.push(MotionBuffer.J_AWAY | MotionBuffer.J_LEFT, 2)
	b.push(MotionBuffer.B_PUNCH | MotionBuffer.J_AWAY | MotionBuffer.J_LEFT, 4)
	assert_false(MotionMatcher.matches(_hip_toss(), b, 4), "compound button+stick trigger rejected")
