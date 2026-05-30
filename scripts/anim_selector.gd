class_name AnimSelector
## Pick the walk/idle animation base name from movement input + depth facing.
## Type comes from the movement axes (arcade legs key off MOVE_DIR); the _front/_back
## suffix comes from the depth facing. Horizontal flip is applied separately by
## Fighter.flip_h_for (idle/walk art is right-drawn). The `rotate` and `run` clips are
## handled by the fighter directly, not here.

## `depth` is Facing.FRONT or Facing.BACK; anything other than FRONT maps to _back.
## NOTE: "walk_horisontal" keeps the clip's legacy misspelling — it is the real animation
## key in doink_frames.tres; do NOT "correct" it to "horizontal" or the lookup breaks.
static func walk_anim(move_dir: Vector2, depth: int) -> String:
	var suffix := "_front" if depth == Facing.FRONT else "_back"
	var ix := signf(move_dir.x)
	var iy := signf(move_dir.y)
	if ix == 0.0 and iy == 0.0:
		return "idle" + suffix
	if ix != 0.0 and iy != 0.0:
		return "walk_diagonal" + suffix
	if iy != 0.0:
		return "walk_vertical" + suffix
	return "walk_horisontal" + suffix

## True when the fighter moves AGAINST the way its body faces (backpedal / strafe / moving away
## in depth), so the walk cycle should play in REVERSE — arcade legs follow MOVE_DIR while the
## torso holds FACING_DIR. Facing vector = (horizontal ±1, depth ±1: FRONT=+1 toward camera/down,
## BACK=-1 away/up). Dot < 0 means the movement opposes the facing.
static func is_reverse(move_dir: Vector2, facing: float, depth: int) -> bool:
	return move_dir.x * facing + move_dir.y * float(depth) < 0.0
