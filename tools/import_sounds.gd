extends SceneTree
## One-shot asset import: copy + rename the WAVs this slice needs from the external WWF Sources
## rip into res://assets/audio. Run headless:
##   godot --headless --path . --script res://tools/import_sounds.gd
## then re-import so Godot generates the .import files:
##   godot --headless --path . --import

const SRC := "/media/pablin/DATOS/JUEGOS/Wrestlemania/WWF Sources/Sounds"

# dest_dir -> { dest_filename : source_relative_path }
const MANIFEST := {
	"res://assets/audio/sfx": {
		"impact_01.wav": "Punches_impacts_etc/Punches_impacts_etc/Impact.wav",
		"impact_02.wav": "Punches_impacts_etc/Punches_impacts_etc/Impact 2.wav",
		"impact_03.wav": "Punches_impacts_etc/Punches_impacts_etc/Impact 3.wav",
		"impact_04.wav": "Punches_impacts_etc/Punches_impacts_etc/Impact 4.wav",
		"impact_05.wav": "Punches_impacts_etc/Punches_impacts_etc/Impact 5.wav",
		"impact_06.wav": "Punches_impacts_etc/Punches_impacts_etc/Impact 6.wav",
		"body_drop_01.wav": "Punches_impacts_etc/Punches_impacts_etc/Ring body drop.wav",
		"body_drop_02.wav": "Punches_impacts_etc/Punches_impacts_etc/Ring body drop 2.wav",
	},
	"res://assets/audio/voice/doink": {
		"doink_pain_01.wav": "Doink_sound/Doink/Doink pain.wav",
		"doink_pain_02.wav": "Doink_sound/Doink/Doink pain 2.wav",
		"doink_pain_03.wav": "Doink_sound/Doink/Doink pain 3.wav",
		"doink_pain_04.wav": "Doink_sound/Doink/Doink pain 4.wav",
		"doink_pain_05.wav": "Doink_sound/Doink/Doink pain 5.wav",
		"doink_pain_06.wav": "Doink_sound/Doink/Doink pain 6.wav",
		"doink_taunt_01.wav": "Doink_sound/Doink/Doink laugh.wav",
		"doink_taunt_02.wav": "Doink_sound/Doink/Doink laugh 2.wav",
		"doink_taunt_03.wav": "Doink_sound/Doink/Doink laugh 3.wav",
		"doink_buzzer.wav": "Doink_sound/Doink/Doink You made a good choise.wav",
		"doink_hammer.wav": "Doink_sound/Doink/Doink Hammer blow.wav",
	},
}

func _init() -> void:
	var copied := 0
	var missing: Array[String] = []
	for dest_dir in MANIFEST:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest_dir))
		var files: Dictionary = MANIFEST[dest_dir]
		for dest_name in files:
			var src_abs: String = SRC + "/" + files[dest_name]
			var dst_abs: String = ProjectSettings.globalize_path(dest_dir + "/" + dest_name)
			if not FileAccess.file_exists(src_abs):
				missing.append(src_abs)
				continue
			var err := DirAccess.copy_absolute(src_abs, dst_abs)
			if err == OK:
				copied += 1
			else:
				push_error("copy failed (%d): %s" % [err, src_abs])
	print("import_sounds: copied %d file(s)" % copied)
	if not missing.is_empty():
		push_error("import_sounds: MISSING %d source file(s):\n%s" % [missing.size(), "\n".join(missing)])
	quit(1 if not missing.is_empty() else 0)
