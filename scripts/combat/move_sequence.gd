class_name MoveSequence
extends Resource
## A move = an ordered list of SequenceFrames + the SpriteFrames anim to display + the
## attacker AMODE that selects the victim's reaction.

@export var id: String = ""
@export var anim_name: String = ""
@export_enum("PUNCH", "HDBUTT", "KICK", "KNEE", "UPRCUT", "BIGBOOT", "STOMP", "LBDROP") var attack_mode: int = AMode.PUNCH
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

func total_ticks() -> int:
	var t := 0
	for f in frames:
		t += f.duration_ticks
	return t
