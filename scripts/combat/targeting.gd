class_name Targeting
## Biased nearest-opponent selection (arcade calc_closest, WRESTLE.ASM:4127-4210).
## Lower score = more likely chosen. A live candidate always beats a dead one.

const DOWNED_PENALTY := 2.0   # ONGROUND opponents score ×2 (deprioritized)
const LAST_HIT_BONUS := 0.75  # the fighter you last hit scores ×0.75 (stickiness)

## Biased distance for one candidate. Distance is the X/Z plane (Y height is 0 now),
## so the 2D position distance equals the 3D distance with dy=0.
static func score(from: Fighter, cand: Fighter) -> float:
	var s := from.global_position.distance_to(cand.global_position)
	if cand.mode == Fighter.Mode.ONGROUND:
		s *= DOWNED_PENALTY
	if from._who_i_hit == cand:
		s *= LAST_HIT_BONUS
	return s

## Pick the best opposite-side target from `candidates`, or null.
static func pick(from: Fighter, candidates: Array) -> Fighter:
	var best: Fighter = null
	var best_score := INF
	var best_alive := false
	for c in candidates:
		if c == from or c.side == from.side:
			continue
		var alive: bool = not c.is_dead()
		var sc := score(from, c)
		# Prefer alive over dead; among equal aliveness, prefer the lower score.
		if best == null or (alive and not best_alive) or (alive == best_alive and sc < best_score):
			best = c
			best_score = sc
			best_alive = alive
	return best
