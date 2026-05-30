class_name Fighter
extends CharacterBody2D
## Base fighter: depth-plane movement, facing, walk/idle animation.
## Movement input is supplied by subclasses via get_input_direction().

## PLYRMODE-style state (arcade PLYR.EQU MODE_*). Helpless modes never read input —
## that is exactly how the arcade disables control while stunned/down.
enum Mode { NORMAL, RUNNING, INAIR, ONGROUND, BLOCK, DIZZY, GRABBING, GRABBED, HEADHOLD, HEADHELD }
var mode: int = Mode.NORMAL

## Faction. Targeting only considers opposite-side fighters (arcade PLYR_SIDE).
enum Side { PLAYER, ENEMY }
@export var side: int = Side.PLAYER

## The opponent this fighter is currently targeting (drives facing + dispatch range).
var target: Fighter = null
## The fighter this one most recently landed a hit on (arcade WHOIHIT; targeting bias).
var _who_i_hit: Fighter = null
## Counter to stagger target recomputation across fighters.
var _target_tick: int = 0

## Input is only read in NORMAL/RUNNING (arcade: other mode_* handlers are rets).
static func input_allowed(m: int) -> bool:
	return m == Mode.NORMAL or m == Mode.RUNNING

## Walkable depth band in global Y. The fighter's origin sits at its feet.
@export var floor_min_y: float = 360.0
@export var floor_max_y: float = 660.0
## Personal-space radii for soft separation: x = horizontal, y = depth.
## Depth is much smaller so fighters can stand close front-to-back.
@export var separation_radii: Vector2 = Vector2(50, 20)

## --- Feel layer (deliberately NOT arcade-faithful) ---
## The arcade snaps velocity to the table value with no ramp. We slow the walk a
## touch (walk_speed_scale) and ease velocity in/out (walk_acceleration) so the
## footfall animation reads in sync instead of sliding. Both apply to cardinal
## AND diagonal — move_toward eases the whole velocity vector.
@export var walk_speed_scale: float = 0.8
@export var walk_acceleration: float = 2200.0  ## px/s^2 (accel + decel ramp; snappy)
## Depth (vertical/Y) walk runs slower than horizontal — belt-scroll convention.
@export var depth_speed_scale: float = 0.6

## Combat state.
var health: int = Damage.LIFE_MAX
var _facing: float = 1.0   # +1 faces right, -1 faces left; the sprite mirrors this
var _run_dir_x: float = 0.0   # latched horizontal run direction (+1/-1) while RUNNING
var _player: SequencePlayer = SequencePlayer.new()
var _react_timer: float = 0.0          # seconds left in a reaction (hitstun/getup/dizzy)
var _react_recover_mode: int = Mode.NORMAL
var _last_damage_time: float = -999.0  # seconds; for the ⅔ repeat window
var _hit_by_current_move: Array = []   # victims already hit by the swing in progress
var _sim_time: float = 0.0             # accumulated per-fighter sim clock (fixed-tick determinism)
var _grappling: Fighter = null     # the victim I am driving (puppet)
var _grappled_by: Fighter = null   # the attacker driving me
var _immobilize_time: float = 0.0   # seconds of generic stun (gates buffer specials/reversals)
var _last_headhold_time: float = -999.0   # _sim_time when last head-grabbed (2s re-grab cooldown)
var _headhold_break_time: float = 0.0   # seconds until the hold auto-releases
## The held headlock pose = last STANDING headlocks frame (sprite 07); frames 7-15 are
## the from-ground headlock, which the static hold must never animate into.
const _HEADHOLD_POSE_FRAME := 6

@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")

func _ready() -> void:
	add_to_group("fighters")

## Subclasses override this to return an 8-way direction (each axis in -1..1).
func get_input_direction() -> Vector2:
	return Vector2.ZERO

## Subclasses (Player) override to report the run button being held.
func wants_to_run() -> bool:
	return false

## Subclasses (Player) override to report the block button being held.
func wants_to_block() -> bool:
	return false

## True while guarding (blocking or about to block this tick). Used to freeze facing.
func _is_guarding() -> bool:
	return mode == Mode.BLOCK or ((mode == Mode.NORMAL or mode == Mode.RUNNING) and wants_to_block())

