class_name Enemy
extends Fighter
## A Fighter driven by an AIController instead of player input. Movement, run, and block are
## fed through the inherited input virtuals; strikes and grabs are started directly. The
## side-agnostic AttackResolver connects hits and grabs exactly as it does for a Player.

const _MOVES := preload("res://assets/movetables/doink.tres")
## Grab pool the AI can perform (id -> grapple sequence). decide() emits these ids.
const _GRABS := {
	"neck_grab": preload("res://assets/sequences/doink/neck_grab.tres"),
	"hip_toss": preload("res://assets/sequences/doink/hip_toss.tres"),
}

@export var profile: AIProfile

var _ai := AIController.new()
var _intent := AIIntent.new()
var _last_health: int = 0
var _consecutive_incoming: int = 0
var _target_was_attacking: bool = false

func _ready() -> void:
	super()
	if profile == null:
		profile = AIProfile.new()
	_last_health = health

## Movement/run/block come from the latest intent via the inherited Fighter hooks.
func get_input_direction() -> Vector2:
	return _intent.move_dir

func wants_to_run() -> bool:
	return _intent.want_run

func wants_to_block() -> bool:
	return _intent.action == AIIntent.Action.BLOCK

func _physics_process(delta: float) -> void:
	# Puppet victim (held/thrown): driven by the captor; no AI this frame.
	if mode == Mode.GRABBED:
		super(delta)
		return
	if mode == Mode.HEADHELD:
		if not is_immobilized() and not is_dead() and _grappled_by != null \
				and is_instance_valid(_grappled_by) \
				and AIController.should_reverse(profile.skill, profile.reversal_skill, _ai.rng.randf()):
			reverse_into_grappler(_grappled_by, _GRABS["hip_toss"])
		super(delta)
		return
	_intent = _ai.decide(_build_perception(), profile, delta)
	if Fighter.input_allowed(mode) and not is_attacking():
		match _intent.action:
			AIIntent.Action.STRIKE:
				var seq: MoveSequence = _MOVES.lookup(_current_range(), _current_dir(), _intent.button)
				if seq != null:
					start_move(seq)
			AIIntent.Action.GRAB:
				var g: MoveSequence = _GRABS.get(_intent.move_id, null)
				if g != null:
					start_move(g)
	super(delta)
	_last_health = health

## Snapshot the world into the primitives the AIController consumes (no node refs leak in).
func _build_perception() -> Dictionary:
	var event := AIController.Event.NONE
	if target != null and is_instance_valid(target):
		var dropped := _last_health - health
		var attacking: bool = target.is_attacking()
		if attacking and not _target_was_attacking:
			_consecutive_incoming += 1          # a new distinct swing (rising edge)
		elif not attacking:
			_consecutive_incoming = 0           # reset between swings
		_target_was_attacking = attacking
		# big-hit / low-health events drive early stance flips
		if dropped >= 12:
			event = AIController.Event.BIG_HIT
		elif float(health) / float(Damage.LIFE_MAX) < 0.3:
			event = AIController.Event.LOW_HEALTH
		elif _ally_count() > 1:
			event = AIController.Event.MOBBED
		return {
			"dx": target.global_position.x - global_position.x,
			"dz": target.global_position.y - global_position.y,
			"target_attacking": attacking,
			"ally_count": _ally_count(),
			"repeat_count": _consecutive_incoming,
			"event": event,
		}
	_consecutive_incoming = 0
	_target_was_attacking = false
	return {"dx": 9999.0, "dz": 0.0, "target_attacking": false,
		"ally_count": 1, "repeat_count": 0, "event": event}

## Living fighters on my side (mobbing the player drives the crowd-difficulty hook).
func _ally_count() -> int:
	var n := 0
	for f in get_tree().get_nodes_in_group("fighters"):
		if f is Fighter and f.side == side and not f.is_dead():
			n += 1
	return n
