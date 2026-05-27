extends SceneTree
## Author the 2b strike sequences as .tres under res://assets/sequences/doink/.
## Run: godot --headless --path . -s tools/build_doink_sequences.gd

const OUT := "res://assets/sequences/doink"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_save(_strike("punch",    "mid_punch_front", AMode.PUNCH,   8, 4, _ab(22, 86, 0, 55, 9, 10)))
	_save(_strike("headbutt", "headbutt_front",  AMode.HDBUTT,  6, 3, _ab(18, 92, 0, 40, 12, 10), true))
	_save(_strike("kick",     "mid_kick_front",  AMode.KICK,    9, 5, _ab(26, 50, 0, 60, 14, 10)))
	_save(_strike("uppercut", "uppercut",        AMode.UPRCUT,  6, 3, _ab(28, 66, 0, 60, 36, 10)))
	_save(_strike("big_boot", "big_boot",        AMode.BIGBOOT, 8, 4, _ab(34, 60, 0, 70, 20, 10)))
	quit()

func _ab(ox: float, oy: float, oz: float, w: float, h: float, d: float) -> Box3:
	var b := Box3.new(); b.offset = Vector3(ox, oy, oz); b.size = Vector3(w, h, d); return b

func _frame(dur: int, img: int, cmd: int = SequenceFrame.Command.NONE, box: Box3 = null) -> SequenceFrame:
	var f := SequenceFrame.new()
	f.duration_ticks = dur; f.anim_frame = img; f.command = cmd; f.attack_box = box
	return f

## Build a strike that walks the whole SpriteFrames clip: one SequenceFrame per
## image (anim_frame = i), 3 ticks each, with the hitbox live from `contact` to
## `contact+2` (capped). This keeps the visible frame and the hit window in sync.
func _strike(id: String, anim_name: String, amode: int, frame_count: int, contact: int, box: Box3, dizzy: bool = false) -> MoveSequence:
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
		arr.append(_frame(3, i, cmd, b))
	m.frames = arr
	return m

func _save(m: MoveSequence) -> void:
	var err := ResourceSaver.save(m, OUT + "/" + m.id + ".tres")
	print(m.id, " (", m.total_ticks(), " ticks) -> ", error_string(err))
	if err != OK:
		push_error("Failed to save %s: %s" % [m.id, error_string(err)])
		quit(1)
