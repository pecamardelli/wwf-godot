class_name HairPickup
## Arcade hair-pickup gate (DNK.ASM:1709 #spunch_lbowdrop). On grounded SPUNCH, the default is
## elbow drop; hair pickup pre-empts it ONLY when the foe is downed AND the attacker stands at
## the foe's HEAD: far enough to be reaching (not on top), facing opposite the foe's lying-facing.

# |dx| must be >= this to hair-pickup. The asm `cmpi 20h,a1 / jrlt #no` sends CLOSER-than-0x20
# (32px) presses to the elbow drop, so hair pickup is the reaching case.
const HEAD_REACH_MIN := 32.0

## True iff a grounded-SPUNCH press should become a hair pickup rather than an elbow drop.
static func gate(attacker_x: float, attacker_facing: float, victim_x: float, victim_facing: float, victim_mode: int) -> bool:
	if victim_mode != Fighter.Mode.ONGROUND:
		return false
	if absf(attacker_x - victim_x) < HEAD_REACH_MIN:
		return false
	# Opposite FLIPH (arcade cmp a0,a14 / jrz #no on equal facing) = attacker at the head.
	return signf(attacker_facing) != signf(victim_facing)