func is_attacking() -> bool:
	return _player.is_playing()

func is_dead() -> bool:
	return health <= 0

## Refresh `target` from the "fighters" group. Recompute immediately when we have
## no live target; otherwise only every 4th tick, staggered per fighter.
func _update_target() -> void:
	_target_tick += 1
	var stale: bool = target == null or not is_instance_valid(target) or target.is_dead()
	if not stale and (_target_tick % 4) != (get_instance_id() % 4):
		return
	target = Targeting.pick(self, get_tree().get_nodes_in_group("fighters"))

func _physics_process(delta: float) -> void:
	_sim_time += delta
	if _immobilize_time > 0.0:
		_immobilize_time = maxf(_immobilize_time - delta, 0.0)
	# Puppet victim: driven entirely by the captor; skip own simulation.
	if mode == Mode.GRABBED or mode == Mode.HEADHELD:
		return
	_update_target()
	if target != null and is_instance_valid(target) and not _is_guarding() and mode != Mode.RUNNING and (_grappling == null or not _player.is_playing()):
		_set_facing(target.global_position.x - global_position.x)
	# 1) Reaction countdown (hitstun / getup / dizzy): no control, no walk.
	if _react_timer > 0.0:
		_react_timer -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		global_position = MovementMath.clamp_to_floor(global_position, floor_min_y, floor_max_y)
		# Ease any release-rise render offset toward 0 (smooth rise out of the held pose).
		if _release_rise_y != 0.0:
			_release_rise_y = move_toward(_release_rise_y, 0.0, _RELEASE_RISE_SPEED * delta)
			_refresh_flip()
		if _react_timer <= 0.0:
			_release_rise_y = 0.0   # reaction over: drop any leftover rise offset
			if mode == Mode.ONGROUND and sprite != null and sprite.sprite_frames != null:
				var anim := "get_up_back" if _facing < 0.0 else "get_up_front"
				if sprite.sprite_frames.has_animation(anim):
					sprite.play(anim)
					_refresh_flip()
			mode = _react_recover_mode
		return

	# 2) Attacking: advance the sequence, hold position, no walk input.
	if _player.is_playing():
		velocity = Vector2.ZERO
		# Block recoil: a blocked grab nudges the attacker back once, away from the victim.
		if _player.blocked and not _block_recoiled:
			_block_recoiled = true
			_recoil_remaining = _BLOCK_RECOIL_DIST
		if _recoil_remaining > 0.0:
			var rstep: float = minf(_BLOCK_RECOIL_SPEED * delta, _recoil_remaining)
			global_position.x -= _facing * rstep    # _facing points at the victim; recoil away
			_recoil_remaining -= rstep
		# Grapple windup: a short, ACCELERATED step toward the opponent before the grab
		# connects (arcade LEAPATOPP) — ramps up like a walk, stops ~40px short, and travels
		# at most _GRAPPLE_LEAP_MAX total. Not a full-speed run-in.
		if _player.sequence != null and _player.sequence.is_grapple and _grappling == null \
				and target != null and is_instance_valid(target):
			var dx: float = target.global_position.x - global_position.x
			var want_close: bool = absf(dx) > _GRAPPLE_LEAP_GAP and _leap_remaining > 0.0
			var goal_vx: float = (signf(dx) * ArcadeUnits.WALK_CARDINAL * walk_speed_scale) if want_close else 0.0
			_leap_vel = move_toward(_leap_vel, goal_vx, walk_acceleration * delta)
			var step_x: float = clampf(_leap_vel * delta, -_leap_remaining, _leap_remaining)
			global_position.x += step_x
			_leap_remaining -= absf(step_x)
		_player.advance(delta)
		# Drive the attached victim AFTER advance so current_frame() reflects this tick.
		if _grappling != null and is_instance_valid(_grappling):
			_drive_victim(delta)
		if not _player.is_playing():
			_hit_by_current_move.clear()
			if _grappling != null and mode != Mode.HEADHOLD:
				_detach_victim()   # safety: a THROW that ended without a DETACH frame
			if mode == Mode.GRABBING:
				mode = Mode.NORMAL   # attacker freed once the throw/follow-up sequence ends
		_play_sequence_anim()
		return

	# Head-hold: holder stands and holds the lock pose. Follow-ups are dispatched by
	# Player before super(); countdown to auto-break.
	if mode == Mode.HEADHOLD:
		_headhold_break_time = maxf(_headhold_break_time - delta, 0.0)
		if _headhold_break_time <= 0.0:
			_break_head_hold()
			return
		velocity = Vector2.ZERO
		move_and_slide()
		global_position = MovementMath.clamp_to_floor(global_position, floor_min_y, floor_max_y)
		# Sustain the final STANDING headlock pose (frame 6); the 16-frame headlocks clip
		# continues into the from-ground headlock (7-15), so pin the frame, never play it.
		if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation("headlocks"):
			sprite.animation = "headlocks"
			sprite.pause()
			sprite.frame = mini(_HEADHOLD_POSE_FRAME, sprite.sprite_frames.get_frame_count("headlocks") - 1)
			_refresh_flip()
		# Keep the victim attached and LOOP its struggle (arcade master_keep_attached +
		# the headheld loop). The neck-grab sequence drove the cinch; during the static
		# hold the captor's sequence isn't playing, so drive the victim here.
		if _grappling != null and is_instance_valid(_grappling):
			_hold_victim()
		return

	# Block: hold to guard (no move, no attack). Front damage -> 1 (handled in receive_hit).
	if (mode == Mode.NORMAL or mode == Mode.RUNNING or mode == Mode.BLOCK) and wants_to_block():
		mode = Mode.BLOCK
		velocity = Vector2.ZERO
		move_and_slide()
		global_position = MovementMath.clamp_to_floor(global_position, floor_min_y, floor_max_y)
		_animate_block()
		return
	elif mode == Mode.BLOCK:
		mode = Mode.NORMAL
		_block_bouncing = false

	# 3) Normal movement (Plan 2a feel layer).
	var dir: Vector2 = Vector2.ZERO
	if Fighter.input_allowed(mode):
		dir = get_input_direction()
		# Start a run latch on a run-key PRESS (GMS 'trot'); direction = pressed, else facing.
		if mode != Mode.RUNNING and wants_to_run():
			mode = Mode.RUNNING
			_run_dir_x = signf(dir.x) if dir.x != 0.0 else signf(_facing)
		if mode == Mode.RUNNING:
			# Pressing the OPPOSITE direction stops the run (GMS run.gml).
			if signf(dir.x) != 0.0 and signf(dir.x) == -signf(_run_dir_x):
				mode = Mode.NORMAL
			else:
				_set_facing(_run_dir_x)   # face the run direction (no moonwalk)
				var run_vel := Vector2(_run_dir_x * ArcadeUnits.RUN_SPEED, signf(dir.y) * ArcadeUnits.RUN_DEPTH_DRIFT)
				velocity = velocity.move_toward(run_vel, walk_acceleration * delta)
		if mode != Mode.RUNNING:
			var walk_vel: Vector2 = MovementMath.walk_velocity(dir) * walk_speed_scale
			walk_vel.y *= depth_speed_scale
			var rel := RelativeInput.resolve(dir, _facing)
			var target_down: bool = target != null and is_instance_valid(target) and target.mode == Mode.ONGROUND
			walk_vel.x *= walk_dir_multiplier(rel.away, target_down)
			velocity = velocity.move_toward(walk_vel, walk_acceleration * delta)
	else:
		# Stun cuts control instantly (arcade): no coasting while helpless.
		velocity = Vector2.ZERO
	move_and_slide()
	_apply_separation()
	global_position = MovementMath.clamp_to_floor(global_position, floor_min_y, floor_max_y)
	# Target-facing is authoritative; fall back to movement-based facing only when untargeted.
	if target == null or not is_instance_valid(target):
		_update_facing(dir)
	_update_animation(dir)

