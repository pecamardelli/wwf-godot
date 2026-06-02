extends SceneTree
## Build assets/audio/doink_sound_table.tres from the imported WAVs. Run headless:
##   godot --headless --path . --script res://tools/build_doink_sound_table.gd

const OUT := "res://assets/audio/doink_sound_table.tres"

func _load_all(dir: String, names: Array) -> Array[AudioStream]:
	var out: Array[AudioStream] = []
	for n in names:
		var path: String = dir + "/" + n
		assert(ResourceLoader.exists(path), "missing imported stream: " + path)
		out.append(load(path))
	return out

func _entry(streams: Array[AudioStream], bus: StringName, priority: int, jitter: float) -> SoundEntry:
	var e := SoundEntry.new()
	e.streams = streams
	e.bus = bus
	e.priority = priority
	e.pitch_jitter = jitter
	return e

func _init() -> void:
	var impacts := _load_all("res://assets/audio/sfx",
		["impact_01.wav","impact_02.wav","impact_03.wav","impact_04.wav","impact_05.wav","impact_06.wav"])
	var body := _load_all("res://assets/audio/sfx", ["body_drop_01.wav","body_drop_02.wav"])
	var pain := _load_all("res://assets/audio/voice/doink",
		["doink_pain_01.wav","doink_pain_02.wav","doink_pain_03.wav","doink_pain_04.wav","doink_pain_05.wav","doink_pain_06.wav"])
	var taunt := _load_all("res://assets/audio/voice/doink",
		["doink_taunt_01.wav","doink_taunt_02.wav","doink_taunt_03.wav"])

	var impact_entry := _entry(impacts, &"SFX", 0, 0.06)
	var body_entry := _entry(body, &"SFX", 0, 0.04)

	var t := SoundTable.new()
	# Default: every impact move category routes to the shared impact pool; body-drop is its own.
	var def := {}
	for cat in [AMode.PUNCH, AMode.HDBUTT, AMode.KICK, AMode.KNEE, AMode.UPRCUT, AMode.BIGBOOT,
			AMode.STOMP, AMode.LBDROP, AMode.SLAP, AMode.SPINKICK, AMode.EARSLAP, AMode.HAMMER, AMode.BOXGLOVE]:
		def[cat] = impact_entry
	def[SoundCategory.BODY_DROP] = body_entry
	t.default = def
	# Doink voice overrides.
	t.per_wrestler = {
		&"doink": {
			SoundCategory.PAIN: _entry(pain, &"Voice", 2, 0.05),
			SoundCategory.TAUNT: _entry(taunt, &"Voice", 1, 0.0),
		}
	}

	var err := ResourceSaver.save(t, OUT)
	print("build_doink_sound_table: saved %s (err=%d)" % [OUT, err])
	quit(0 if err == OK else 1)
