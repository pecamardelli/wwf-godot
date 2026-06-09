class_name FlyingKick
## Arcade flying-kick gate (DNK.ASM:1848 #super_kick). HIGH_KICK against a STANDING foe that sits
## OUTSIDE the 60x60 "close" box becomes the homing jump kick; a foe inside the box gets the close
## super move (out of scope here), and a downed foe gets the stomp branch. `range_max` in the arcade
## is 999 (effectively unbounded above), so there is only a LOWER bound.

const LEAP_MIN_DX := 60.0   # arcade #super_kick close-box DX
const LEAP_MIN_DZ := 60.0   # arcade #super_kick close-box DZ

## True iff a HIGH_KICK press against a STANDING foe should leap. The arcade dnk_2_spin_kick ALWAYS
## LEAPATOPPs — close is the short "close super" hop, far is the full flying kick; there is no grounded
## spin kick. So any standing foe leaps; only a downed foe (stomp branch) stays grounded. positions are
## kept in the signature for a future close-vs-far variant split (arcade #super_kick 60x60 box).
static func gate(_attacker_pos: Vector2, _target_pos: Vector2, target_mode: int) -> bool:
	return target_mode != Fighter.Mode.ONGROUND
