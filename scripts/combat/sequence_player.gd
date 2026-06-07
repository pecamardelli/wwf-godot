class_name SequencePlayer
extends RefCounted
## Steps a MoveSequence over wall-clock time. Frame durations are arcade ticks,
## converted via ArcadeUnits.ticks_to_seconds (logic runs at 60 Hz, 1 frame != 1 tick).
## Grapple sequences add a WAIT_HIT_OPP hold + a victim "slave" track surfaced for Fighter.

var sequence: MoveSequence = null
var attack_live: bool = false
var active_attack_box: Box3 = null

# --- Grapple state surfaced to Fighter ---
var slave_anim: String = ""                 # current victim anim (set by SLAVE_ANIM / SET_ATTACH)
var whiffed: bool = false                    # WAIT_HIT_OPP timed out with no connect
var blocked: bool = false                    # grab landed on a guarding victim (no grab)
var damage_opp_seen: bool = false            # diagnostics/tests: DAMAGE_OPP fired this play
var detach_seen: bool = false                # diagnostics/tests: DETACH fired this play
var _pending_attach: bool = false
var _pending_detach: bool = false
var _pending_damage: bool = false
var _pending_set_opp_mode: bool = false
var _pending_clr_opp_mode: bool = false
var _damage_amode: int = 0
var _damage_dizzy: bool = false
var _opp_mode: int = 0
var _pending_launch: bool = false
var _launch_yvel: int = 0
var _launch_xvel: int = 0
var _launch_homing: bool = false
var _leap_ticks: int = 0
var _leap_cap_x: int = 0
var _leap_cap_z: int = 0
var _pending_sounds: Array[SoundEntry] = []   # ANI_SOUND payloads queued this advance()

var _index: int = -1
var _time_left: float = 0.0
var _waiting_for_hit: bool = false
var _wait_left: float = 0.0   # seconds remaining on the WAIT_HIT_OPP timeout
var _freeze_left: float = 0.0   # seconds of contact hitstop (hold the reach frame on a grab connect)
var _grab_window_index: int = -1   # frame index of the WAIT_HIT_OPP reach apex
var _reversing: bool = false       # retracting the reach after a whiff/block
var _reverse_index: int = -1       # frame shown during the reverse phase

func play(seq: MoveSequence) -> void:
	sequence = seq
	_index = -1
	_time_left = 0.0
	attack_live = false
	active_attack_box = null
	slave_anim = ""
	whiffed = false
	blocked = false
	damage_opp_seen = false
	detach_seen = false
	_pending_attach = false
	_pending_detach = false
	_pending_damage = false
	_pending_set_opp_mode = false
	_pending_clr_opp_mode = false
	_pending_launch = false
	_pending_sounds.clear()
	_waiting_for_hit = false
	_wait_left = 0.0
	_freeze_left = 0.0
	_grab_window_index = -1
	_reversing = false
	_reverse_index = -1

func is_playing() -> bool:
	return sequence != null

func is_waiting_for_hit() -> bool:
	return _waiting_for_hit

## Grab box connected: clear the WAIT_HIT_OPP hold but freeze on the reach frame for a brief
## contact hitstop before the throw/puppet plays. Duration is per-move
## (MoveSequence.contact_freeze_ticks): hip toss = 4 (arcade `WL 4,D3HT3Q+FR1`, DNKSEQ2.ASM:4248);
## neck grab = 1 (arcade `ANI_SUPERSLAVE2,1,D4GH3A+FR4` settle, DNKSEQ3.ASM).
func notify_grab_connected() -> void:
	if _waiting_for_hit:
		_waiting_for_hit = false
		var ticks: int = sequence.contact_freeze_ticks if sequence != null else 4
		_freeze_left = ArcadeUnits.ticks_to_seconds(ticks)

## Grab landed on a guarding victim: no attach. Retract the reach (if the move opts in),
## else end the move (throws). Mirrors arcade #missedb.
func notify_grab_blocked() -> void:
	if _waiting_for_hit:
		_waiting_for_hit = false
		blocked = true
		if not _begin_reverse():
			_finish()

## One-shot intent readers (read-and-clear) — Fighter calls these each tick.
func consume_attach() -> bool:
	var v := _pending_attach; _pending_attach = false; return v
func consume_detach() -> bool:
	var v := _pending_detach; _pending_detach = false; return v
func consume_damage_opp() -> bool:
	var v := _pending_damage; _pending_damage = false; return v
func consume_set_opp_mode() -> bool:
	var v := _pending_set_opp_mode; _pending_set_opp_mode = false; return v
func consume_clr_opp_mode() -> bool:
	var v := _pending_clr_opp_mode; _pending_clr_opp_mode = false; return v
func consume_launch() -> bool:
	var v := _pending_launch; _pending_launch = false; return v
func launch_yvel() -> int: return _launch_yvel
func launch_xvel() -> int: return _launch_xvel
func launch_homing() -> bool: return _launch_homing
func leap_ticks() -> int: return _leap_ticks
func leap_cap_x() -> int: return _leap_cap_x
func leap_cap_z() -> int: return _leap_cap_z
## Read-and-clear the ANI_SOUND payloads that fired since the last call (may be empty).
func consume_sounds() -> Array[SoundEntry]:
	var out := _pending_sounds.duplicate()
	_pending_sounds.clear()
	return out
