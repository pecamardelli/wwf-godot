class_name Fighter
extends CharacterBody2D
## Base fighter: depth-plane movement, facing, walk/idle animation.
## Movement input is supplied by subclasses via get_input_direction().

## PLYRMODE-style state (arcade PLYR.EQU MODE_*). Helpless modes never read input —
## that is exactly how the arcade disables control while stunned/down.
enum Mode { NORMAL, RUNNING, INAIR, ONGROUND, BLOCK, DIZZY }
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
@export var walk_acceleration: float = 1100.0  ## px/s^2
## Depth (vertical/Y) walk runs slower than horizontal — belt-scroll convention.
@export var depth_speed_scale: float = 0.6

## Combat state.
var health: int = Damage.LIFE_MAX
var _facing: float = 1.0   # +1 faces right, -1 faces left; the sprite mirrors this
var _player: SequencePlayer = SequencePlayer.new()
var _react_timer: float = 0.0          # seconds left in a reaction (hitstun/getup/dizzy)
var _react_recover_mode: int = Mode.NORMAL
var _last_damage_time: float = -999.0  # seconds; for the ⅔ repeat window
var _hit_by_current_move: Array = []   # victims already hit by the swing in progress
var _sim_time: float = 0.0             # accumulated per-fighter sim clock (fixed-tick determinism)

@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")

func _ready() -> void:
	add_to_group("fighters")

## Subclasses override this to return an 8-way direction (each axis in -1..1).
func get_input_direction() -> Vector2:
	return Vector2.ZERO

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
	_update_target()
	if target != null and is_instance_valid(target):
		_set_facing(target.global_position.x - global_position.x)
	# 1) Reaction countdown (hitstun / getup / dizzy): no control, no walk.
	if _react_timer > 0.0:
		_react_timer -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		global_position = MovementMath.clamp_to_floor(global_position, floor_min_y, floor_max_y)
		if _react_timer <= 0.0:
			mode = _react_recover_mode
		return

	# 2) Attacking: advance the sequence, hold position, no walk input.
	if _player.is_playing():
		velocity = Vector2.ZERO
		_player.advance(delta)
		if not _player.is_playing():
			_hit_by_current_move.clear()
		_play_sequence_anim()
		return

	# 3) Normal movement (Plan 2a feel layer).
	var dir: Vector2 = Vector2.ZERO
	if Fighter.input_allowed(mode):
		dir = get_input_direction()
		var walk_vel: Vector2 = MovementMath.walk_velocity(dir) * walk_speed_scale
		walk_vel.y *= depth_speed_scale
		velocity = velocity.move_toward(walk_vel, walk_acceleration * delta)
	else:
		# Stun cuts control instantly (arcade): no coasting while helpless.
		velocity = Vector2.ZERO
	move_and_slide()
	_apply_separation()
	global_position = MovementMath.clamp_to_floor(global_position, floor_min_y, floor_max_y)
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

## Facing as ±1 (right = +1). Logic-side; the sprite flip mirrors it.
func facing() -> float:
	return _facing

## Set facing from a signed value; mirror to the sprite if present.
func _set_facing(f: float) -> void:
	if f == 0.0:
		return
	_facing = signf(f)
	if sprite != null:
		sprite.flip_h = _facing < 0.0

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
	var anim: String = "walk_horisontal_front" if dir != Vector2.ZERO else "idle_front"
	if sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
		sprite.play(anim)
	elif not sprite.is_playing():
		sprite.play(anim)

## Begin a move sequence (ignored while attacking-uninterruptable or in a reaction).
func start_move(move: MoveSequence) -> void:
	if _react_timer > 0.0:
		return
	if _player.is_playing() and _player.sequence.uninterruptable:
		return
	_face_nearest_opponent()
	_player.play(move)
	_hit_by_current_move.clear()
	_play_sequence_anim()

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
	var now := _sim_time
	var repeat := (now - _last_damage_time) <= ArcadeUnits.ticks_to_seconds(Damage.REPEAT_WINDOW_TICKS)
	var blocked := mode == Mode.BLOCK
	var dmg := Damage.resolve(move.attack_mode, repeat, blocked)
	health = Damage.apply_health(health, dmg)
	_last_damage_time = now

	var hit_dir := Hitbox.hit_side(attacker.global_position, global_position)
	var family := AMode.Family.BLOCK if blocked else AMode.reaction_for(move.attack_mode)
	var r := Reaction.resolve(family, hit_dir, move.causes_dizzy and not blocked)
	_enter_reaction(r, hit_dir)

func _enter_reaction(r: Dictionary, hit_dir: int) -> void:
	_player.play(null)                       # cancel any move in progress
	_hit_by_current_move.clear()             # a cancelled move leaves no stale hit-list
	mode = r.mode
	global_position.x += hit_dir * r.knockback  # push the victim AWAY from the attacker
	_react_recover_mode = Mode.NORMAL
	_react_timer = ArcadeUnits.ticks_to_seconds(maxi(r.hitstun_ticks, r.getup_ticks))
	if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(r.anim):
		sprite.play(r.anim)

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
	if sprite.is_playing():
		sprite.pause()
	var f: SequenceFrame = _player.current_frame()
	if f != null:
		var last: int = sprite.sprite_frames.get_frame_count(anim) - 1
		sprite.frame = clampi(f.anim_frame, 0, maxi(last, 0))
