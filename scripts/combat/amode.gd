class_name AMode
## Attack modes (arcade AMODE_*) and the reaction-family dispatch (arcade #hit_table,
## REACT1.ASM:833-901): the reaction is chosen by the ATTACKER's mode, not by damage.

## Subset of AMODE_* we implement in 2b (the wired strikes). Extend in later plans.
enum { PUNCH, HDBUTT, KICK, KNEE, UPRCUT, BIGBOOT, STOMP, LBDROP, SLAP, SPINKICK, EARSLAP, HAMMER, BOXGLOVE }

## Reaction families (arcade STDSEQ reaction tables, REACT1.ASM:1723-1866).
enum Family { HEAD_HIT, BODY_HIT, FALL_BACK, KNOCKDOWN, STAGGER, ONGROUND, BLOCK, DIZZY }

## AMODE -> reaction family.
const _HIT_TABLE := {
	PUNCH: Family.HEAD_HIT,
	HDBUTT: Family.HEAD_HIT,
	KICK: Family.BODY_HIT,
	KNEE: Family.BODY_HIT,
	UPRCUT: Family.FALL_BACK,
	BIGBOOT: Family.KNOCKDOWN,
	STOMP: Family.ONGROUND,
	LBDROP: Family.ONGROUND,
	# Seeded families for the new ground strikes (arcade reaction not yet extracted per-move; tune in playtest).
	SLAP: Family.HEAD_HIT,
	SPINKICK: Family.STAGGER,
	EARSLAP: Family.HEAD_HIT,
	HAMMER: Family.KNOCKDOWN,
	BOXGLOVE: Family.KNOCKDOWN,
}

static func reaction_for(amode: int) -> int:
	return _HIT_TABLE.get(amode, Family.BODY_HIT)

## Time the victim stays down before getup (set_getup_time, GETUP.ASM:32-184).
## Knockdowns = STAY_TIME 270 ticks; fall-back is shorter; everything else = 0 (get right up).
const _GETUP_TICKS := {
	Family.KNOCKDOWN: 270,
	Family.FALL_BACK: 90,
	Family.DIZZY: 120,
}

static func getup_ticks(family: int) -> int:
	return _GETUP_TICKS.get(family, 0)
