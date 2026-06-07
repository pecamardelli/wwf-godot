class_name FlyingKick
## Arcade flying-kick gate (DNK.ASM:1848 #super_kick). HIGH_KICK against a STANDING foe that sits
## OUTSIDE the 60x60 "close" box becomes the homing jump kick; a foe inside the box gets the close
## super move (out of scope here), and a downed foe gets the stomp branch. `range_max` in the arcade
## is 999 (effectively unbounded above), so there is only a LOWER bound.

const LEAP_MIN_DX := 60.0   # arcade #super_kick close-box DX
const LEAP_MIN_DZ := 60.0   # arcade #super_kick close-box DZ

## True iff a NORMAL-range HIGH_KICK press should become a flying kick rather than the standing kick.
static func gate(attacker_pos: Vector2, target_pos: Vector2, target_mode: int) -> bool:
	if target_mode == Fighter.Mode.ONGROUND:
		return false
	# Within the 60x60 box -> close super (skip). Outside (either axis beyond) -> flying kick.
	return not Proximity.is_within(attacker_pos, target_pos, LEAP_MIN_DX, LEAP_MIN_DZ)
