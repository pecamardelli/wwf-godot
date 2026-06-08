class_name Player
extends Fighter
## A Fighter driven by per-player input actions.
## player_index 0 -> p1_* actions; player_index 1 -> p2_* actions.

const _MOVES := preload("res://assets/movetables/doink.tres")
const _HAIR_PICKUP := preload("res://assets/sequences/doink/hair_pickup.tres")
const _FLYING_KICK := preload("res://assets/sequences/doink/flying_kick.tres")
const _HEADBUTT_BURST := preload("res://assets/sequences/doink/headbutt_burst.tres")

## Head-hold follow-ups, loaded by path (NOT in the main grab-initiator MotionTable).
const _FOLLOWUP_MOTIONS := {
	"piledriver": preload("res://assets/motions/doink/piledriver.tres"),
	"head_slam": preload("res://assets/motions/doink/head_slam.tres"),
}
const _FOLLOWUP_SEQUENCES := {
	"piledriver": preload("res://assets/sequences/doink/piledriver.tres"),
	"head_slam": preload("res://assets/sequences/doink/head_slam.tres"),
	"joy_buzzer": preload("res://assets/sequences/doink/joy_buzzer.tres"),
}

@export var player_index: int = 0

## Mash-to-extend headbutt burst (CLOSE + high-punch). See BurstState + _service_burst_end.
var _burst := BurstState.new()

## Motion-input state (arcade wrest_joystat). Filled each frame by feed_input().
var motion_buffer := MotionBuffer.new()
var charge := ChargeTracker.new()
var _input_tick := 0
var _prev_stick := 0
var _prev_buttons := 0
## Optional special-move registry (grapples). When null, Player behaves as a striker only.
@export var motions: MotionTable = null

func _action_prefix() -> String:
	return "p1_" if player_index == 0 else "p2_"

func get_input_direction() -> Vector2:
	var p: String = _action_prefix()
	return Vector2(
		Input.get_axis(p + "left", p + "right"),
		Input.get_axis(p + "up", p + "down")
	)

func wants_to_run() -> bool:
	return _pressed(_action_prefix() + "run")

func wants_to_block() -> bool:
	return _held(_action_prefix() + "block")

func _unhandled_input(_event: InputEvent) -> void:
	# While downed, any button/direction press mashes toward a faster getup.
	if mode == Mode.ONGROUND:
		var p := _action_prefix()
		if _pressed(p + "punch") or _pressed(p + "kick") or _pressed(p + "high_punch") \
				or _pressed(p + "high_kick") or _pressed(p + "left") or _pressed(p + "right"):
			mash_recover()
	# Normal-move dispatch lives in _physics_process now, AFTER the special scan, so a
	# grab pre-empts a normal attack (arcade move_doink: check_secret_moves before mode_normal).

## Hair pickup pre-empts the grounded elbow drop when the attacker is at the downed foe's head
## (arcade #spunch_lbowdrop sub-branch). SPUNCH-only — GROUNDED+LOW_PUNCH also resolves to
## elbow_drop, but the arcade gates hair pickup inside the SPUNCH handler. Geometric gate, not a
## MoveTable cell — so we intercept the resolved move here. Returns the move to actually start.
func _grounded_move_or_hair_pickup(seq: MoveSequence, btn: int) -> MoveSequence:
	if seq != null and seq.id == "elbow_drop" and btn == MoveTable.Btn.HIGH_PUNCH \
			and target != null and is_instance_valid(target) \
			and HairPickup.gate(global_position.x, _facing, target.global_position.x, target._facing, target.mode):
		return _HAIR_PICKUP
	return seq

## Flying kick pre-empts the standing spin kick (HIGH_KICK) when the target stands beyond the
## 60x60 close box (arcade #super_kick: within = close super, outside = jumping kick). Geometric
## gate, not a MoveTable cell — so we intercept the resolved move here.
func _normal_kick_or_flying_kick(seq: MoveSequence, btn: int) -> MoveSequence:
	if seq != null and seq.id == "spin_kick" and btn == MoveTable.Btn.HIGH_KICK \
			and target != null and is_instance_valid(target) \
			and FlyingKick.gate(global_position, target.global_position, target.mode):
		return _FLYING_KICK
	return seq

