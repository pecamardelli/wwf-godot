extends SceneTree
## Build a SpriteFrames resource for Doink from the normalized PNG folders.
## Run with:
##   godot --headless --path . -s tools/build_doink_frames.gd
## (PNGs must be imported first: godot --headless --path . --import)

func _init() -> void:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	_add_anim(sf, "idle", "res://assets/sprites/doink/idle", 8.0, true)
	_add_anim(sf, "walk", "res://assets/sprites/doink/walk", 12.0, true)
	var path := "res://assets/sprites/doink/doink_frames.tres"
	var err := ResourceSaver.save(sf, path)
	print("saved ", path, " -> ", error_string(err))
	quit()

func _add_anim(sf: SpriteFrames, anim: String, dir_path: String, fps: float, loop: bool) -> void:
	sf.add_animation(anim)
	sf.set_animation_loop(anim, loop)
	sf.set_animation_speed(anim, fps)
	var d := DirAccess.open(dir_path)
	if d == null:
		push_error("cannot open " + dir_path)
		return
	var files: Array[String] = []
	for f in d.get_files():
		if f.to_lower().ends_with(".png"):
			files.append(f)
	files.sort()
	for f in files:
		var tex: Texture2D = load(dir_path + "/" + f)
		sf.add_frame(anim, tex)
	print(anim, ": ", files.size(), " frames")
