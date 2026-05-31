extends SceneTree
## Author Doink's MotionTable (special-move registry) -> res://assets/motions/doink_motions.tres
## Run: godot --headless --path . -s tools/build_doink_motiontable.gd
## Scan order follows doink_secret_moves (DOINK.ASM:214): throws before the head grab,
## then secret-move strikes (hammer, ear_slap, boxing_glove).

const SEQ := "res://assets/sequences/doink/"
const OUT := "res://assets/motions/doink_motions.tres"

## Convenience: load a MoveSequence by id from the canonical sequences directory.
var S := func(id: String) -> MoveSequence:
	return load(SEQ + id + ".tres")

## Build and register one MotionMove in the table.
func _add(t: MotionTable, id: String, values: Array, masks: Array, max_ticks: int, seq: MoveSequence) -> void:
	var m := MotionMove.new()
	m.move_id = id
	m.values = PackedInt32Array(values)
	m.masks = PackedInt32Array(masks)
	m.max_ticks = max_ticks
	t.add(m, seq)

func _init() -> void:
	var t := MotionTable.new()
	var J := MotionBuffer   # alias for readability
	# ALL_DIR: every directional bit we want to ignore on the trigger step so that
	# holding any direction while pressing the button does not block the match.
	var ALL_DIR: int = J.J_UP | J.J_DOWN | J.J_AWAY | J.J_TOWARD | J.J_REAL_LR

	# Grab INITIATORS (arcade doink_secret_moves). Head-hold follow-ups
	# (piledriver/head_slam/joy_buzzer) are dispatched separately from HEADHOLD
	# context (Task 16 loads them by path), NOT scanned here in normal play.
	#
	# More-specific / button-distinct patterns come first. hip_toss (B_PUNCH+AWAY)
	# and grab_fling (B_SPUNCH+AWAY) are single-step and mutually exclusive by
	# button. neck_grab (B_SPUNCH+TOWARD TOWARD TOWARD) and hammer (B_SKICK+TOWARD
	# TOWARD TOWARD) differ in button. ear_slap (B_PUNCH + QCF) is 4 steps and
	# only fires on the full quarter-circle; boxing_glove (7xB_PUNCH) needs seven
	# consecutive punches and can only shadow hip_toss if the buffer contains
	# toward — it doesn't, so ordering here is safe.

	# Three-step throws: double-tap direction then button (newest-first). Trigger mask is
	# ALL_DIR (button-only value). Directional-step masks follow the ARCADE encoding:
	#  - AWAY grabs (hip_toss, grab_fling) use J_REAL_LR|J_UP|J_DOWN -> tolerate a vertical
	#    component (arcade #hip_toss/#grab_fling mask).
	#  - TOWARD grabs (neck_grab, hammer) use J_REAL_LR ONLY -> up/down stay SIGNIFICANT, so
	#    down+toward (a diagonal) is REJECTED. Pure-cardinal toward (arcade #neck_grab/#hammer
	#    `.word J_TOWARD, J_REAL_LR`). This is why holding down while pressing toward must NOT
	#    fire the headlock.
	# (Genesis override: hip_toss/grab_fling are 3-step here, not the arcade's single step.)
	_add(t, "hip_toss",
		[J.B_PUNCH, J.J_AWAY, J.J_AWAY],
		[ALL_DIR, J.J_REAL_LR | J.J_UP | J.J_DOWN, J.J_REAL_LR | J.J_UP | J.J_DOWN],
		32, S.call("hip_toss"))

	_add(t, "grab_fling",
		[J.B_SPUNCH, J.J_AWAY, J.J_AWAY],
		[ALL_DIR, J.J_REAL_LR | J.J_UP | J.J_DOWN, J.J_REAL_LR | J.J_UP | J.J_DOWN],
		32, S.call("grab_fling"))

	_add(t, "neck_grab",
		[J.B_SPUNCH, J.J_TOWARD, J.J_TOWARD],
		[ALL_DIR, J.J_REAL_LR, J.J_REAL_LR],
		32, S.call("neck_grab"))

	_add(t, "hammer",
		[J.B_SKICK, J.J_TOWARD, J.J_TOWARD],
		[ALL_DIR, J.J_REAL_LR, J.J_REAL_LR],
		32, S.call("hammer"))

	# Four-step quarter-circle-forward: DOWN, DOWN+TOWARD, TOWARD, B_PUNCH (newest-first).
	# Arcade motion: tap DOWN -> DOWN+TOWARD -> TOWARD -> press B_PUNCH (optionally
	# holding TOWARD on the trigger frame). Trigger mask is ALL_DIR so values[0] = B_PUNCH only.
	_add(t, "ear_slap",
		[J.B_PUNCH, J.J_TOWARD, J.J_DOWN | J.J_TOWARD, J.J_DOWN],
		[ALL_DIR, ~J.J_TOWARD & 0xFFFF, ~(J.J_DOWN | J.J_TOWARD) & 0xFFFF, ~J.J_DOWN & 0xFFFF],
		50, S.call("ear_slap"))

	# Seven consecutive B_PUNCH presses; stick direction is ignored on every step.
	var bg_v: Array = []
	var bg_m: Array = []
	for _i in range(7):
		bg_v.append(J.B_PUNCH)
		bg_m.append(ALL_DIR)
	_add(t, "boxing_glove", bg_v, bg_m, 60, S.call("boxing_glove"))

	var err := ResourceSaver.save(t, OUT)
	print("doink_motions -> ", error_string(err))
	if err != OK:
		quit(1)
	quit()
