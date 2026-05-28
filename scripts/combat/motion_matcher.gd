class_name MotionMatcher
extends RefCounted
## Faithful port of check_secret_moves (RESEARCH §A.3). Pure: no scene/Input access.

const _INPUT_MASK := 0xFFFF   # entries are 16-bit input fields

## True if `move`'s pattern is satisfied by `buffer` as of `current_tick`.
static func matches(move: MotionMove, buffer: MotionBuffer, current_tick: int) -> bool:
	var n := buffer.size()
	if n == 0 or move.step_count() == 0:
		return false
	# Freshness: a motion only fires the frame its trigger edge was pushed.
	if buffer.newest_tick() != current_tick:
		return false
	# The newest entry must BE the trigger: no extra bits (head-noise check) AND the
	# exact trigger value. Together these guarantee step 0 is the most-recent input and
	# nothing newer slipped in (e.g. a different button press cannot fire this move).
	var head := buffer.code_at(0)
	if (head & (~move.masks[0] & _INPUT_MASK)) != 0:
		return false
	if (head & move.masks[0]) != move.values[0]:
		return false
	# Match the remaining (older) steps newest->oldest. `skips <= SKIP_BUDGET` tolerates
	# exactly SKIP_BUDGET intervening entries before a step matches (8 skipped, 9th matches).
	var entry_i := 1
	var last_match_tick := buffer.tick_at(0)
	for step in range(1, move.step_count()):
		var matched := false
		var skips := 0
		while entry_i < n and skips <= MotionBuffer.SKIP_BUDGET:
			var code := buffer.code_at(entry_i)
			if (code & move.masks[step]) == move.values[step]:
				last_match_tick = buffer.tick_at(entry_i)
				entry_i += 1
				matched = true
				break
			entry_i += 1
			skips += 1
		if not matched:
			return false
	# Whole motion must lie within the window (arcade ticks -> logic frames).
	return (current_tick - last_match_tick) <= ArcadeUnits.ticks_to_frames(move.max_ticks)
