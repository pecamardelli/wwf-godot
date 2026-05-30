class_name AnimSelector
## Walk/idle animation selection + play direction, ported from the GMS `update_sprites`.
## - The _front/_back suffix ("position") comes from depth facing (toward/away the camera).
## - Horizontal flip is applied separately by Fighter.flip_h_for from `facing`.
## - There is only ONE diagonal sprite (drawn on a single diagonal axis). GMS uses it only when
##   the movement runs along that axis; the PERPENDICULAR diagonal falls back to the horizontal
##   clip. Using the diagonal clip for every diagonal was the "some diagonals inverted" bug.
## - `reverse` mirrors GMS `image_speed` sign: the clip plays backwards when image_speed < 0
##   (arcade legs follow MOVE_DIR while the torso holds FACING_DIR).
## The `rotate` and `run` clips are handled by the fighter directly, not here.

## Returns { anim: String, reverse: bool } for the current movement + facing.
## `facing` is ±1 (right/left); `depth` is Facing.FRONT (+1) / Facing.BACK (-1).
static func select(move_dir: Vector2, facing: float, depth: int) -> Dictionary:
	var suffix := "_front" if depth == Facing.FRONT else "_back"
	var sx := signf(move_dir.x)
	var sy := signf(move_dir.y)
	var iss := float(depth)            # GMS imageSpeedSign: FRONT=+1, BACK=-1
	if sx == 0.0 and sy == 0.0:
		return {"anim": "idle" + suffix, "reverse": false}
	if sx != 0.0 and sy != 0.0:
		# Diagonal movement. GMS condition decides whether the diagonal sprite's axis matches;
		# if not, it falls back to the horizontal clip (image_speed carries the vertical pass).
		var s_sign := -sy              # sign(sin(direction)): moving up = +1
		var c_sign := sx               # sign(cos(direction)): moving right = +1
		if signf(s_sign * facing) == signf(c_sign * iss):
			# diagonal clip; GMS image_speed = -vspeed/max * 1.2  ->  sign(-sy)
			return {"anim": "walk_diagonal" + suffix, "reverse": -sy < 0.0}
		# horizontal fallback; image_speed left over from the vertical pass = sy * iss
		return {"anim": "walk_horisontal" + suffix, "reverse": sy * iss < 0.0}
	if sy != 0.0:
		# pure vertical; GMS image_speed = vspeed/max * imageSpeedSign -> sign(sy * iss)
		return {"anim": "walk_vertical" + suffix, "reverse": sy * iss < 0.0}
	# pure horizontal; GMS image_speed = hspeed/max * facing -> sign(sx * facing)
	return {"anim": "walk_horisontal" + suffix, "reverse": sx * facing < 0.0}