## Nudge away from any overlapping fighters so bodies touch but never stack.
func _apply_separation() -> void:
	var push: Vector2 = Vector2.ZERO
	for other in get_tree().get_nodes_in_group("fighters"):
		if other == self:
			continue
		push += MovementMath.separation_push(global_position, other.global_position, separation_radii)
	global_position += push

## Reaction/defensive anims whose source art is drawn facing LEFT (opposite the
## action anims). flip_h is inverted for these so they render toward _facing.
const _LEFT_DRAWN := {
	"defence": true,
	"facepunched_front": true, "facepunched_back": true,
	"shoved": true, "droped": true, "damage_lying": true, "stuned": true,
	"get_up_front": true, "get_up_back": true,
}

## Correct flip_h for an animation given facing: left-drawn art is inverted.
static func flip_h_for(anim: String, facing: float) -> bool:
	if _LEFT_DRAWN.has(anim):
		return facing > 0.0
	return facing < 0.0

## Per-animation vertical RENDER offset (px, +down) for imported frames whose art sits
## off the feet origin. `damage_lying` is drawn ~40px above the feet, so nudge it down to
## the floor line; the body lies ON the mat instead of floating above it.
const _ANIM_Y_OFFSET := {
	"damage_lying": 40.0,
	# Held headlock victim is drawn off its feet origin (bent-over pose sits high in the frame);
	# nudge it down so the head sits at the captor's arm instead of floating up. The arcade gets
	# this from the per-frame Y attach term (ANI_SUPERSLAVE2 ATTACH_YOFF) we can't read directly.
	"headlocked": 45.0,
}

