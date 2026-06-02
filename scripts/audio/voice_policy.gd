class_name VoicePolicy
## Pure decision for a fighter's single voice channel (arcade per-channel priority).

## Should a new voice line take the channel? Yes if idle, or if it ranks at least as high as the
## currently-playing line (newest wins on a tie). A lower-priority line while busy is dropped.
static func should_interrupt(current_priority: int, new_priority: int, busy: bool) -> bool:
	if not busy:
		return true
	return new_priority >= current_priority
