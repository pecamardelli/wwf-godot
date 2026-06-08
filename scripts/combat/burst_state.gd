class_name BurstState
## Pure mash-to-extend burst counter (Doink headbutt burst). No scene/engine deps so it is
## unit-testable in isolation. count 0 = idle. The owner calls start() on the first hit,
## note_continue() when the attack button is re-pressed during a hit, then at each hit's end
## uses can_chain()/advance() to continue or reset() to stop. Caps at MAX hits in a row.

const MAX := 4

var count: int = 0
var continue_pressed: bool = false

func is_active() -> bool:
	return count > 0

func start() -> void:
	count = 1
	continue_pressed = false

func note_continue() -> void:
	if count < MAX:
		continue_pressed = true

func can_chain() -> bool:
	return continue_pressed and count < MAX

func advance() -> void:
	count += 1
	continue_pressed = false

func reset() -> void:
	count = 0
	continue_pressed = false
