class_name DamageTable
## Base strike damage per AMODE (DAMAGE.EQU). Repeat damage RD_* = floor(D_* * 2/3),
## used when the victim was damaged within the last 50 ticks (REACT1.ASM:457-466).

const _BASE := {
	AMode.PUNCH: 8,
	AMode.HDBUTT: 12,
	AMode.KICK: 13,
	AMode.KNEE: 12,
	AMode.UPRCUT: 20,
	AMode.BIGBOOT: 18,
	AMode.STOMP: 8,
	AMode.LBDROP: 17,
	# Seeded values — arcade DAMAGE.EQU not yet extracted for these moves; tune in playtest.
	AMode.SLAP: 10,
	AMode.SPINKICK: 18,
	AMode.EARSLAP: 10,
	AMode.HAMMER: 22,
	AMode.BOXGLOVE: 25,
}

static func base(amode: int) -> int:
	return int(_BASE.get(amode, 0))

static func repeat(amode: int) -> int:
	return (base(amode) * 2) / 3   # integer floor
