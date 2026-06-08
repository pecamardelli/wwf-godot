class_name VoicePolicy
## Pure decision for a fighter's single voice channel (arcade per-channel priority).

## Should a new voice line take the channel? ALWAYS yes — the newest voice cancels whatever the
## fighter is currently saying (a rapid combo's pain grunts retrigger every hit, never queue or
## drop). Args kept for call-site compatibility; the decision no longer gates on priority.
static func should_interrupt(_current_priority: int, _new_priority: int, _busy: bool) -> bool:
	return true