func damage_amode() -> int:
	return _damage_amode
func damage_dizzy() -> bool:
	return _damage_dizzy
func opp_mode() -> int:
	return _opp_mode

## Advance by `delta` seconds. Returns true on the step that finishes the sequence.
func advance(delta: float) -> bool:
	if sequence == null:
		return false
	if _reversing:
		_time_left -= delta
		while _time_left <= 0.0:
			_reverse_index -= 1
			if _reverse_index < 0:
				_finish()
				return true
			_time_left += ArcadeUnits.ticks_to_seconds(sequence.frames[_reverse_index].duration_ticks)
		return false
	if _waiting_for_hit:
		_wait_left -= delta
		if _wait_left <= 0.0:
			# Whiff: the grab never connected. END the move instead of playing the throw
			# frames (SET_ATTACH/slam/DETACH) with no victim — otherwise the attacker mimes
			# the full toss in empty air. The reach (WAIT_HIT_OPP frame) was the visible
			# grab attempt. No connect -> never GRABBING -> no soft-lock.
			whiffed = true
			_waiting_for_hit = false
			if _begin_reverse():
				return false
			_finish()
			return true
		return false
	if _freeze_left > 0.0:
		_freeze_left -= delta   # contact hitstop: hold the reach frame, then the throw plays
		if _freeze_left > 0.0:
			return false
	_time_left -= delta
	while _time_left <= 0.0:
		_index += 1
		if _index >= sequence.frames.size():
			_finish()
			return true
		var f: SequenceFrame = sequence.frames[_index]
		_apply_command(f)
		if _waiting_for_hit:
			return false   # entered a hold frame: stop advancing this tick
		_time_left += ArcadeUnits.ticks_to_seconds(f.duration_ticks)
	return false

func current_frame() -> SequenceFrame:
	if sequence == null:
		return null
	var idx: int = _reverse_index if _reversing else _index
	if idx < 0 or idx >= sequence.frames.size():
		return null
	return sequence.frames[idx]

func _apply_command(f: SequenceFrame) -> void:
	if f.sound != null:
		_pending_sounds.append(f.sound)
	match f.command:
		SequenceFrame.Command.ATTACK_ON:
			attack_live = true
			active_attack_box = f.attack_box
		SequenceFrame.Command.ATTACK_OFF:
			attack_live = false
			active_attack_box = null
		SequenceFrame.Command.WAIT_HIT_OPP:
			attack_live = true
			active_attack_box = f.attack_box
			_waiting_for_hit = true
			_wait_left = ArcadeUnits.ticks_to_seconds(f.wait_hit_max_ticks)
			_grab_window_index = _index
		SequenceFrame.Command.SET_ATTACH:
			attack_live = false
			active_attack_box = null
			_pending_attach = true
			if f.slave_anim != "":
				slave_anim = f.slave_anim
		SequenceFrame.Command.SLAVE_ANIM:
			if f.slave_anim != "":
				slave_anim = f.slave_anim
		SequenceFrame.Command.DAMAGE_OPP:
			_pending_damage = true
			damage_opp_seen = true
			_damage_amode = f.victim_amode
			_damage_dizzy = f.victim_dizzy
		SequenceFrame.Command.DETACH:
			_pending_detach = true
			detach_seen = true
		SequenceFrame.Command.SET_OPP_MODE:
			_pending_set_opp_mode = true
			_opp_mode = f.opp_mode
		SequenceFrame.Command.CLR_OPP_MODE:
			_pending_clr_opp_mode = true
		SequenceFrame.Command.SET_LAUNCH:
			_pending_launch = true
			_launch_yvel = f.launch_yvel
			_launch_xvel = f.launch_xvel
			_launch_homing = f.launch_homing
			_leap_ticks = f.leap_ticks
			_leap_cap_x = f.leap_cap_x
			_leap_cap_z = f.leap_cap_z
		_:
			pass   # NONE / STARTATTACK: no-op (hitbox opens on ATTACK_ON/WAIT_HIT_OPP)

func _finish() -> void:
	sequence = null
	attack_live = false
	active_attack_box = null
	_index = -1
	_grab_window_index = -1
	_reverse_index = -1
	_waiting_for_hit = false
	_reversing = false

## Begin retracting the reach (whiff/block): play the reach frames from the grab window
## back to frame 0, then finish. Only when the move opts in and there IS a reach lead-in.
## Returns true if the reverse phase started (caller should NOT finish yet).
func _begin_reverse() -> bool:
	# _grab_window_index == 0 means WAIT_HIT_OPP is the very first frame — no lead-in to retract.
	if sequence == null or not sequence.reverse_reach_on_whiff or _grab_window_index <= 0:
		return false
	_reversing = true
	_reverse_index = _grab_window_index   # start at the grab frame itself so the retraction begins at the apex
	# current_frame() re-shows that WAIT_HIT_OPP frame during the retraction, but the grab box
	# is cleared here so it is NOT live while reversing (the reach is retracting, not attacking).
	attack_live = false
	active_attack_box = null
	_time_left = ArcadeUnits.ticks_to_seconds(sequence.frames[_reverse_index].duration_ticks)
	return true
