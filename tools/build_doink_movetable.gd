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
	var knee: MoveSequence = load(SEQ + "knee.tres")
	var stomp: MoveSequence = load(SEQ + "stomp.tres")
	var uppercut: MoveSequence = load(SEQ + "uppercut.tres")
	var slap: MoveSequence = load(SEQ + "slap.tres")
	var spin_kick: MoveSequence = load(SEQ + "spin_kick.tres")
	var elbow: MoveSequence = load(SEQ + "elbow_drop.tres")
	var big_boot: MoveSequence = load(SEQ + "big_boot.tres")
	var R := MoveTable.Rng
	var D := MoveTable.Dir
	var B := MoveTable.Btn

	# PUNCH (low punch): far punch, close head butt, grounded elbow drop. NOTE: no RUNNING entry
	# — the arcade running PUNCH is the flying clothesline (an aerial), deferred until the jump
	# system exists; until then running+punch is intentionally a no-op (the run just ends).
	t.add(R.NORMAL,   D.NEUTRAL, B.LOW_PUNCH, punch)
	t.add(R.CLOSE,    D.NEUTRAL, B.LOW_PUNCH, headbutt)
	t.add(R.GROUNDED, D.NEUTRAL, B.LOW_PUNCH, elbow)

	# KICK (low kick): far kick, close knee, grounded stomp, running big boot.
	t.add(R.NORMAL,   D.NEUTRAL, B.LOW_KICK, kick)
	t.add(R.CLOSE,    D.NEUTRAL, B.LOW_KICK, knee)
	t.add(R.GROUNDED, D.NEUTRAL, B.LOW_KICK, stomp)
	t.add(R.RUNNING,  D.NEUTRAL, B.LOW_KICK, big_boot)

	# SPUNCH (high punch): far/close slap, close+DOWN uppercut, grounded elbow drop, running big boot.
	t.add(R.NORMAL,   D.NEUTRAL, B.HIGH_PUNCH, slap)
	t.add(R.CLOSE,    D.NEUTRAL, B.HIGH_PUNCH, slap)
	t.add(R.CLOSE,    D.DOWN,    B.HIGH_PUNCH, uppercut)
	t.add(R.GROUNDED, D.NEUTRAL, B.HIGH_PUNCH, elbow)
	t.add(R.RUNNING,  D.NEUTRAL, B.HIGH_PUNCH, big_boot)

	# SKICK (high kick): far spin kick, close knee, grounded stomp, running big boot.
	t.add(R.NORMAL,   D.NEUTRAL, B.HIGH_KICK, spin_kick)
	t.add(R.CLOSE,    D.NEUTRAL, B.HIGH_KICK, knee)
	t.add(R.GROUNDED, D.NEUTRAL, B.HIGH_KICK, stomp)
	t.add(R.RUNNING,  D.NEUTRAL, B.HIGH_KICK, big_boot)

	var err := ResourceSaver.save(t, OUT)
	print("doink movetable -> ", error_string(err))
	if err != OK:
		quit(1)
	quit()