## Per-FRAME horizontal RENDER offset (px, source-art space) that pins a held animation's grip
## point so it doesn't drift frame-to-frame. The arcade re-derives this every frame from the
## victim's sprite hotspot (ANI_SUPERSLAVE2 victimXoff); we bake it from our art instead.
## headlocked: lock the NECK (the gripped head = the body's left edge near the top; the right
## edge is the struggling arm and must keep moving). Values are zero-mean (mean(edge) - edge[i]),
## GENERATED by tools/anchor_probe.gd — do not hand-edit (a hand-typed table with the wrong range
## is what added the wobble). Regenerate if the headlocked art changes.
const _ANIM_FRAME_X_OFFSET := {
	"headlocked": [-2.0, -2.0, -1.0, 2.0, 2.0, 1.0, 0.0, -3.0],
}

## Apply the correct flip + render offset for the current animation + facing.
func _refresh_flip() -> void:
	if sprite != null:
		sprite.flip_h = flip_h_for(sprite.animation, _facing)
		# Base per-anim Y offset + a transient "rise" offset, so a freed headlock victim eases up
		# from the lowered held pose instead of popping up the instant the held offset vanishes.
		sprite.offset.y = _ANIM_Y_OFFSET.get(sprite.animation, 0.0) + _release_rise_y
		# Per-frame grip-anchor correction (kills frame-to-frame drift). Measured in source-art
		# space; when the sprite is flipped the texture mirrors, so negate to keep the grip point
		# fixed in world space. Flip is constant during a hold, so this removes the wobble.
		var fx: Variant = _ANIM_FRAME_X_OFFSET.get(sprite.animation)
		var ox := 0.0
		if fx != null and sprite.frame >= 0 and sprite.frame < fx.size():
			ox = fx[sprite.frame]
			if sprite.flip_h:
				ox = -ox   # texture mirrored: negate so the grip holds in world space
		sprite.offset.x = ox

## Facing as ±1 (right = +1). Logic-side; the sprite flip mirrors it.
func facing() -> float:
	return _facing

## Set facing from a signed value; mirror to the sprite if present.
func _set_facing(f: float) -> void:
	if f == 0.0:
		return
	_facing = signf(f)
	_refresh_flip()

func _update_facing(dir: Vector2) -> void:
	if dir.x != 0.0:
		_set_facing(dir.x)

## Turn toward the nearest other fighter (called when a move starts).
func _face_nearest_opponent() -> void:
	var best := INF
	var toward := 0.0
	for f in get_tree().get_nodes_in_group("fighters"):
		if f == self:
			continue
		var dx: float = f.global_position.x - global_position.x
		if absf(dx) < best:
			best = absf(dx)
			toward = dx
	if toward != 0.0:
		_set_facing(toward)

