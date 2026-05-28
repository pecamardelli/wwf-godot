extends SceneTree
## Author Doink's MoveTable -> res://assets/movetables/doink.tres
## Run: godot --headless --path . -s tools/build_doink_movetable.gd

const OUT := "res://assets/movetables/doink.tres"
const SEQ := "res://assets/sequences/doink/"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/movetables"))
	var t := MoveTable.new()
	var punch: MoveSequence = load(SEQ + "punch.tres")
	var headbutt: MoveSequence = load(SEQ + "headbutt.tres")
	var kick: MoveSequence = load(SEQ + "kick.tres")
	var uppercut: MoveSequence = load(SEQ + "uppercut.tres")
	var big_boot: MoveSequence = load(SEQ + "big_boot.tres")
	# Low punch: far -> punch, close -> headbutt.
	t.add(MoveTable.Rng.NORMAL, MoveTable.Dir.NEUTRAL, MoveTable.Btn.LOW_PUNCH, punch)
	t.add(MoveTable.Rng.CLOSE,  MoveTable.Dir.NEUTRAL, MoveTable.Btn.LOW_PUNCH, headbutt)
	# High punch -> uppercut (both ranges).
	t.add(MoveTable.Rng.NORMAL, MoveTable.Dir.NEUTRAL, MoveTable.Btn.HIGH_PUNCH, uppercut)
	t.add(MoveTable.Rng.CLOSE,  MoveTable.Dir.NEUTRAL, MoveTable.Btn.HIGH_PUNCH, uppercut)
	# Low kick -> kick (both ranges).
	t.add(MoveTable.Rng.NORMAL, MoveTable.Dir.NEUTRAL, MoveTable.Btn.LOW_KICK, kick)
	t.add(MoveTable.Rng.CLOSE,  MoveTable.Dir.NEUTRAL, MoveTable.Btn.LOW_KICK, kick)
	# High kick -> big boot (all ranges; it is also the running attack).
	for r in [MoveTable.Rng.NORMAL, MoveTable.Rng.CLOSE, MoveTable.Rng.RUNNING]:
		t.add(r, MoveTable.Dir.NEUTRAL, MoveTable.Btn.HIGH_KICK, big_boot)
	var err := ResourceSaver.save(t, OUT)
	print("doink movetable -> ", error_string(err))
	if err != OK:
		quit(1)
	quit()
