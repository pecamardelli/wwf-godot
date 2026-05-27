class_name Reaction
## Maps a reaction family + hit side to the victim's visible/behavioural response.
## Anim names are the imported Doink reaction folders (assets/sprites/doink/*).
## `side` is +1 (hit from front) or -1 (from back) per Hitbox.hit_side.

## Resolve to { anim:String, mode:int (Fighter.Mode), hitstun_ticks:int,
##              knockback:float, getup_ticks:int }. `dizzy` overrides to the DIZZY family.
static func resolve(family: int, side: int, dizzy: bool) -> Dictionary:
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
			return _r("stuned", Fighter.Mode.DIZZY, 0, 6.0,
				AMode.getup_ticks(AMode.Family.DIZZY))
		_:
			return _r("shoved", Fighter.Mode.NORMAL, 12, 10.0, 0)

static func _r(anim: String, mode: int, hitstun: int, knockback: float, getup: int) -> Dictionary:
	return {
		"anim": anim, "mode": mode, "hitstun_ticks": hitstun,
		"knockback": knockback, "getup_ticks": getup,
	}
