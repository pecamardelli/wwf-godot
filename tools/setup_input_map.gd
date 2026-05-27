extends SceneTree
## Setup: define the input actions and persist them to project.godot.
## Run with:
##   godot --headless --path . -s tools/setup_input_map.gd
## Authoritative for the listed actions — it OVERWRITES existing bindings so the
## key layout below is the single source of truth.

func _init() -> void:
	var bindings := {
		# Player 1 movement (WASD).
		"p1_up": KEY_W,
		"p1_down": KEY_S,
		"p1_left": KEY_A,
		"p1_right": KEY_D,
		# Player 1 attacks / actions (J K L / U I O cluster).
		"p1_punch": KEY_J,        # low punch
		"p1_high_punch": KEY_U,   # high punch
		"p1_kick": KEY_L,         # low kick
		"p1_high_kick": KEY_O,    # high kick
		"p1_block": KEY_K,        # block  (key bound; mechanic wired in 2c)
		"p1_run": KEY_I,          # run    (key bound; mechanic wired in 2c)
		# Player 2 movement (arrows). Solo for now — P1 holds the full scheme.
		"p2_up": KEY_UP,
		"p2_down": KEY_DOWN,
		"p2_left": KEY_LEFT,
		"p2_right": KEY_RIGHT,
	}
	for action in bindings:
		var ev := InputEventKey.new()
		ev.physical_keycode = bindings[action]
		ProjectSettings.set_setting("input/" + str(action), {"deadzone": 0.5, "events": [ev]})
		print("set action: ", action, " -> ", OS.get_keycode_string(bindings[action]))

	# Drop actions from the previous layout that no longer exist (solo P1 for now).
	for stale in ["p2_punch", "p2_kick"]:
		if ProjectSettings.has_setting("input/" + stale):
			ProjectSettings.clear("input/" + stale)
			print("removed stale action: ", stale)

	var err := ProjectSettings.save()
	print("ProjectSettings.save() -> ", error_string(err))
	quit()