func _update_animation(dir: Vector2) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var anim: String
	if mode == Mode.RUNNING:
		anim = "run"
	elif dir != Vector2.ZERO:
		anim = "walk_horisontal_front"
	else:
		anim = "idle_front"
	if sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
		sprite.play(anim)
	elif not sprite.is_playing():
		sprite.play(anim)
	_refresh_flip()

## Walk-speed multiplier from facing-relative state (arcade walk table modifiers).
func walk_dir_multiplier(moving_away: bool, target_down: bool) -> float:
	var m := 1.0
	if moving_away:
		m *= ArcadeUnits.BACKWARD_MULT
	if target_down:
		m *= ArcadeUnits.OPP_DOWN_MULT
	return m

## Begin a move sequence (ignored while attacking-uninterruptable or in a reaction).
func start_move(move: MoveSequence) -> void:
	if _react_timer > 0.0:
		return
	if _player.is_playing() and _player.sequence.uninterruptable:
		return
	if mode == Mode.RUNNING:
		mode = Mode.NORMAL   # starting an attack ends a run (arcade/GMS)
	# Continuous target-facing is authoritative; only snap-face when untargeted.
	# Grapple sequences skip the snap: the attacker already faces the victim at grab time.
	if not move.is_grapple and (target == null or not is_instance_valid(target)):
		_face_nearest_opponent()
	if move.is_grapple:
		_leap_remaining = _GRAPPLE_LEAP_MAX   # fresh short step-in budget for this grab
		_leap_vel = 0.0
		_recoil_remaining = 0.0
		_block_recoiled = false
	_player.play(move)
	_hit_by_current_move.clear()
	_play_sequence_anim()

## Drive the attached victim from the current SequenceFrame's slave track + intents.
func _drive_victim(_delta: float) -> void:
	var vic: Fighter = _grappling
	var f: SequenceFrame = _player.current_frame()
	# Orient the victim to the attacker (arcade ANI_SUPERSLAVE2: victim flip = attacker
	# facing XOR per-frame table flip; we have no per-frame flip, so mirror facing). Set
	# unconditionally so the puppet never keeps its pre-grab (opponent-facing) orientation.
	vic._facing = _facing
	# Position the victim relative to me (x mirrored by facing).
	if f != null:
		var off := f.victim_offset
		vic.global_position = global_position + Vector2(off.x * _facing, -off.y)
	# A driven puppet is GHOST for the whole throw (arcade ANI_SETOPPMODE,MODE_GHOST at
	# grab, cleared at release): its position is FULLY master-controlled, NOT floor-clamped,
	# so the lift arc isn't pinned to the floor band. It is grounded again on DETACH.
	if _player.consume_set_opp_mode():
		vic.mode = _player.opp_mode()
	if _player.consume_clr_opp_mode():
		vic.mode = Mode.GRABBED
	# Slave animation frame.
	if vic.sprite != null and vic.sprite.sprite_frames != null and _player.slave_anim != "":
		if vic.sprite.sprite_frames.has_animation(_player.slave_anim):
			if vic.sprite.animation != _player.slave_anim:
				vic.sprite.animation = _player.slave_anim
			vic.sprite.pause()
			if f != null:
				var last: int = vic.sprite.sprite_frames.get_frame_count(_player.slave_anim) - 1
				vic.sprite.frame = clampi(f.victim_anim_frame, 0, maxi(last, 0))
			vic._refresh_flip()   # flip the slave pose to the attacker's facing
	# DAMAGE_OPP: pre-scaled puppet damage, applied once.
	if _player.consume_damage_opp():
		var key: String = _player.sequence.id
		var dmg: int = Damage.GRAPPLE_DAMAGE.get(key, 20)
		vic.health = Damage.apply_health(vic.health, dmg)
		vic._last_damage_time = vic._sim_time
	# DETACH: release the victim into a knockdown, clear both refs.
	if _player.consume_detach():
		_detach_victim()

