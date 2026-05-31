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

	# Single-step throws (button + direction on the same frame). NOTE: unlike the multi-step
	# patterns above, the direction IS part of values[0], so the mask must NOT be ALL_DIR —
	# masking J_AWAY would erase the very bit the value depends on. Only the real-L/R + up/down
	# bits are ignored here.
	_add(t, "hip_toss",
		[J.B_PUNCH | J.J_AWAY],
		[J.J_REAL_LR | J.J_UP | J.J_DOWN],
		10, S.call("hip_toss"))

	_add(t, "grab_fling",
		[J.B_SPUNCH | J.J_AWAY],
		[J.J_REAL_LR | J.J_UP | J.J_DOWN],
		10, S.call("grab_fling"))

	# Three-step motion: button (holding TOWARD is allowed), TOWARD, TOWARD (newest-first).
	# The trigger mask is ALL_DIR so direction bits are ignored on step 0; values[0] must
	# only contain bits NOT in the mask, i.e. just the button.
	_add(t, "neck_grab",
		[J.B_SPUNCH, J.J_TOWARD, J.J_TOWARD],
		[ALL_DIR, ~J.J_TOWARD & 0xFFFF, ~J.J_TOWARD & 0xFFFF],
		32, S.call("neck_grab"))

	_add(t, "hammer",
		[J.B_SKICK, J.J_TOWARD, J.J_TOWARD],
		[ALL_DIR, ~J.J_TOWARD & 0xFFFF, ~J.J_TOWARD & 0xFFFF],
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
