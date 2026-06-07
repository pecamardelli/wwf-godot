extends CheckBox
## Sandbox dev toggle: enables/disables AI on every Enemy fighter. Unchecked (default) = enemies
## stand still; checked = they fight. Drives Enemy.ai_enabled live, so flipping it mid-session
## starts or stops the brawl.

func _ready() -> void:
	button_pressed = false                      # default unchecked = AI off (enemies idle)
	toggled.connect(_on_toggled)
	# Push the initial state AFTER the scene is fully built (enemies join the "fighters" group in
	# their own _ready), so the sandbox reliably starts with the enemies standing still.
	call_deferred("_apply", button_pressed)

func _on_toggled(on: bool) -> void:
	_apply(on)

func _apply(on: bool) -> void:
	for f in get_tree().get_nodes_in_group("fighters"):
		if f is Enemy:
			f.ai_enabled = on
