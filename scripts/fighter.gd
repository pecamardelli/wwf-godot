class_name Fighter
extends CharacterBody2D
## Base fighter: depth-plane movement, facing, walk/idle animation.
## Movement input is supplied by subclasses via get_input_direction().

@export var walk_speed: float = 140.0
## Walkable depth band in global Y. The fighter's origin sits at its feet.
@export var floor_min_y: float = 360.0
@export var floor_max_y: float = 660.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

## Subclasses override this to return an 8-way direction (each axis in -1..1).
func get_input_direction() -> Vector2:
	return Vector2.ZERO

func _physics_process(_delta: float) -> void:
	var dir: Vector2 = get_input_direction()
	velocity = MovementMath.move_velocity(dir, walk_speed)
	move_and_slide()
	global_position = MovementMath.clamp_to_floor(global_position, floor_min_y, floor_max_y)
	_update_facing(dir)
	_update_animation(dir)

func _update_facing(dir: Vector2) -> void:
	if dir.x != 0.0:
		sprite.flip_h = dir.x < 0.0

func _update_animation(dir: Vector2) -> void:
	if sprite.sprite_frames == null:
		return
	var anim: String = "walk" if dir != Vector2.ZERO else "idle"
	if sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
		sprite.play(anim)
	elif not sprite.is_playing():
		sprite.play(anim)
