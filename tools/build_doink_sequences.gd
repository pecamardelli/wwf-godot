extends SceneTree
## Author the 2b strike sequences as .tres under res://assets/sequences/doink/.
## Run: godot --headless --path . -s tools/build_doink_sequences.gd

const OUT := "res://assets/sequences/doink"
const FRAMES := "res://assets/sprites/doink/doink_frames.tres"

# Arcade Doink-as-victim hip-toss offsets, one per throw frame (DNKSEQ2.ASM:4643 #puppet_tbl
# #Doink): {x in front(+)/behind(-), y up(+)}. The victim is lifted up-and-over (apex y=52)
# then flung behind and down. The arcade applies per-frame sprite-anchor corrections we don't
# have, and they pull X and Y differently — horizontally the raws read too far (shrink X),
# vertically the lift reads too low if shrunk (keep Y near source). Two tuning knobs.
const _GRAB_OFFSET_SCALE_X := 0.6   # horizontal: keep the body close to the attacker
const _GRAB_OFFSET_SCALE_Y := 1.0   # vertical: faithful source lift height (raise if too low)
const _HIPTOSS_VICTIM := [
	Vector3(69, 8, 0), Vector3(37, 7, 0), Vector3(56, 10, 0), Vector3(37, 26, 0),
	Vector3(23, 41, 0), Vector3(-23, 52, 0), Vector3(-73, -18, 0), Vector3(-137, -40, 0),
]

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
	_save(_throw("hip_toss",   "hip_toss", "hip_tossed", AMode.BIGBOOT, _HIPTOSS_VICTIM))
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
## follow-ups start already-attached at SET_ATTACH. The grab commands land at:
## reach(0) -> attach(1) -> slam(n-2) -> detach(n-1). `victim_table` (arcade #puppet_tbl
## {x, y(+up)} per throw frame) drives the exact victim offsets when supplied; otherwise a
## generic over-the-shoulder arc is used.
func _grapple(id: String, anim: String, slave: String, slam_amode: int, has_grab_window: bool, victim_table: Array = []) -> MoveSequence:
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
		var voff: Vector3
		if victim_table.is_empty():
			voff = _victim_arc(t, t_slam)
		else:
			var throw_i := (i - 1) if has_grab_window else i   # throw-frame ordinal (reach = -1)
			var raw: Vector3 = victim_table[clampi(throw_i, 0, victim_table.size() - 1)]
			voff = Vector3(raw.x * _GRAB_OFFSET_SCALE_X, raw.y * _GRAB_OFFSET_SCALE_Y, 0.0)
		var vimg := int(round(t * float(vframes - 1)))
		# 4 ticks/frame matches the arcade SUPERSLAVE2 throw cadence (DNKSEQ2.ASM:4266+);
		# 3 read too fast.
		var fr := _gframe(4, i, cmd, slave, voff, vimg)
		if cmd == SequenceFrame.Command.WAIT_HIT_OPP:
			fr.attack_box = _grab_box(); fr.wait_hit_max_ticks = 16
		if cmd == SequenceFrame.Command.DAMAGE_OPP:
			fr.victim_amode = slam_amode
		arr.append(fr)
	m.frames = arr
	return m

## A throw (fresh grab): opens a WAIT_HIT_OPP reach, then drives the caught victim.
func _throw(id: String, anim: String, slave: String, slam_amode: int, victim_table: Array = []) -> MoveSequence:
	return _grapple(id, anim, slave, slam_amode, true, victim_table)

## A head-hold follow-up: victim is ALREADY attached, so NO grab window — start at SET_ATTACH.
func _followup(id: String, anim: String, slave: String, slam_amode: int) -> MoveSequence:
	return _grapple(id, anim, slave, slam_amode, false)

## Neck grab (STANDING): walk headlocks frames 0-6 only. The 16-frame headlocks clip is
## two moves — sprites 01-07 (frames 0-6) = standing grab-into-hold; 08-16 (7-15) = the
## from-ground headlock (a separate move, out of scope). Reach -> attach -> pull the victim
## into the hold, ending on the held pose (frame 6) which the HEADHOLD state sustains. No
## DAMAGE_OPP/DETACH here — the hold's follow-ups drive those.
const NECK_STAND_FRAMES := 7   # headlocks sprites 01-07

func _neck_grab() -> MoveSequence:
	var m := MoveSequence.new()
	m.id = "neck_grab"; m.anim_name = "headlocks"; m.attack_mode = AMode.PUNCH
	m.is_grapple = true; m.uninterruptable = true
	var vframes: int = maxi(_sf.get_frame_count("headlocked"), 1)
	var arr: Array[SequenceFrame] = []
	for i in range(NECK_STAND_FRAMES):
		var t := float(i) / float(NECK_STAND_FRAMES - 1)
		var cmd := SequenceFrame.Command.SLAVE_ANIM
		if i == 0:
			cmd = SequenceFrame.Command.WAIT_HIT_OPP
		elif i == 1:
			cmd = SequenceFrame.Command.SET_ATTACH
		var vimg := int(round(t * float(vframes - 1)))
		var fr := _gframe(3, i, cmd, "headlocked", Vector3(30, 0, 0), vimg)
		if cmd == SequenceFrame.Command.WAIT_HIT_OPP:
			fr.attack_box = _grab_box(); fr.wait_hit_max_ticks = 16
		arr.append(fr)
	m.frames = arr
	return m

func _save(m: MoveSequence) -> void:
	var err := ResourceSaver.save(m, OUT + "/" + m.id + ".tres")
	print(m.id, " (", m.total_ticks(), " ticks) -> ", error_string(err))
	if err != OK:
		push_error("Failed to save %s: %s" % [m.id, error_string(err)])
		quit(1)
