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

var _index: int = -1
var _time_left: float = 0.0
var _waiting_for_hit: bool = false
var _wait_left: float = 0.0   # seconds remaining on the WAIT_HIT_OPP timeout

func play(seq: MoveSequence) -> void:
	sequence = seq
	_index = -1
	_time_left = 0.0
	attack_live = false
	active_attack_box = null
	slave_anim = ""
	whiffed = false
	damage_opp_seen = false
	detach_seen = false
	_pending_attach = false
	_pending_detach = false
	_pending_damage = false
	_pending_set_opp_mode = false
	_pending_clr_opp_mode = false
	_waiting_for_hit = false
	_wait_left = 0.0

func is_playing() -> bool:
	return sequence != null

func is_waiting_for_hit() -> bool:
	return _waiting_for_hit

## Grab box connected: clear the hold so the sequence resumes into the attach frames.
func notify_grab_connected() -> void:
	if _waiting_for_hit:
		_waiting_for_hit = false

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
	if _waiting_for_hit:
		_wait_left -= delta
		if _wait_left <= 0.0:
			whiffed = true
			_waiting_for_hit = false   # timeout -> resume through the remaining frames
		else:
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
	if sequence == null or _index < 0 or _index >= sequence.frames.size():
		return null
	return sequence.frames[_index]

func _apply_command(f: SequenceFrame) -> void:
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
		_:
			pass   # NONE / STARTATTACK: no-op (hitbox opens on ATTACK_ON/WAIT_HIT_OPP)

func _finish() -> void:
	sequence = null
	attack_live = false
	active_attack_box = null
	_index = -1
	_waiting_for_hit = false
