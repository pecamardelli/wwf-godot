extends SceneTree
## Build assets/audio/announcer_table.tres from the imported announcer WAVs. Run headless:
##   godot --headless --path . --script res://tools/build_announcer_table.gd

const OUT := "res://assets/audio/announcer_table.tres"
const DIR := "res://assets/audio/announcer"

func _load_all(names: Array) -> Array[AudioStream]:
	var out: Array[AudioStream] = []
	for n in names:
		var path: String = DIR + "/" + n
		assert(ResourceLoader.exists(path), "missing imported stream: " + path)
		out.append(load(path))
	return out

func _entry(streams: Array[AudioStream], priority: int) -> SoundEntry:
	var e := SoundEntry.new()
	e.streams = streams
	e.bus = &"Announcer"
	e.priority = priority
	e.pitch_jitter = 0.0   # speech: no pitch variation
	return e

func _init() -> void:
	var impressive := _load_all([
		"impressive_01.wav","impressive_02.wav","impressive_03.wav","impressive_04.wav",
		"impressive_05.wav","impressive_06.wav","impressive_07.wav","impressive_08.wav",
		"impressive_09.wav","impressive_10.wav","impressive_11.wav","impressive_12.wav",
		"impressive_13.wav","impressive_14.wav"])
	var ko := _load_all(["ko_01.wav","ko_02.wav","ko_03.wav","ko_04.wav"])
	var near_ko := _load_all(["near_ko_01.wav","near_ko_02.wav","near_ko_03.wav"])

	var t := SoundTable.new()
	t.default = {
		SoundCategory.ANNC_IMPRESSIVE: _entry(impressive, 2),
		SoundCategory.ANNC_KO: _entry(ko, 3),
		SoundCategory.ANNC_NEAR_KO: _entry(near_ko, 1),
	}
	var err := ResourceSaver.save(t, OUT)
	print("build_announcer_table: saved %s (err=%d)" % [OUT, err])
	quit(0 if err == OK else 1)
