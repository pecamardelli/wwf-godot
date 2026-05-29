extends SceneTree
## Author the 2b strike sequences as .tres under res://assets/sequences/doink/.
## Run: godot --headless --path . -s tools/build_doink_sequences.gd

const OUT := "res://assets/sequences/doink"
const FRAMES := "res://assets/sprites/doink/doink_frames.tres"

# The Doink SpriteFrames, so grapple sequences can walk EVERY frame of an animation
# (the visible throw must play the whole clip, like the arcade ANI_SUPERSLAVE2 loop).
var _sf: SpriteFrames = null

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_sf = load(FRAMES)
	# Punch-family strikes run at 2 ticks/frame (snappier); kicks stay at the default 3.
	_save(_strike("punch",    "mid_punch_front", AMode.PUNCH,   8, 4, _ab(22, 86, 0, 55, 9, 10), false, 2))
	_save(_strike("headbutt", "headbutt_front",  AMode.HDBUTT,  6, 3, _ab(18, 92, 0, 40, 12, 10), true, 2))
	_save(_strike("kick",     "mid_kick_front",  AMode.KICK,    9, 5, _ab(26, 50, 0, 60, 14, 10)))
	_save(_strike("uppercut", "uppercut",        AMode.UPRCUT,  6, 3, _ab(28, 66, 0, 60, 36, 10), false, 2))
	_save(_strike("big_boot", "big_boot",        AMode.BIGBOOT, 8, 4, _ab(34, 60, 0, 70, 20, 10)))
	# Grapple throws (victim channel). DOINK.ASM:572 (hip toss), :504 (grab & fling).
	_save(_throw("hip_toss",   "hip_toss", "hip_tossed", AMode.BIGBOOT))
	_save(_throw("grab_fling", "fling",    "flinged",    AMode.BIGBOOT))
	# Head grab: connect -> HEADHOLD (no DAMAGE_OPP/DETACH here; head-hold drives follow-ups).
	_save(_neck_grab())
	# Head-hold follow-ups (DOINK.ASM:685-832). Victim is already attached (no grab window).
	_save(_followup("piledriver", "piledriver", "piledrivered", AMode.BIGBOOT))
	_save(_followup("head_slam",  "faceslam",   "faceslamed",   AMode.BIGBOOT))
	_save(_followup("joy_buzzer", "joy_buzzer", "joy_buzzer",   AMode.BIGBOOT))
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

## Over-the-shoulder victim arc as a function of throw progress t in [0,1]: sweep from
## in-front to behind, rise to a peak then back to the mat by the slam frame (t_slam).
## +y = up. Starting offsets; the expert tunes exact positioning in playtest.
func _victim_arc(t: float, t_slam: float) -> Vector3:
	var vx := lerpf(34.0, -36.0, t)
	var vy := 0.0
	if t < t_slam:
		vy = 60.0 * sin(PI * t / t_slam)   # up-and-over, back to the mat at the slam
	return Vector3(vx, vy, 0.0)

## Build a grapple that walks the WHOLE attacker clip: one SequenceFrame per sprite image
## (anim_frame = i), so the full throw animation plays (arcade SUPERSLAVE2 walks every
## puppet frame). `has_grab_window` opens a WAIT_HIT_OPP reach on frame 0 (a fresh throw);
## follow-ups start already-attached at SET_ATTACH. The victim slave frame is mapped across
## its own clip; the grab commands land at: reach(0) -> attach(1) -> slam(n-2) -> detach(n-1).
func _grapple(id: String, anim: String, slave: String, slam_amode: int, has_grab_window: bool) -> MoveSequence:
	var m := MoveSequence.new()
	m.id = id; m.anim_name = anim; m.attack_mode = slam_amode; m.is_grapple = true; m.uninterruptable = true
	var n: int = maxi(_sf.get_frame_count(anim), 4)
	var vframes: int = maxi(_sf.get_frame_count(slave), 1)
	var t_slam := float(n - 2) / float(n - 1)
	var arr: Array[SequenceFrame] = []
	for i in range(n):
		var t := float(i) / float(n - 1)
		var cmd := SequenceFrame.Command.SLAVE_ANIM
		if i == 0:
			cmd = SequenceFrame.Command.WAIT_HIT_OPP if has_grab_window else SequenceFrame.Command.SET_ATTACH
		elif i == 1 and has_grab_window:
			cmd = SequenceFrame.Command.SET_ATTACH
		elif i == n - 2:
			cmd = SequenceFrame.Command.DAMAGE_OPP
		elif i == n - 1:
			cmd = SequenceFrame.Command.DETACH
		var vimg := int(round(t * float(vframes - 1)))
		var fr := _gframe(3, i, cmd, slave, _victim_arc(t, t_slam), vimg)
		if cmd == SequenceFrame.Command.WAIT_HIT_OPP:
			fr.attack_box = _grab_box(); fr.wait_hit_max_ticks = 16
		if cmd == SequenceFrame.Command.DAMAGE_OPP:
			fr.victim_amode = slam_amode
		arr.append(fr)
	m.frames = arr
	return m

## A throw (fresh grab): opens a WAIT_HIT_OPP reach, then drives the caught victim.
func _throw(id: String, anim: String, slave: String, slam_amode: int) -> MoveSequence:
	return _grapple(id, anim, slave, slam_amode, true)

## A head-hold follow-up: victim is ALREADY attached, so NO grab window — start at SET_ATTACH.
func _followup(id: String, anim: String, slave: String, slam_amode: int) -> MoveSequence:
	return _grapple(id, anim, slave, slam_amode, false)

## Neck grab: windup -> WAIT_HIT_OPP -> SET_ATTACH into the head hold. The hold itself
## (mode transition + follow-up polling) is handled by Fighter, not this sequence.
func _neck_grab() -> MoveSequence:
	var m := MoveSequence.new()
	m.id = "neck_grab"; m.anim_name = "headlocks"; m.attack_mode = AMode.PUNCH
	m.is_grapple = true; m.uninterruptable = true
	var wait := _gframe(6, 0, SequenceFrame.Command.WAIT_HIT_OPP, "headlocked", Vector3(34, 0, 0), 0)
	wait.attack_box = _grab_box(); wait.wait_hit_max_ticks = 16
	var attach := _gframe(4, 1, SequenceFrame.Command.SET_ATTACH, "headlocked", Vector3(30, 0, 0), 1)
	m.frames = [wait, attach]
	return m

func _save(m: MoveSequence) -> void:
	var err := ResourceSaver.save(m, OUT + "/" + m.id + ".tres")
	print(m.id, " (", m.total_ticks(), " ticks) -> ", error_string(err))
	if err != OK:
		push_error("Failed to save %s: %s" % [m.id, error_string(err)])
		quit(1)
