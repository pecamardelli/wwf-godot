extends "res://addons/gut/test.gd"

# Hip toss = PUNCH (trigger) ; AWAY ; AWAY  (newest-first), within 32 arcade ticks.
# Arcade (DOINK.ASM:572, GAME.EQU:380): trigger mask = J_ALL (ignore ALL direction
# bits, compare the button only); direction steps mask J_REAL_LR (ignore screen L/R).
const J_ALL := MotionBuffer.J_UP | MotionBuffer.J_DOWN | MotionBuffer.J_AWAY \
	| MotionBuffer.J_TOWARD | MotionBuffer.J_REAL_LR

func _hip_toss() -> MotionMove:
	var m := MotionMove.new()
	m.move_id = "hip_toss"
	m.values = PackedInt32Array([MotionBuffer.B_PUNCH, MotionBuffer.J_AWAY, MotionBuffer.J_AWAY])
	m.masks = PackedInt32Array([J_ALL, MotionBuffer.J_REAL_LR, MotionBuffer.J_REAL_LR])
	m.max_ticks = 32
	return m

func test_ticks_to_frames_rounds_up():
	assert_eq(ArcadeUnits.ticks_to_frames(32), 37, "ceil(32*60/53)")

func test_matches_a_clean_motion_within_window():
	var b := MotionBuffer.new()
	b.push(MotionBuffer.J_AWAY | MotionBuffer.J_LEFT, 0)
	b.push(MotionBuffer.J_AWAY | MotionBuffer.J_LEFT, 2)
	b.push(MotionBuffer.B_PUNCH, 4)
	assert_true(MotionMatcher.matches(_hip_toss(), b, 4))

func test_held_direction_trigger_fires():
	# Arcade J_ALL trigger mask IGNORES held direction: pressing PUNCH while still
	# holding away DOES fire the grab (the corrected behavior).
	var b := MotionBuffer.new()
	b.push(MotionBuffer.J_AWAY | MotionBuffer.J_LEFT, 0)
	b.push(MotionBuffer.J_AWAY | MotionBuffer.J_LEFT, 2)
	b.push(MotionBuffer.B_PUNCH | MotionBuffer.J_AWAY | MotionBuffer.J_LEFT, 4)
	assert_true(MotionMatcher.matches(_hip_toss(), b, 4), "held-direction press fires (J_ALL ignores dir)")

func test_rejects_when_not_fresh():
	var b := MotionBuffer.new()
	b.push(MotionBuffer.J_AWAY, 0)
	b.push(MotionBuffer.J_AWAY, 2)
	b.push(MotionBuffer.B_PUNCH, 4)
	assert_false(MotionMatcher.matches(_hip_toss(), b, 6))

func test_rejects_when_too_slow():
	var b := MotionBuffer.new()
	b.push(MotionBuffer.J_AWAY, 0)
	b.push(MotionBuffer.J_AWAY, 1)
	b.push(MotionBuffer.B_PUNCH, 100)
	assert_false(MotionMatcher.matches(_hip_toss(), b, 100))

func test_rejects_trigger_with_no_button():
	# A stick-change head (no button bit) masks to nothing under J_ALL -> noise since
	# the trigger -> rejected (arcade head-noise check).
	var b := MotionBuffer.new()
	b.push(MotionBuffer.J_AWAY, 0)
	b.push(MotionBuffer.J_AWAY, 2)
	b.push(MotionBuffer.J_TOWARD | MotionBuffer.J_RIGHT, 4)   # newest is a stick change
	assert_false(MotionMatcher.matches(_hip_toss(), b, 4), "head with no button is noise")

func test_rejects_wrong_button_trigger():
	var b := MotionBuffer.new()
	b.push(MotionBuffer.J_AWAY, 0)
	b.push(MotionBuffer.J_AWAY, 2)
	b.push(MotionBuffer.B_KICK, 4)   # KICK, not PUNCH
	assert_false(MotionMatcher.matches(_hip_toss(), b, 4))

func test_tolerates_bounded_noise_between_steps():
	var b2 := MotionBuffer.new()
	b2.push(MotionBuffer.J_AWAY, 0)
	b2.push(MotionBuffer.J_LEFT, 1)               # real L/R only -> masks to zero under J_REAL_LR = noise
	b2.push(MotionBuffer.J_AWAY, 2)
	b2.push(MotionBuffer.B_PUNCH, 4)
	assert_true(MotionMatcher.matches(_hip_toss(), b2, 4), "true noise (L/R-only) between steps tolerated")

func test_rejects_when_step_missing():
	var b := MotionBuffer.new()
	b.push(MotionBuffer.J_AWAY, 2)
	b.push(MotionBuffer.B_PUNCH, 4)
	assert_false(MotionMatcher.matches(_hip_toss(), b, 4))

func test_empty_buffer_no_match():
	assert_false(MotionMatcher.matches(_hip_toss(), MotionBuffer.new(), 0))

# 2-step move (PUNCH trigger ; AWAY) with a huge window, to isolate the skip budget.
func _punch_then_away() -> MotionMove:
	var m := MotionMove.new()
	m.move_id = "punch_then_away"
	m.values = PackedInt32Array([MotionBuffer.B_PUNCH, MotionBuffer.J_AWAY])
	m.masks = PackedInt32Array([J_ALL, MotionBuffer.J_REAL_LR])
	m.max_ticks = 999
	return m

func test_skip_budget_tolerates_eight_then_rejects_nine():
	# True-noise entries = real-L/R-only (mask to zero under J_REAL_LR).
	var b8 := MotionBuffer.new()
	b8.push(MotionBuffer.J_AWAY, 0)
	for i in range(8):
		b8.push(MotionBuffer.J_LEFT, 1 + i)
	b8.push(MotionBuffer.B_PUNCH, 100)
	assert_true(MotionMatcher.matches(_punch_then_away(), b8, 100), "8 noise entries tolerated")
	var b9 := MotionBuffer.new()
	b9.push(MotionBuffer.J_AWAY, 0)
	for i in range(9):
		b9.push(MotionBuffer.J_LEFT, 1 + i)
	b9.push(MotionBuffer.B_PUNCH, 100)
	assert_false(MotionMatcher.matches(_punch_then_away(), b9, 100), "9 noise entries rejected")
