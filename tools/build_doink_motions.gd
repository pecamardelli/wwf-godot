extends SceneTree
## Author Doink's special-move input patterns -> res://assets/motions/doink/*.tres
## Run: godot --headless --path . -s tools/build_doink_motions.gd
## Patterns from DOINK.ASM:426/504/572 + GAME.EQU:366-428 (arcade {value,mask}).

const OUT := "res://assets/motions/doink"

# Trigger mask = J_ALL (GAME.EQU:380 = all 4 facing-relative dir bits + real screen
# L/R). As an IGNORE mask it strips every direction bit so the trigger compares the
# button only -> a held direction does NOT block the grab.
const J_ALL := MotionBuffer.J_UP | MotionBuffer.J_DOWN | MotionBuffer.J_AWAY \
	| MotionBuffer.J_TOWARD | MotionBuffer.J_REAL_LR
# Direction steps ignore real screen L/R (J_REAL_LR); the facing-relative dir is significant.
const DIR_IGNORE := MotionBuffer.J_REAL_LR

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	# Hip toss: PUNCH ; away ; away  (32 ticks).  DOINK.ASM:572
	_save(_motion("hip_toss", MotionBuffer.B_PUNCH, MotionBuffer.J_AWAY, MotionBuffer.J_AWAY, 32))
	# Grab & fling: SPUNCH ; away ; away  (32 ticks).  DOINK.ASM:504
	_save(_motion("grab_fling", MotionBuffer.B_SPUNCH, MotionBuffer.J_AWAY, MotionBuffer.J_AWAY, 32))
	# Neck/head grab: SPUNCH ; toward ; toward  (32 ticks).  DOINK.ASM:426
	_save(_motion("neck_grab", MotionBuffer.B_SPUNCH, MotionBuffer.J_TOWARD, MotionBuffer.J_TOWARD, 32))
	# Head-hold follow-ups (DOINK.ASM:685-832).
	_save(_motion("piledriver", MotionBuffer.B_SPUNCH, MotionBuffer.J_TOWARD, MotionBuffer.J_TOWARD, 32))
	_save(_motion("head_slam",  MotionBuffer.B_SKICK,  MotionBuffer.J_DOWN,   MotionBuffer.J_DOWN,   32))
	quit()

func _motion(id: String, trigger_btn: int, dir2: int, dir3: int, max_ticks: int) -> MotionMove:
	var m := MotionMove.new()
	m.move_id = id
	m.values = PackedInt32Array([trigger_btn, dir2, dir3])
	m.masks = PackedInt32Array([J_ALL, DIR_IGNORE, DIR_IGNORE])
	m.max_ticks = max_ticks
	return m

func _save(m: MotionMove) -> void:
	var err := ResourceSaver.save(m, OUT + "/" + m.move_id + ".tres")
	print(m.move_id, " -> ", error_string(err))
	if err != OK:
		push_error("failed saving %s: %s" % [m.move_id, error_string(err)])
		quit(1)
