extends SceneTree
## Author Doink's special-move input patterns -> res://assets/motions/doink/*.tres
## Run: godot --headless --path . -s tools/build_doink_motions.gd
## Patterns from RESEARCH §A.4 (DOINK.ASM:426-583).

const OUT := "res://assets/motions/doink"

# Trigger mask = EVERY input bit, so the trigger entry must be a clean button with a
# neutral stick (no joy or screen-direction noise). Matches the matcher's trigger rule.
const ALL := MotionBuffer.J_UP | MotionBuffer.J_DOWN | MotionBuffer.J_AWAY | MotionBuffer.J_TOWARD \
	| MotionBuffer.B_PUNCH | MotionBuffer.B_BLOCK | MotionBuffer.B_SPUNCH | MotionBuffer.B_KICK | MotionBuffer.B_SKICK \
	| MotionBuffer.J_LEFT | MotionBuffer.J_RIGHT
# Direction steps ignore real screen L/R (J_LEFT/J_RIGHT), matching only the relative dir.
const DIR := MotionBuffer.J_AWAY | MotionBuffer.J_TOWARD | MotionBuffer.J_UP | MotionBuffer.J_DOWN

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	# Hip toss: PUNCH ; away ; away  (32 ticks).  DOINK.ASM:572
	_save(_motion("hip_toss", MotionBuffer.B_PUNCH, MotionBuffer.J_AWAY, MotionBuffer.J_AWAY, 32))
	# Grab & fling: SPUNCH ; away ; away  (32 ticks).  DOINK.ASM:504
	_save(_motion("grab_fling", MotionBuffer.B_SPUNCH, MotionBuffer.J_AWAY, MotionBuffer.J_AWAY, 32))
	# Neck/head grab: SPUNCH ; toward ; toward  (32 ticks).  DOINK.ASM:426
	_save(_motion("neck_grab", MotionBuffer.B_SPUNCH, MotionBuffer.J_TOWARD, MotionBuffer.J_TOWARD, 32))
	quit()

func _motion(id: String, trigger_btn: int, dir2: int, dir3: int, max_ticks: int) -> MotionMove:
	var m := MotionMove.new()
	m.move_id = id
	m.values = PackedInt32Array([trigger_btn, dir2, dir3])
	m.masks = PackedInt32Array([ALL, DIR, DIR])
	m.max_ticks = max_ticks
	return m

func _save(m: MotionMove) -> void:
	var err := ResourceSaver.save(m, OUT + "/" + m.move_id + ".tres")
	print(m.move_id, " -> ", error_string(err))
	if err != OK:
		push_error("failed saving %s: %s" % [m.move_id, error_string(err)])
		quit(1)