## Victim offset (in front of the captor) while held in the static headlock. The arcade head-hold
## #puppet_tbl #Doink raw X=51 (DNKSEQ3.ASM:1549) is in the arcade's sprite-anchor space; our
## sprites are anchored differently, so we add the +30 anchor-space correction (the arcade's
## per-frame victimXoff-attackerXoff term) measured in playtest. Grips the bent-over head.
const _HEADHOLD_VICTIM_X := 81.0
## Grab "leap" (arcade LEAPATOPP): step in toward the target, stopping ~Xoff=40 short,
## and travel at most MAX_X_DIST=40 total — a short, accelerated step, not a run-in.
const _GRAPPLE_LEAP_GAP := 40.0   # stop this far from the target (arcade Xoff=40)
const _GRAPPLE_LEAP_MAX := 40.0   # cap total step distance (arcade MAX_X_DIST=40)
var _leap_vel: float = 0.0        # accelerated step-in velocity (px/s)
var _leap_remaining: float = 0.0  # px of step-in budget left this grab
## Block recoil (arcade #missedb ANI_SET_YVEL): our fighters are floor-clamped with no
## jump, so a blocked grab nudges the attacker straight back instead of hopping up.
const _BLOCK_RECOIL_DIST := 12.0   # px of backward recoil (tuned in playtest)
const _BLOCK_RECOIL_SPEED := 140.0 # px/s of recoil travel
var _recoil_remaining: float = 0.0
var _block_recoiled: bool = false  # latch so the recoil fires once per blocked grab

## Arcade head-held struggle loop cadence: D3BF3A plays at 4 ticks/frame (DNKSEQ3.ASM #loop).
const _HEADHELD_LOOP_TICKS := 4

## During the STATIC head hold, keep the victim attached + facing the captor and LOOP its
## struggle (arcade master_keep_attached + the headheld loop). The neck-grab sequence drives
## the cinch; once it ends the captor isn't "playing", so the victim is driven from here.
func _hold_victim() -> void:
	var vic: Fighter = _grappling
	vic._facing = _facing
	vic.global_position = global_position + Vector2(_HEADHOLD_VICTIM_X * _facing, 0.0)
	vic.global_position = MovementMath.clamp_to_floor(vic.global_position, vic.floor_min_y, vic.floor_max_y)
	if vic.sprite != null and vic.sprite.sprite_frames != null and vic.sprite.sprite_frames.has_animation("headlocked"):
		# Drive the struggle loop MANUALLY (paused): a free-running sprite advances on its own
		# timer, so the per-frame grip offset (set in _refresh_flip) lags the displayed frame by
		# up to a frame and the victim jitters forward/back. Setting the frame + its offset
		# together each tick keeps the grip pinned. Cadence = arcade D3BF3A 4 ticks/frame
		# (DNKSEQ3.ASM #loop).
		var n: int = maxi(vic.sprite.sprite_frames.get_frame_count("headlocked"), 1)
		var per: float = ArcadeUnits.ticks_to_seconds(_HEADHELD_LOOP_TICKS)
		vic.sprite.animation = "headlocked"
		vic.sprite.pause()
		vic.sprite.frame = int(vic._sim_time / per) % n
		vic._refresh_flip()   # grip offset for THIS frame, same tick

## Release the current victim to ONGROUND (knockdown) and clear both refs.
func _detach_victim() -> void:
	var vic: Fighter = _grappling
	_grappling = null
	if vic != null and is_instance_valid(vic):
		vic._grappled_by = null
		vic.mode = Mode.ONGROUND
		vic._react_recover_mode = Mode.NORMAL
		vic._react_timer = ArcadeUnits.ticks_to_seconds(AMode.getup_ticks(AMode.Family.KNOCKDOWN))
		if vic.sprite != null and vic.sprite.sprite_frames != null and vic.sprite.sprite_frames.has_animation("damage_lying"):
			vic.sprite.play("damage_lying")
			vic._refresh_flip()

const _MASH_REDUCE := 0.08   # seconds shaved per mash press (arcade GETUP mash)
const _BLOCK_READY_FRAME := 2     # "sprite number 3": the held guard pose
const _BLOCK_KNOCKBACK := 6.0     # small bounce-back when a hit is blocked
var _block_bouncing: bool = false

