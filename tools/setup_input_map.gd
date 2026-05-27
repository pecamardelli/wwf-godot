extends SceneTree
## One-off setup: define the co-op input actions and persist them to project.godot.
## Run with:
##   godot --headless --path . -s tools/setup_input_map.gd
## Idempotent — re-running leaves existing actions untouched.

func _init() -> void:
	var bindings := {
		"p1_up": KEY_W,
		"p1_down": KEY_S,
		"p1_left": KEY_A,
		"p1_right": KEY_D,
		"p2_up": KEY_UP,
		"p2_down": KEY_DOWN,
		"p2_left": KEY_LEFT,
		"p2_right": KEY_RIGHT,
	}
	for action in bindings:
		var setting := "input/" + str(action)
		if ProjectSettings.has_setting(setting):
			continue
		var ev := InputEventKey.new()
		ev.physical_keycode = bindings[action]
		ProjectSettings.set_setting(setting, {"deadzone": 0.5, "events": [ev]})
		print("added action: ", action)
	var err := ProjectSettings.save()
	print("ProjectSettings.save() -> ", error_string(err))
	quit()
