class_name AnnouncerPolicy
## Pure decision for the single announcer channel (arcade sp_anncer priority + a talk cadence).

## Play a new line when the channel is idle AND off cooldown, OR when it strictly outranks the
## line currently playing (a higher-priority event preempts mid-sentence, ignoring cooldown).
## Equal/lower priority while busy, or any line still on cooldown while idle, is dropped.
static func should_play(cooldown_remaining: float, busy: bool, current_priority: int, new_priority: int) -> bool:
	if busy:
		return new_priority > current_priority
	return cooldown_remaining <= 0.0