## True only while a fresh burst hit could still connect: a valid, standing, CLOSE target.
func _burst_close_to_target() -> bool:
	return target != null and is_instance_valid(target) and target.mode == Mode.NORMAL \
		and _current_range() == MoveTable.Rng.CLOSE

## Called once a burst hit's move has ended (not is_attacking()). Either chains the next hit
## (buffered re-press, under the cap, still close) or ENDS the burst — popping whoever the last
## hit landed on. Returns true when it consumed the frame (always, while a burst is active).
func _service_burst_end(close: bool) -> bool:
	var victim: Fighter = null
	if not _hit_by_current_move.is_empty():
		var v: Variant = _hit_by_current_move.back()
		if v is Fighter:
			victim = v
	var victim_ok := victim != null and is_instance_valid(victim) and not victim.is_dead()
	if close and victim_ok and _burst.can_chain():
		_burst.advance()
		start_move(_HEADBUTT_BURST)
		return true
	if victim_ok:
		victim.pop_from_headbutt(self)
	_burst.reset()
	return true

## Normal-move dispatch (arcade action_table / mode_normal). Run from _physics_process
## ONLY after scan_specials returns false, so a buffered grab always wins over a normal
## attack on the same press (the arcade pre-empts the action table on a secret-move match).
func _dispatch_normal_move() -> void:
	var btn := _pressed_button()
	if btn < 0:
		return
	var seq: MoveSequence = _MOVES.lookup(_current_range(), _current_dir(), btn)
	seq = _grounded_move_or_hair_pickup(seq, btn)   # hair pickup pre-empts elbow drop at the head
	seq = _normal_kick_or_flying_kick(seq, btn)     # flying kick pre-empts the standing spin kick
	if seq != null:
		if seq.id == "headbutt_burst" and not _burst.is_active():
			_burst.start()   # first hit of a fresh burst chain
		start_move(seq)
	elif mode == Mode.RUNNING:
		mode = Mode.NORMAL   # an attack press with no running variant still ends the run

## Which attack button was just pressed, or -1.
func _pressed_button() -> int:
	var p := _action_prefix()
	if _pressed(p + "punch"): return MoveTable.Btn.LOW_PUNCH
	if _pressed(p + "high_punch"): return MoveTable.Btn.HIGH_PUNCH
	if _pressed(p + "kick"): return MoveTable.Btn.LOW_KICK
	if _pressed(p + "high_kick"): return MoveTable.Btn.HIGH_KICK
	return -1

## In HEADHOLD: poll the buffer for follow-up grapples + the joybuzzer charge release.
## On a match, start the follow-up (victim stays attached) and immobilize the victim.
func scan_headhold_followups() -> bool:
	if mode != Fighter.Mode.HEADHOLD or _grappling == null:
		return false
	# Joybuzzer: PUNCH held >= 100 ticks then released (arcade #charge_buzz first).
	if charge.released_after(MotionBuffer.B_PUNCH, 100):
		return _launch_followup("joy_buzzer")
	for id in ["piledriver", "head_slam"]:
		if MotionMatcher.matches(_FOLLOWUP_MOTIONS[id], motion_buffer, _input_tick):
			return _launch_followup(id)
	return false

## Start a head-hold follow-up with the victim already attached (no re-grab). Converts
## the hold (HEADHOLD/HEADHELD) into a driven throw (GRABBING/GRABBED); the follow-up
## sequence (no WAIT_HIT_OPP) drives the still-attached victim straight through the slam.
func _launch_followup(id: String) -> bool:
	if _grappling == null or not is_instance_valid(_grappling):
		return false
	var seq: MoveSequence = _FOLLOWUP_SEQUENCES.get(id, null)
	if seq == null:
		return false
	_grappling.set_immobilize_ticks(15)
	mode = Fighter.Mode.GRABBING
	_grappling.mode = Fighter.Mode.GRABBED
	start_move(seq)
	motion_buffer.clear()
	return true

## In HEADHELD: a non-immobilized victim may counter with the same follow-up patterns,
## swapping roles and immobilizing the former captor (arcade emergent reversal, §B.8).
func scan_headhold_reversal() -> bool:
	if mode != Fighter.Mode.HEADHELD or _grappled_by == null or not is_instance_valid(_grappled_by):
		return false
	if is_immobilized() or is_dead():
		return false
	for id in ["piledriver", "head_slam"]:
		if MotionMatcher.matches(_FOLLOWUP_MOTIONS[id], motion_buffer, _input_tick):
			reverse_into_grappler(_grappled_by, _FOLLOWUP_SEQUENCES[id])
			motion_buffer.clear()
			return true
	return false

