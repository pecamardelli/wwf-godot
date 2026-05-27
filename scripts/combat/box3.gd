class_name Box3
extends Resource
## A combat box in a fighter's local frame: offset.x extends toward facing.
## Axis mapping to our 2D world: X = position.x, Y = height off ground, Z = position.y (depth).

@export var offset: Vector3 = Vector3.ZERO
@export var size: Vector3 = Vector3.ZERO

## World-space AABB for `box` on a fighter at `pos`, facing ±1, at `height` (0 grounded).
static func world_aabb(box: Box3, pos: Vector2, facing: float, height: float) -> AABB:
	var centre := Vector3(pos.x + facing * box.offset.x, height + box.offset.y, pos.y + box.offset.z)
	return AABB(centre - box.size * 0.5, box.size)
