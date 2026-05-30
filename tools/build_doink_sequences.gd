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
const _GRAB_OFFSET_SCALE_Y := 1.5   # verdwtical lift (source apex 52px x this); raise for a higher toss
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
	var afames: int = maxi(_sf.get_frame_count(anim), 1)
	var vframes: int = maxi(_sf.get_frame_count(slave), 1)
	# Step count covers the LONGER of the two clips so NEITHER side drops a frame. The arcade
	# ANI_SUPERSLAVE2 names the attacker frame AND the victim frame independently per step
	# (DNKSEQ3.ASM #puppet_tbl). Tying the step count to the attacker clip alone forced the
	# longer victim clip to be resampled down, SKIPPING frames — the puppet "missed frames"
	# mid-toss (piledriver dropped 7 of 16). With n >= both, the attacker may repeat a frame
	# (invisible mid-throw) but the watched victim plays every frame.
	var n: int = maxi(maxi(afames, vframes), 4)
	var t_slam := float(n - 2) / float(n - 1)
	# Lift apex from the source table (max +y). The raw early Y values are low because the
	# arcade adds a per-frame sprite-anchor lift we lack; we drive a smooth ramp to the apex
	# (continuous hoist) and then SLAM down to the floor line (y=0) — never below it. The
	# source's negative slam Y is relative to the elevated grab point; our origin is the feet
	# (the floor), so the victim must land ON the floor, not under the player's line.
	var apex_y := 0.0
	var apex_j := 0
	if not victim_table.is_empty():
		for k in range(victim_table.size()):
			if victim_table[k].y > apex_y:
				apex_y = victim_table[k].y
				apex_j = k
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
			var msz := victim_table.size()
			var throw_i := clampi((i - 1) if has_grab_window else i, 0, msz - 1)   # reach -> 0
			# X: faithful source sweep (front -> behind). Y: smooth hoist to the source apex,
			# then down to the slam — the victim rises continuously from the grab, not stuck.
			var vx: float = victim_table[throw_i].x * _GRAB_OFFSET_SCALE_X
			var vy := 0.0
			if throw_i <= apex_j and apex_j > 0:
				vy = apex_y * smoothstep(0.0, float(apex_j), float(throw_i))   # ease up to apex
			# after the apex: slammed to the floor line (vy stays 0) — lands ON the floor
			voff = Vector3(vx, vy * _GRAB_OFFSET_SCALE_Y, 0.0)
		# Resample each clip independently onto the n steps (n >= both => no frame skipped on
		# either side; the attacker repeats a frame when n > afames, never the watched victim).
		var aimg := int(round(t * float(afames - 1)))
		var vimg := int(round(t * float(vframes - 1)))
		# 4 ticks/frame matches the arcade SUPERSLAVE2 throw cadence (DNKSEQ2.ASM:4266+);
		# 3 read too fast.
		var fr := _gframe(4, aimg, cmd, slave, voff, vimg)
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

## Neck grab (STANDING), arcade dnk_3_head_hold_anim (DNKSEQ3.ASM:1389). Reach out through
## the lead-in frames to a grab window at the reach APEX (sprite 05 = frame 4); on connect,
## puppet the victim into the locked pose (sprite 07 = frame 6); on whiff/block the reach
## retracts (reverse_reach_on_whiff). Standing portion only (sprites 01-07 = frames 0-6); the
## from-ground headlock (sprites 08-16) is a separate move, out of scope. No DAMAGE_OPP/DETACH
## — the head-hold follow-ups drive those.
const NECK_GRAB_FRAME := 4   # headlocks sprite 05: reach apex / grab window
const NECK_HOLD_FRAME := 6   # headlocks sprite 07: locked pose
## Victim X offset while pulled into the lock — the arcade head-hold #puppet_tbl #Doink raw X
## values (DNKSEQ3.ASM:1549): the head is drawn in from ~60px to the locked 51px. (Y omitted:
## the bend is baked into our art and the held victim is floor-clamped.) The final entry (51)
## is the held/locked offset and MUST match Fighter._HEADHOLD_VICTIM_X (the hold continuation).
## Arcade head-hold #puppet_tbl #Doink raw X (60,59,64,51) + the +20 anchor-space correction
## (our sprites are anchored differently than the arcade's; measured in playtest). Drawn in to
## the locked 71. The final entry MUST match Fighter._HEADHOLD_VICTIM_X (the hold continuation).
const NECK_PUPPET_X := [90.0, 89.0, 94.0, 81.0]
const NECK_HOLD_VICTIM_X := 81.0   # = NECK_PUPPET_X.back(): the locked/held offset

func _neck_grab() -> MoveSequence:
	var m := MoveSequence.new()
	m.id = "neck_grab"; m.anim_name = "headlocks"; m.attack_mode = AMode.PUNCH
	m.is_grapple = true; m.uninterruptable = true; m.reverse_reach_on_whiff = true
	m.contact_freeze_ticks = 1   # arcade head hold has no long freeze (ANI_SUPERSLAVE2,1,FR4 settle)
	var vframes: int = maxi(_sf.get_frame_count("headlocked"), 1)
	var arr: Array[SequenceFrame] = []
	# Reach lead-in (frames 0..NECK_GRAB_FRAME-1): no victim yet, just the reach animation.
	# Reach plays at 3 ticks/frame (a touch quicker than the 4-tick puppet pull-in below).
	for i in range(NECK_GRAB_FRAME):
		arr.append(_gframe(3, i, SequenceFrame.Command.NONE, "", Vector3.ZERO, 0))
	# Grab window at the reach apex. The victim (during the brief freeze) sits at the first
	# puppet offset (NECK_PUPPET_X[0]), the start of being drawn into the lock.
	var gw := _gframe(3, NECK_GRAB_FRAME, SequenceFrame.Command.WAIT_HIT_OPP, "", Vector3(NECK_PUPPET_X[0], 0, 0), 0)
	gw.attack_box = _grab_box(); gw.wait_hit_max_ticks = 16
	arr.append(gw)
	# Connected pull-in: resample attacker frames [NECK_GRAB_FRAME+1 .. NECK_HOLD_FRAME] over
	# enough steps that the victim "headlocked" clip plays EVERY frame (no drop — same rule as
	# the throws). The victim X follows the arcade head-hold #puppet_tbl (NECK_PUPPET_X), drawn
	# in from ~60 to the locked 51. The attacker may repeat a frame; the victim never skips one.
	var cont_lo := NECK_GRAB_FRAME + 1   # first connected attacker frame (5)
	var cont_span := NECK_HOLD_FRAME - cont_lo   # 1
	var nc: int = maxi(cont_span + 1, vframes)
	for s in range(nc):
		var t := float(s) / float(nc - 1)
		var aimg := cont_lo + int(round(t * float(cont_span)))
		var vimg := int(round(t * float(vframes - 1)))
		var vx: float = NECK_PUPPET_X[int(round(t * float(NECK_PUPPET_X.size() - 1)))]
		var cmd := SequenceFrame.Command.SET_ATTACH if s == 0 else SequenceFrame.Command.SLAVE_ANIM
		arr.append(_gframe(4, aimg, cmd, "headlocked", Vector3(vx, 0, 0), vimg))
	m.frames = arr
	return m

func _save(m: MoveSequence) -> void:
	var err := ResourceSaver.save(m, OUT + "/" + m.id + ".tres")
	print(m.id, " (", m.total_ticks(), " ticks) -> ", error_string(err))
	if err != OK:
		push_error("Failed to save %s: %s" % [m.id, error_string(err)])
		quit(1)
