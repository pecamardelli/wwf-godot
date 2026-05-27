class_name Fighter
extends CharacterBody2D
## Base fighter: depth-plane movement, facing, walk/idle animation.
## Movement input is supplied by subclasses via get_input_direction().

@export var walk_speed: float = 140.0
## Walkable depth band in global Y. The fighter's origin sits at its feet.
@export var floor_min_y: float = 360.0
@export var floor_max_y: float = 660.0
## Personal-space radii for soft separation: x = horizontal, y = depth.
## Depth is much smaller so fighters can stand close front-to-back.
@export var separation_radii: Vector2 = Vector2(50, 20)

@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")

func _ready() -> void:
	add_to_group("fighters")

## Subclasses override this to return an 8-way direction (each axis in -1..1).
func get_input_direction() -> Vector2:
	return Vector2.ZERO

func _physics_process(_delta: float) -> void:
	var dir: Vector2 = get_input_direction()
	velocity = MovementMath.walk_velocity(dir)
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

func _update_facing(dir: Vector2) -> void:
	if sprite == null:
		return
	if dir.x != 0.0:
		sprite.flip_h = dir.x < 0.0

func _update_animation(dir: Vector2) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var anim: String = "walk" if dir != Vector2.ZERO else "idle"
	if sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
		sprite.play(anim)
	elif not sprite.is_playing():
		sprite.play(anim)
