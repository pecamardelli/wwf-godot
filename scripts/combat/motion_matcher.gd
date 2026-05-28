class_name MotionMatcher
extends RefCounted
## Faithful port of check_secret_moves (WRESTLE.ASM:4851, RESEARCH §A.3). Pure: no
## scene/Input access. `mask` = bits to IGNORE; an entry matches step k when
## (entry.code & ~mask[k]) == value[k] (arcade `andn`/`cmp`).

const _INPUT_MASK := 0xFFFF   # entries are 16-bit input fields

## True if `move`'s pattern is satisfied by `buffer` as of `current_tick`.
static func matches(move: MotionMove, buffer: MotionBuffer, current_tick: int) -> bool:
	var n := buffer.size()
	if n == 0 or move.step_count() == 0:
		return false
	# Freshness: a motion only fires the frame its trigger edge was pushed.
	if buffer.newest_tick() != current_tick:
		return false
	# Trigger/head check (WRESTLE.ASM:4894-4898): the newest entry must carry at least
	# one SIGNIFICANT bit for step 0, else there's noise since the trigger -> reject.
	var sig0 := (~move.masks[0]) & _INPUT_MASK
	if (buffer.code_at(0) & sig0) == 0:
		return false
	# Match steps newest->oldest from step 0 / entry 0. The skip budget is SHARED
	# across the whole move (arcade `movk 8,a3` set once) and only entries that mask
	# to ZERO (true noise) consume it; a significant entry that != value fails the move.
	var entry_i := 0
	var skips := 0
	var last_match_tick := current_tick
	for step in range(move.step_count()):
		var sig := (~move.masks[step]) & _INPUT_MASK
		var matched := false
		while entry_i < n and skips <= MotionBuffer.SKIP_BUDGET:
			var code := buffer.code_at(entry_i)
			if (code & sig) == 0:
				entry_i += 1
				skips += 1
				continue
			if (code & sig) == move.values[step]:
				last_match_tick = buffer.tick_at(entry_i)
				entry_i += 1
				matched = true
				break
			return false   # significant bits present but wrong -> whole move fails
		if not matched:
			return false
	# Whole motion must lie within the window (arcade ticks -> logic frames).
	return (current_tick - last_match_tick) <= ArcadeUnits.ticks_to_frames(move.max_ticks)