func set_immobilize_ticks(ticks: int) -> void:
	_immobilize_time = ArcadeUnits.ticks_to_seconds(ticks)

func _set_headhold_break_ticks(ticks: int) -> void:
	_headhold_break_time = ArcadeUnits.ticks_to_seconds(ticks)

## Release a head hold: the captor returns to NORMAL; the freed victim staggers back as if
## struck rather than snapping to idle (arcade dnk_3_head_held_brk_anim shoves the victim away
## and plays a head-hit reaction, DNKSEQ3.ASM).
func _break_head_hold() -> void:
	var vic: Fighter = _grappling
	_grappling = null
	mode = Mode.NORMAL
	if vic != null and is_instance_valid(vic):
		vic._release_with_stagger(_facing)

## Head-hit stagger when released from a head hold (arcade ANI_SET_XVEL away + D2AH2A head hit
## from dnk_3_head_held_brk_anim). Shoved away from the captor, plays a hit reaction, recovers.
const _HEADHOLD_RELEASE_PUSH := 14.0          # px shoved away from the captor on release
const _HEADHOLD_RELEASE_STAGGER_TICKS := 14   # stagger duration before recovering to NORMAL
## Transient vertical RENDER offset eased to 0 during a reaction. Set on head-hold release to the
## held pose's lowered offset so the freed victim rises smoothly instead of snapping up a frame.
var _release_rise_y: float = 0.0
const _RELEASE_RISE_SPEED := 180.0            # px/s the held offset eases out on release
func _release_with_stagger(captor_facing: float) -> void:
	_grappled_by = null
	mode = Mode.NORMAL
	global_position.x += captor_facing * _HEADHOLD_RELEASE_PUSH   # shoved away from the captor
	global_position = MovementMath.clamp_to_floor(global_position, floor_min_y, floor_max_y)
	_react_recover_mode = Mode.NORMAL
	_react_timer = ArcadeUnits.ticks_to_seconds(_HEADHOLD_RELEASE_STAGGER_TICKS)
	# Start the stagger art at the held pose's lowered height, then ease up (no instant pop).
	_release_rise_y = _ANIM_Y_OFFSET.get("headlocked", 0.0)
	if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation("damage_front"):
		sprite.play("damage_front")
		_refresh_flip()

func is_immobilized() -> bool:
	return _immobilize_time > 0.0

## Called when the player presses anything while downed — speeds up getup.
func mash_recover() -> void:
	if mode == Mode.ONGROUND and _react_timer > 0.0:
		_react_timer = maxf(_react_timer - _MASH_REDUCE, 0.0)

## The live attack box this tick, or null.
func current_attack_box() -> Box3:
	return _player.active_attack_box if _player.attack_live else null

func hurt_box() -> Box3:
	return Hitbox.hurt_box_for_mode(mode)

func already_hit(victim: Node) -> bool:
	return _hit_by_current_move.has(victim)

## The move currently playing (used by the resolver to read attack_mode). May be null.
func current_move() -> MoveSequence:
	return _player.sequence

## Apply a landed hit from `attacker` using `move`. Called by AttackResolver.
func receive_hit(attacker: Fighter, move: MoveSequence) -> void:
	# A victim already in a reaction CAN be re-hit by a different swing (juggling) - intentional for 2b.
	attacker._hit_by_current_move.append(self)
	attacker._who_i_hit = self   # arcade WHOIHIT: bias attacker's targeting toward who it just hit
	var now := _sim_time
	var repeat := (now - _last_damage_time) <= ArcadeUnits.ticks_to_seconds(Damage.REPEAT_WINDOW_TICKS)
	var blocked := mode == Mode.BLOCK
	var dmg := Damage.resolve(move.attack_mode, repeat, blocked)
	health = Damage.apply_health(health, dmg)
	_last_damage_time = now

	var hit_dir := Hitbox.hit_side(attacker.global_position, global_position)
	if blocked:
		# Absorbed while guarding: stay in BLOCK, bounce back slightly, play the block-bounce anim.
		global_position.x += hit_dir * _BLOCK_KNOCKBACK
		_start_block_bounce()
		return
	var family := AMode.reaction_for(move.attack_mode)
	var r := Reaction.resolve(family, hit_dir, move.causes_dizzy)
	_enter_reaction(r, hit_dir)