func _physics_process(delta: float) -> void:
	feed_input(get_input_direction(), _buttons_held_mask(), facing())
	# Headbutt burst: a re-press during a hit buffers the next; a fresh reaction on US ends it.
	if _burst.is_active():
		if not Fighter.input_allowed(mode) or _react_timer > 0.0:
			_burst.reset()                                   # we got hit/knocked -> burst broken
		elif _pressed(_action_prefix() + "high_punch"):
			_burst.note_continue()
	# If both fighters buffer a counter on the same frame, the first to _physics_process
	# (scene-tree order) wins; the loser is already GRABBED and skips its own scan.
	if mode == Fighter.Mode.HEADHELD and not is_attacking():
		if scan_headhold_reversal():
			super(delta)
			return
	if mode == Fighter.Mode.HEADHOLD and not is_attacking():
		if scan_headhold_followups():
			super(delta)
			return
	# Specials are checked before normal-move dispatch (arcade move_doink runs
	# check_secret_moves before mode_normal, every frame). A fired grab pre-empts the
	# normal attack on the same press.
	if Fighter.input_allowed(mode) and not is_attacking() and _react_timer <= 0.0:
		if _burst.is_active():
			if _service_burst_end(_burst_close_to_target()):
				super(delta)
				return
		if scan_specials():
			super(delta)
			return
		_dispatch_normal_move()
	super(delta)

## Scan the special-move registry against the current buffer; start the first match's
## grapple sequence. Returns true if a special fired. Clears the buffer on a fire so the
## same trigger edge cannot re-fire next frame (arcade clears counts on a grab).
## Respects the same input gate as _unhandled_input: no dispatch while attacking or in a
## helpless mode.
func scan_specials() -> bool:
	if motions == null:
		return false
	if not Fighter.input_allowed(mode) or is_attacking():
		return false
	for m in motions.moves():
		if MotionMatcher.matches(m, motion_buffer, _input_tick):
			var seq := motions.lookup(m.move_id)
			if seq != null:
				start_move(seq)
				motion_buffer.clear()
				return true
	return false

## Fill the motion buffer from this frame's input EDGES (arcade update_joystat).
## stick `dir` is the 8-way direction; `buttons_held` is an OR of MotionBuffer.B_* bits.
func feed_input(dir: Vector2, buttons_held: int, facing_sign: float) -> void:
	_input_tick += 1
	var stick := MotionBuffer.encode_stick(dir, facing_sign)
	if stick != _prev_stick:
		motion_buffer.push(stick, _input_tick)        # stick-change edge
	var downs := buttons_held & ~_prev_buttons
	for bit in [MotionBuffer.B_PUNCH, MotionBuffer.B_BLOCK, MotionBuffer.B_SPUNCH,
			MotionBuffer.B_KICK, MotionBuffer.B_SKICK]:
		if (downs & bit) != 0:
			motion_buffer.push(bit | stick, _input_tick)   # button-down edge carries stick
	charge.update(buttons_held)
	_prev_stick = stick
	_prev_buttons = buttons_held

## OR of the attack buttons currently held (live input).
func _buttons_held_mask() -> int:
	var p := _action_prefix()
	var m := 0
	if _held(p + "punch"): m |= MotionBuffer.B_PUNCH
	if _held(p + "block"): m |= MotionBuffer.B_BLOCK
	if _held(p + "high_punch"): m |= MotionBuffer.B_SPUNCH
	if _held(p + "kick"): m |= MotionBuffer.B_KICK
	if _held(p + "high_kick"): m |= MotionBuffer.B_SKICK
	return m

func _held(action: String) -> bool:
	return InputMap.has_action(action) and Input.is_action_pressed(action)

## True only when the action exists in the map AND was just pressed. The has_action
## guard keeps Player 2 (which has no attack actions yet) from erroring on missing ones.
func _pressed(action: String) -> bool:
	return InputMap.has_action(action) and Input.is_action_just_pressed(action)
