class_name MovementMath
## Pure movement/depth helpers. No scene-tree dependencies, fully unit-testable.

## Velocity for an 8-way input direction at the given speed.
## Diagonals are normalized so speed is constant in every direction.
static func move_velocity(input_dir: Vector2, speed: float) -> Vector2:
	if input_dir == Vector2.ZERO:
		return Vector2.ZERO
	return input_dir.normalized() * speed

## Clamp a position's Y into the walkable floor band [floor_min_y, floor_max_y].
static func clamp_to_floor(pos: Vector2, floor_min_y: float, floor_max_y: float) -> Vector2:
	return Vector2(pos.x, clampf(pos.y, floor_min_y, floor_max_y))