## Bind `attacker` as my captor. A neck grab enters the persistent HEAD HOLD
## (HEADHOLD/HEADHELD); every other grab is a throw (GRABBING/GRABBED). Called by
## AttackResolver when a grab box connects.
func receive_grab(attacker: Fighter, move: MoveSequence) -> void:
	_player.play(null)                 # cancel anything I was doing
	_hit_by_current_move.clear()
	_react_timer = 0.0
	_grappled_by = attacker
	attacker._grappling = self
	attacker._player.notify_grab_connected()
	if move != null and move.id == "neck_grab":
		mode = Mode.HEADHELD
		attacker.mode = Mode.HEADHOLD
		attacker._set_headhold_break_ticks(180)   # ~3.4s hold window (arcade head_held_brk)
		if self is Player:
			(self as Player).motion_buffer.clear()   # arcade clear_opp_counts
		_last_headhold_time = _sim_time              # 2s re-grab cooldown stamp
	else:
		mode = Mode.GRABBED
		attacker.mode = Mode.GRABBING

## Block stance: crouch into the guard then FREEZE at the ready frame. On a blocked
## hit (_block_bouncing) play through to the last frame, then settle back to ready.
## Mirrors GMS block_sprites (freeze at frame 2, bounce on impact).
func _animate_block() -> void:
	if sprite == null or sprite.sprite_frames == null or not sprite.sprite_frames.has_animation("defence"):
		return
	if sprite.animation != "defence":
		sprite.animation = "defence"
		sprite.frame = 0
		sprite.play("defence")   # crouch into the guard, frozen below once it reaches ready
	_refresh_flip()   # defence art is left-drawn; render toward _facing
	var last := sprite.sprite_frames.get_frame_count("defence") - 1
	if _block_bouncing:
		if sprite.frame >= last:
			_block_bouncing = false
			sprite.frame = _BLOCK_READY_FRAME
			sprite.pause()
		# else: let the bounce keep playing toward `last`
	elif sprite.frame >= _BLOCK_READY_FRAME:
		sprite.frame = _BLOCK_READY_FRAME
		sprite.pause()           # hold the ready guard pose
	# else: still crouching in (frame < ready) -> keep playing

## Start the block-bounce from the ready frame (called on a blocked hit).
func _start_block_bounce() -> void:
	_block_bouncing = true
	if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation("defence"):
		sprite.animation = "defence"
		sprite.frame = _BLOCK_READY_FRAME
		sprite.play("defence")

func _enter_reaction(r: Dictionary, hit_dir: int) -> void:
	_player.play(null)                       # cancel any move in progress
	_hit_by_current_move.clear()             # a cancelled move leaves no stale hit-list
	mode = r.mode
	global_position.x += hit_dir * r.knockback  # push the victim AWAY from the attacker
	_react_recover_mode = Mode.NORMAL
	_react_timer = ArcadeUnits.ticks_to_seconds(maxi(r.hitstun_ticks, r.getup_ticks))
	if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(r.anim):
		sprite.play(r.anim)
		_refresh_flip()

## Puppet-style playback: the SEQUENCE drives which sprite frame shows, so the
## hitbox window and the visible frame share one clock. We pause auto-advance and
## set the frame from the current SequenceFrame.anim_frame each tick.
func _play_sequence_anim() -> void:
	if sprite == null or _player.sequence == null:
		return
	var anim: String = _player.sequence.anim_name
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(anim):
		return
	if sprite.animation != anim:
		sprite.animation = anim
	_refresh_flip()
	if sprite.is_playing():
		sprite.pause()
	var f: SequenceFrame = _player.current_frame()
	if f != null:
		var last: int = sprite.sprite_frames.get_frame_count(anim) - 1
		sprite.frame = clampi(f.anim_frame, 0, maxi(last, 0))
