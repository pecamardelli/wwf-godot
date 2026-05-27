extends SceneTree
## Build doink_frames.tres: one animation per folder under assets/sprites/doink/.
## Run: godot --headless --path . -s tools/build_doink_frames.gd
## (PNGs must be imported first: godot --headless --path . --import)

const ROOT := "res://assets/sprites/doink"
# Animations that should loop (movement/idle); everything else plays once.
const LOOPING := ["idle_front", "idle_back", "walk_horisontal_front", "walk_horisontal_back",
	"walk_vertical_front", "walk_vertical_back", "walk_diagonal_front", "walk_diagonal_back", "run"]

func _init() -> void:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	var dirs := DirAccess.open(ROOT)
	if dirs == null:
		push_error("cannot open " + ROOT)
		quit(1)
		return
	var anim_names := dirs.get_directories()
	anim_names.sort()
	var count := 0
	for anim in anim_names:
		_add_anim(sf, anim)
		count += 1
	var err := ResourceSaver.save(sf, ROOT + "/doink_frames.tres")
	print("animations: ", count, "  save -> ", error_string(err))
	quit()

func _add_anim(sf: SpriteFrames, anim: String) -> void:
	sf.add_animation(anim)
	sf.set_animation_loop(anim, anim in LOOPING)
	sf.set_animation_speed(anim, 12.0)
	var d := DirAccess.open(ROOT + "/" + anim)
	if d == null:
		return
	var files: Array[String] = []
	for f in d.get_files():
		if f.to_lower().ends_with(".png"):
			files.append(f)
	files.sort()
	for f in files:
		var tex: Texture2D = load(ROOT + "/" + anim + "/" + f)
		sf.add_frame(anim, tex)
