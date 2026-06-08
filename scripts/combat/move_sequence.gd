class_name MoveSequence
extends Resource
## A move = an ordered list of SequenceFrames + the SpriteFrames anim to display + the
## attacker AMODE that selects the victim's reaction.

@export var id: String = ""
@export var anim_name: String = ""
## Depth-facing variant: played when the attacker faces BACK (away from the camera). Empty
## means use anim_name for both facings (moves with no back-facing art). The strike's frame
## TIMING comes from the sequence frames regardless of which clip displays.
@export var anim_name_back: String = ""
@export_enum("PUNCH", "HDBUTT", "KICK", "KNEE", "UPRCUT", "BIGBOOT", "STOMP", "LBDROP", "SLAP", "SPINKICK", "EARSLAP", "HAMMER", "BOXGLOVE") var attack_mode: int = AMode.PUNCH
@export var frames: Array[SequenceFrame] = []
## MODE_UNINT: while playing, new input is ignored until the sequence ends.
@export var uninterruptable: bool = true
## Some moves daze the victim (dizzy family) regardless of the base reaction.
@export var causes_dizzy: bool = false
## When this move's hit causes the dizzy reaction, ALSO apply the upward pop (hop). Separates a
## "dizzy stun" (burst intermediate, false) from a "dizzy + pop" (single headbutt / burst ender, true).
@export var victim_pop: bool = false
## Base damage to use instead of the attack_mode default (DamageTable.base) when > 0. Still runs
## through the offense scaling in Damage.resolve. Lets two same-amode moves differ in power.
@export var damage_override: int = 0
## Pin the victim in place for THIS hit — zero its reaction knockback so it doesn't drift. Used by
## the headbutt burst (arcade combo ZEROVELS/MODE_UNINT lock). Only this move's hits pin: a hit
## from another move/attacker still knocks the victim back normally.
@export var locks_victim: bool = false
## Grapple moves route their connect to attach (victim channel) rather than damage.
@export var is_grapple: bool = false
## A whiffed/blocked grab retracts the reach (plays the reach frames in reverse) instead of
## ending instantly. True only for the standing neck grab (arcade #missed/#missedb).
@export var reverse_reach_on_whiff: bool = false
## Arcade ticks to hold the reach frame after a grab connects, before the throw/puppet plays.
## Hip toss = 4 (arcade `WL 4,D3HT3Q+FR1`, DNKSEQ2.ASM:4248); neck grab = 1 (arcade
## `ANI_SUPERSLAVE2,1,D4GH3A+FR4` settle, DNKSEQ3.ASM) — the head hold has no long freeze.
@export var contact_freeze_ticks: int = 4

func total_ticks() -> int:
	var t := 0
	for f in frames:
		t += f.duration_ticks
	return t
