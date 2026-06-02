extends SceneTree
## One-shot asset import: copy + rename the announcer WAVs this slice needs into
## res://assets/audio/announcer. Run headless:
##   godot --headless --path . --script res://tools/import_announcer_sounds.gd
##   godot --headless --path . --import

const SRC := "/media/pablin/DATOS/JUEGOS/Wrestlemania/WWF Sources/Sounds/Comment_sound/Comment"
const DEST := "res://assets/audio/announcer"

# dest_filename : source_filename (under SRC)
const MANIFEST := {
	"impressive_01.wav": "Comment Awersome.wav",
	"impressive_02.wav": "Comment Awersome 2.wav",
	"impressive_03.wav": "Comment Boom shakalaka.wav",
	"impressive_04.wav": "Comment Did you see that.wav",
	"impressive_05.wav": "Comment Did you see that 2.wav",
	"impressive_06.wav": "Comment Unbelievable.wav",
	"impressive_07.wav": "Comment Unbelievable 2.wav",
	"impressive_08.wav": "Comment Wow.wav",
	"impressive_09.wav": "Comment Wow 2.wav",
	"impressive_10.wav": "Comment Most impressive.wav",
	"impressive_11.wav": "Comment Ka-boom.wav",
	"impressive_12.wav": "Comment Look at this.wav",
	"impressive_13.wav": "Comment I can't believe.wav",
	"impressive_14.wav": "Comment Nice execution.wav",
	"ko_01.wav": "Comment And stay down.wav",
	"ko_02.wav": "Comment Game over.wav",
	"ko_03.wav": "Comment We have a winner.wav",
	"ko_04.wav": "Comment And all.wav",
	"near_ko_01.wav": "Comment Can he get up in time.wav",
	"near_ko_02.wav": "Comment Get up!.wav",
	"near_ko_03.wav": "Comment Doink It don't look good.wav",
}

func _init() -> void:
	var copied := 0
	var missing: Array[String] = []
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST))
	for dest_name in MANIFEST:
		var src_abs: String = SRC + "/" + MANIFEST[dest_name]
		var dst_abs: String = ProjectSettings.globalize_path(DEST + "/" + dest_name)
		if not FileAccess.file_exists(src_abs):
			missing.append(src_abs)
			continue
		var err := DirAccess.copy_absolute(src_abs, dst_abs)
		if err == OK:
			copied += 1
		else:
			push_error("copy failed (%d): %s" % [err, src_abs])
	print("import_announcer_sounds: copied %d file(s)" % copied)
	if not missing.is_empty():
		push_error("import_announcer_sounds: MISSING %d:\n%s" % [missing.size(), "\n".join(missing)])
	quit(1 if not missing.is_empty() else 0)
