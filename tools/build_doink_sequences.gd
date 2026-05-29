extends SceneTree
## Author the 2b strike sequences as .tres under res://assets/sequences/doink/.
## Run: godot --headless --path . -s tools/build_doink_sequences.gd

const OUT := "res://assets/sequences/doink"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	# Punch-family strikes run at 2 ticks/frame (snappier); kicks stay at the default 3.
	_save(_strike("punch",    "mid_punch_front", AMode.PUNCH,   8, 4, _ab(22, 86, 0, 55, 9, 10), false, 2))
	_save(_strike("headbutt", "headbutt_front",  AMode.HDBUTT,  6, 3, _ab(18, 92, 0, 40, 12, 10), true, 2))
	_save(_strike("kick",     "mid_kick_front",  AMode.KICK,    9, 5, _ab(26, 50, 0, 60, 14, 10)))
	_save(_strike("uppercut", "uppercut",        AMode.UPRCUT,  6, 3, _ab(28, 66, 0, 60, 36, 10), false, 2))
	_save(_strike("big_boot", "big_boot",        AMode.BIGBOOT, 8, 4, _ab(34, 60, 0, 70, 20, 10)))
	# Grapple throws (victim channel). DOINK.ASM:572 (hip toss), :504 (grab & fling).
	_save(_throw("hip_toss",   "hip_toss", "hip_tossed", AMode.BIGBOOT))
	_save(_throw("grab_fling", "fling",    "flinged",    AMode.BIGBOOT))
	quit()

func _ab(ox: float, oy: float, oz: float, w: float, h: float, d: float) -> Box3:
	var b := Box3.new(); b.offset = Vector3(ox, oy, oz); b.size = Vector3(w, h, d); return b

func _frame(dur: int, img: int, cmd: int = SequenceFrame.Command.NONE, box: Box3 = null) -> SequenceFrame:
	var f := SequenceFrame.new()
	f.duration_ticks = dur; f.anim_frame = img; f.command = cmd; f.attack_box = box
	return f

## Build a strike that walks the whole SpriteFrames clip: one SequenceFrame per
## image (anim_frame = i), `ticks_per_frame` ticks each, with the hitbox live from
## `contact` to `contact+2` (capped). This keeps the visible frame and the hit
## window in sync; lower ticks_per_frame = faster-reading swing.
func _strike(id: String, anim_name: String, amode: int, frame_count: int, contact: int, box: Box3, dizzy: bool = false, ticks_per_frame: int = 3) -> MoveSequence:
	var m := MoveSequence.new()
	m.id = id; m.anim_name = anim_name; m.attack_mode = amode; m.causes_dizzy = dizzy
	var off_frame := mini(contact + 2, frame_count - 1)
	var arr: Array[SequenceFrame] = []
	for i in range(frame_count):
		var cmd := SequenceFrame.Command.NONE
		var b: Box3 = null
		if i == contact:
			cmd = SequenceFrame.Command.ATTACK_ON
			b = box
		elif i == off_frame:
			cmd = SequenceFrame.Command.ATTACK_OFF
		arr.append(_frame(ticks_per_frame, i, cmd, b))
	m.frames = arr
	return m

## A grab box (reach in front of the attacker).
func _grab_box() -> Box3:
	var b := Box3.new(); b.offset = Vector3(20, 60, 0); b.size = Vector3(70, 90, 40); return b

func _gframe(dur: int, img: int, cmd: int, slave: String, voff: Vector3, vimg: int) -> SequenceFrame:
	var f := SequenceFrame.new()
	f.duration_ticks = dur; f.anim_frame = img; f.command = cmd
	f.slave_anim = slave; f.victim_offset = voff; f.victim_anim_frame = vimg
	return f

## A throw: windup -> WAIT_HIT_OPP (grab box, hold for connect) -> attach -> lift ->
## slam (DAMAGE_OPP) -> DETACH. Victim offsets are arc keyframes, tuned in playtest.
func _throw(id: String, anim: String, slave: String, slam_amode: int) -> MoveSequence:
	var m := MoveSequence.new()
	m.id = id; m.anim_name = anim; m.attack_mode = slam_amode; m.is_grapple = true; m.uninterruptable = true
	var wait := _gframe(6, 0, SequenceFrame.Command.WAIT_HIT_OPP, slave, Vector3(40, 0, 0), 0)
	wait.attack_box = _grab_box(); wait.wait_hit_max_ticks = 16
	var attach := _gframe(3, 1, SequenceFrame.Command.SET_ATTACH, slave, Vector3(34, 40, 0), 1)
	var lift   := _gframe(3, 2, SequenceFrame.Command.SLAVE_ANIM, slave, Vector3(24, 60, 0), 2)
	var over   := _gframe(3, 3, SequenceFrame.Command.SLAVE_ANIM, slave, Vector3(-10, 50, 0), 3)
	var slam   := _gframe(4, 4, SequenceFrame.Command.DAMAGE_OPP, slave, Vector3(-34, 0, 0), 4)
	slam.victim_amode = slam_amode
	var detach := _gframe(3, 5, SequenceFrame.Command.DETACH, slave, Vector3(-40, 0, 0), 5)
	var recover := _frame(6, 6)
	m.frames = [wait, attach, lift, over, slam, detach, recover]
	return m

func _save(m: MoveSequence) -> void:
	var err := ResourceSaver.save(m, OUT + "/" + m.id + ".tres")
	print(m.id, " (", m.total_ticks(), " ticks) -> ", error_string(err))
	if err != OK:
		push_error("Failed to save %s: %s" % [m.id, error_string(err)])
		quit(1)
