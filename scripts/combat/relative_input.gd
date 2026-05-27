class_name RelativeInput
## Map raw 8-way input to directions relative to facing (arcade J_TOWARD/J_AWAY).
## `toward` = horizontal input pointing the same way the fighter faces (at the target).

static func resolve(raw: Vector2, facing: float) -> Dictionary:
	var ix := signf(raw.x)
	var fx := signf(facing)
	return {
		"toward": ix != 0.0 and ix == fx,
		"away": ix != 0.0 and ix == -fx,
		"up": raw.y < 0.0,
		"down": raw.y > 0.0,
	}
