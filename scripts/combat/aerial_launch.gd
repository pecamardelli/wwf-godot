class_name AerialLaunch
## Homing leap velocity (arcade LEAPATOPP, ANIM.EQU:156): the planar (X, depth) velocity that
## carries a fighter from `from` to `to` in `seconds`, clamped to per-axis caps. Vertical (Y) is
## launched separately at a fixed velocity; this is only the ground-plane component.

## `from`/`to` are world positions (x = screen X, y = screen depth). Returns (vx, vz) in px/s.
static func leap_velocity(from: Vector2, to: Vector2, seconds: float, cap_x: float, cap_z: float) -> Vector2:
	if seconds <= 0.0:
		return Vector2.ZERO
	var vx := clampf((to.x - from.x) / seconds, -cap_x, cap_x)
	var vz := clampf((to.y - from.y) / seconds, -cap_z, cap_z)
	return Vector2(vx, vz)

## Airtime (seconds) of a launch at `yvel` (px/s, up) under `gravity` (px/s^2): the time to rise
## and fall back to the launch height. The homing planar velocity is sized to THIS so the leap
## covers the distance to the target over the whole arc and lands on it — instead of being sized
## to an unrelated fixed window and sailing far past (the old overshoot bug). Returns 0 on bad input.
static func airtime_seconds(yvel: float, gravity: float) -> float:
	if yvel <= 0.0 or gravity <= 0.0:
		return 0.0
	return 2.0 * yvel / gravity
