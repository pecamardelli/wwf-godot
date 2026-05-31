class_name MoveSequence
extends Resource
## A move = an ordered list of SequenceFrames + the SpriteFrames anim to display + the
## attacker AMODE that selects the victim's reaction.

@export var id: String = ""
@export var anim_name: String = ""
@export_enum("PUNCH", "HDBUTT", "KICK", "KNEE", "UPRCUT", "BIGBOOT", "STOMP", "LBDROP", "SLAP", "SPINKICK", "EARSLAP", "HAMMER", "BOXGLOVE") var attack_mode: int = AMode.PUNCH
@export var frames: Array[SequenceFrame] = []
## MODE_UNINT: while playing, new input is ignored until the sequence ends.
@export var uninterruptable: bool = true
## Some moves daze the victim (dizzy family) regardless of the base reaction.
@export var causes_dizzy: bool = false
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
