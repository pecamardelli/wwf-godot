class_name Proximity
## Arcade proximity test (JJXM macro, DNK.ASM): the opponent is "close" when
## |Δx| <= DX AND |Δz| <= DZ (X = horizontal, Z = depth = screen Y). Thresholds are
## per attack/opponent-mode in the action table; these constants are the common ones.

# Standing opponent (PUNCH NORMAL): DNK.ASM punch JJXM 50,45.
const CLOSE_DX := 50.0
const CLOSE_DZ := 45.0
# Grounded opponent (PUNCH/KICK ONGROUND): DNK.ASM 120,120.
const GROUNDED_DX := 120.0
const GROUNDED_DZ := 120.0

## True when `b` is within (dx, dz) of `a` on both axes (x = .x, z = .y), inclusive.
static func is_within(a: Vector2, b: Vector2, dx: float, dz: float) -> bool:
	return absf(b.x - a.x) <= dx and absf(b.y - a.y) <= dz
