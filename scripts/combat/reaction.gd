class_name Reaction
## Maps a reaction family + hit side to the victim's visible/behavioural response.
## Anim names are the imported Doink reaction folders (assets/sprites/doink/*).
## `side` is +1 (hit from front) or -1 (from back) per Hitbox.hit_side.

## Resolve to { anim:String, mode:int (Fighter.Mode), hitstun_ticks:int,
##              knockback:float, getup_ticks:int }. `dizzy` overrides to the DIZZY family.
static func resolve(family: int, side: int, dizzy: bool, pop: bool = false) -> Dictionary:
	if dizzy:
		family = AMode.Family.DIZZY
	var back := side < 0
	match family:
		AMode.Family.HEAD_HIT:
			return _r("facepunched_back" if back else "facepunched_front",
				Fighter.Mode.NORMAL, 12, 8.0, 0)
		AMode.Family.BODY_HIT:
			return _r("shoved", Fighter.Mode.NORMAL, 12, 10.0, 0)
		AMode.Family.STAGGER:
			return _r("shoved", Fighter.Mode.NORMAL, 18, 14.0, 0)
		AMode.Family.FALL_BACK:
			return _r("droped", Fighter.Mode.ONGROUND, 0, 24.0,
				AMode.getup_ticks(AMode.Family.FALL_BACK))
		AMode.Family.KNOCKDOWN:
			return _r("droped", Fighter.Mode.ONGROUND, 0, 30.0,
				AMode.getup_ticks(AMode.Family.KNOCKDOWN))
		AMode.Family.ONGROUND:
			return _r("damage_lying", Fighter.Mode.ONGROUND, 0, 4.0, 60)
		AMode.Family.BLOCK:
			return _r("defence", Fighter.Mode.BLOCK, 6, 2.0, 0)
		AMode.Family.DIZZY:
			# Headbutt: dizzy stun on `headbutted_salted`, recovery on clip-end (anim_timed; arcade
			# head_hit2 -> MODE_NORMAL), getup_ticks only a fallback if the clip can't be measured.
			# The upward pop (arcade REACT1.ASM:1171 OBJ_YVEL 0x3c000) is applied ONLY when `pop` is
			# set — burst intermediates stun without it; the single headbutt / burst ender pop.
			var hop := ArcadeUnits.HDBUTT_HOP_YVEL if pop else 0.0
			return _r("headbutted_salted", Fighter.Mode.DIZZY, 0, 6.0,
				AMode.getup_ticks(AMode.Family.DIZZY), hop, true)
		_:
			return _r("shoved", Fighter.Mode.NORMAL, 12, 10.0, 0)

static func _r(anim: String, mode: int, hitstun: int, knockback: float, getup: int,
		hop: float = 0.0, anim_timed: bool = false) -> Dictionary:
	return {
		"anim": anim, "mode": mode, "hitstun_ticks": hitstun,
		"knockback": knockback, "getup_ticks": getup,
		"hop": hop, "anim_timed": anim_timed,
	}

## Moves that drop the victim face-first (slam / roll) -> get_up_back_2. Everything else is
## a face-up knockdown (lands on the back) -> get_up_front. Arcade parallel: #getup_tbl
## defaults to *_faceup_getup_anim, with *_facedown_getup_anim for face-down falls
## (REACT1.ASM, ADMSEQ2.ASM #choose_dir). Seed list is forward-looking — add slam/roll
## finishers here as they get wired; verify against the art in playtest.
const _FACE_DOWN_ROLL_MOVES := {"flying_clothesline": true, "faceslam": true}

## `_family` is reserved (intentionally unused): orientation keys off the move id today, but
## the signature anticipates family-differentiated falls (the arcade has them).
static func fall_orientation(_family: int, move_id: String) -> int:
	if _FACE_DOWN_ROLL_MOVES.has(move_id):
		return Fighter.Fall.FACE_DOWN_ROLL
	return Fighter.Fall.FACE_UP
