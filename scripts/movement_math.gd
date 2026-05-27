class_name MovementMath
## Pure movement/depth helpers. No scene-tree dependencies, fully unit-testable.

## Arcade 8-way walk velocity in px/second. Uses the SIGN of each input axis;
## cardinal and diagonal use different per-axis speeds (arcade table, not normalized).
static func walk_velocity(input_dir: Vector2) -> Vector2:
	var ix: float = signf(input_dir.x)
	var iy: float = signf(input_dir.y)
	if ix == 0.0 and iy == 0.0:
		return Vector2.ZERO
	if ix != 0.0 and iy != 0.0:
		return Vector2(ix * ArcadeUnits.WALK_DIAGONAL_AXIS, iy * ArcadeUnits.WALK_DIAGONAL_AXIS)
	return Vector2(ix * ArcadeUnits.WALK_CARDINAL, iy * ArcadeUnits.WALK_CARDINAL)

## Clamp a position's Y into the walkable floor band [floor_min_y, floor_max_y].
static func clamp_to_floor(pos: Vector2, floor_min_y: float, floor_max_y: float) -> Vector2:
	return Vector2(pos.x, clampf(pos.y, floor_min_y, floor_max_y))

## Soft body separation against an ELLIPTICAL personal space (radii.x horizontal,
## radii.y depth). Depth radius is normally much smaller so fighters can line up
## close front-to-back. Returns how far THIS body should move to reach the ellipse
## edge, taking half so two bodies separating symmetrically close the whole gap.
## Returns ZERO when outside the ellipse.
static func separation_push(self_pos: Vector2, other_pos: Vector2, radii: Vector2) -> Vector2:
	var delta: Vector2 = self_pos - other_pos
	var rx: float = maxf(radii.x, 0.001)
	var ry: float = maxf(radii.y, 0.001)
	var ux: float = delta.x / rx
	var uy: float = delta.y / ry
	var nd: float = sqrt(ux * ux + uy * uy)
	if nd >= 1.0:
		return Vector2.ZERO
	if nd == 0.0:
		# Perfectly overlapping: pick a deterministic axis to break the tie.
		return Vector2(rx * 0.5, 0.0)
	# Scale delta out to the ellipse edge (factor 1/nd), self moves half of it.
	return delta * (1.0 / nd - 1.0) * 0.5
