extends SceneTree
## Author the 2b strike sequences as .tres under res://assets/sequences/doink/.
## Run: godot --headless --path . -s tools/build_doink_sequences.gd

const OUT := "res://assets/sequences/doink"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_save(_punch())
	_save(_headbutt())
	_save(_kick())
	_save(_uppercut())
	_save(_big_boot())
	quit()

func _ab(ox, oy, oz, w, h, d) -> Box3:
	var b := Box3.new(); b.offset = Vector3(ox, oy, oz); b.size = Vector3(w, h, d); return b

func _frame(dur, img, cmd := 0, box: Box3 = null) -> SequenceFrame:
	var f := SequenceFrame.new()
	f.duration_ticks = dur; f.anim_frame = img; f.command = cmd; f.attack_box = box
	return f

func _punch() -> MoveSequence:
	var m := MoveSequence.new()
	m.id = "punch"; m.anim_name = "mid_punch_front"; m.attack_mode = AMode.PUNCH
	m.frames = [
		_frame(3, 0),
		_frame(2, 1, 1),
		_frame(2, 2, 2, _ab(22, 86, 0, 55, 9, 10)),
		_frame(2, 3),
		_frame(2, 3, 3),
		_frame(4, 0),
	]
	return m

func _headbutt() -> MoveSequence:
	var m := MoveSequence.new()
	m.id = "headbutt"; m.anim_name = "headbutt_front"; m.attack_mode = AMode.HDBUTT
	m.causes_dizzy = true
	m.frames = [
		_frame(3, 0), _frame(2, 1, 1),
		_frame(3, 2, 2, _ab(18, 92, 0, 40, 12, 10)),
		_frame(3, 2, 3), _frame(5, 0),
	]
	return m

func _kick() -> MoveSequence:
	var m := MoveSequence.new()
	m.id = "kick"; m.anim_name = "mid_kick_front"; m.attack_mode = AMode.KICK
	m.frames = [
		_frame(3, 0), _frame(2, 1, 1),
		_frame(2, 2, 2, _ab(26, 50, 0, 60, 14, 10)),
		_frame(2, 3), _frame(2, 3, 3), _frame(5, 0),
	]
	return m

func _uppercut() -> MoveSequence:
	var m := MoveSequence.new()
	m.id = "uppercut"; m.anim_name = "uppercut"; m.attack_mode = AMode.UPRCUT
	m.frames = [
		_frame(4, 0), _frame(2, 1, 1),
		_frame(3, 2, 2, _ab(20, 70, 0, 44, 30, 10)),
		_frame(3, 2, 3), _frame(6, 0),
	]
	return m

func _big_boot() -> MoveSequence:
	var m := MoveSequence.new()
	m.id = "big_boot"; m.anim_name = "big_boot"; m.attack_mode = AMode.BIGBOOT
	m.frames = [
		_frame(3, 0), _frame(2, 1, 1),
		_frame(3, 2, 2, _ab(34, 60, 0, 70, 20, 10)),
		_frame(3, 2, 3), _frame(6, 0),
	]
	return m

func _save(m: MoveSequence) -> void:
	var err := ResourceSaver.save(m, OUT + "/" + m.id + ".tres")
	print(m.id, " (", m.total_ticks(), " ticks) -> ", error_string(err))
