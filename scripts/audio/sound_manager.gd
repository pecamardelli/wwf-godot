extends Node
## Autoload `Sound`. Owns a polyphonic SFX player pool and one voice channel per fighter.
## Resolves categories through the SoundTable (arcade WRSND) and plays positionally
## (AudioStreamPlayer2D, so pan/attenuation follow screen position).

const TABLE_PATH := "res://assets/audio/doink_sound_table.tres"
const POOL_SIZE := 8
const ANNOUNCER_TABLE_PATH := "res://assets/audio/announcer_table.tres"
const ANNOUNCER_SETTING := "wwfmania/audio/announcer_enabled"
const MOVE_TABLE_PATH := "res://assets/audio/move_sound_table.tres"

var table: SoundTable = null
var move_table: MoveSoundTable = null
var rng := RandomNumberGenerator.new()

var _sfx_pool: Array[AudioStreamPlayer2D] = []
var _next_sfx := 0
var _voice: Dictionary = {}   # fighter instance_id -> {player: AudioStreamPlayer2D, priority: int}

## Silences actual playback while still resolving + recording the test seams. Useful as a global
## mute, and set true by headless unit tests so the persistent autoload pool never starts real
## playbacks (which the engine would flag as leaked resources at exit).
var muted := false

# --- Test seams: the last thing played (asserted in unit tests; ignored in the game). ---
var last_sfx: Dictionary = {}
var last_voice: Dictionary = {}
var last_announced: Dictionary = {}
var _announcer: Announcer = null

func _ready() -> void:
	# The autoload instance (named "Sound") runs headless only under the test runner, where there
	# is no audio device — mute it so the persistent pool never starts playbacks the engine would
	# report as leaked at exit. Locally-constructed managers (other names, e.g. in unit tests) are
	# left audible so they can exercise real playback/channel creation.
	if name == &"Sound" and DisplayServer.get_name() == "headless":
		muted = true
	if table == null and ResourceLoader.exists(TABLE_PATH):
		table = load(TABLE_PATH)
	if move_table == null and ResourceLoader.exists(MOVE_TABLE_PATH):
		move_table = load(MOVE_TABLE_PATH)
	for _i in range(POOL_SIZE):
		var p := AudioStreamPlayer2D.new()
		p.bus = &"SFX"
		add_child(p)
		_sfx_pool.append(p)
	_register_announcer_setting()
	_announcer = Announcer.new()
	_announcer.name = "Announcer"
	_announcer.muted = muted
	_announcer.enabled = bool(ProjectSettings.get_setting(ANNOUNCER_SETTING, false))
	if ResourceLoader.exists(ANNOUNCER_TABLE_PATH):
		_announcer.table = load(ANNOUNCER_TABLE_PATH)
	add_child(_announcer)

## Ensure the config flag exists and is editor-visible (BOOL). Default OFF for now (commentary is
## disabled pending polish); flip to true to re-enable. No project-file save at runtime —
## get_setting's default covers a project that never persisted it.
func _register_announcer_setting() -> void:
	if not ProjectSettings.has_setting(ANNOUNCER_SETTING):
		ProjectSettings.set_setting(ANNOUNCER_SETTING, false)
	ProjectSettings.set_initial_value(ANNOUNCER_SETTING, false)
	ProjectSettings.add_property_info({"name": ANNOUNCER_SETTING, "type": TYPE_BOOL})

## Fire a play-by-play line (front door for Fighter). No-op if the announcer is absent/disabled.
func announce(category: int, priority: int) -> void:
	if _announcer == null:
		return
	if _announcer.play(category, priority):
		last_announced = _announcer.last_announced

func is_announcer_enabled() -> bool:
	return _announcer != null and _announcer.enabled

func set_announcer_enabled(value: bool) -> void:
	if _announcer != null:
		_announcer.enabled = value

## Pick a random variant from an entry (deterministic under a seeded rng). Null-safe.
func pick_stream(entry: SoundEntry) -> AudioStream:
	if entry == null or entry.streams.is_empty():
		return null
	if entry.streams.size() == 1:
		return entry.streams[0]
	return entry.streams[rng.randi_range(0, entry.streams.size() - 1)]

## On-hit impact: resolve the attacker's table slot for the move category, play at `at_pos`.
func play_impact(wrestler_id: StringName, category: int, at_pos: Vector2) -> void:
	if table == null:
		return
	_play_sfx(table.resolve(wrestler_id, category), at_pos)

## Resolve `category` for the fighter's wrestler and route by the entry's bus (Voice -> the
## fighter's voice channel; anything else -> the SFX pool at the fighter's position).
func play_category(fighter: Node, category: int) -> void:
	if table == null:
		return
	var wid: StringName = fighter.get("wrestler_id") if fighter.get("wrestler_id") != null else &""
	play_entry(table.resolve(wid, category), fighter)

func play_entry(entry: SoundEntry, fighter: Node) -> void:
	if entry == null:
		return
	if entry.bus == &"Voice":
		play_voice(fighter, entry)
	else:
		_play_sfx(entry, fighter.global_position)

func play_voice(fighter: Node, entry: SoundEntry) -> void:
	if entry == null:
		return
	if muted:
		# Record the seam without touching the audio engine (no channel node, no playback).
		last_voice = {"stream": pick_stream(entry), "fighter": fighter, "priority": entry.priority}
		return
	var id := fighter.get_instance_id()
	var st: Dictionary = _voice.get(id, {})
	# Recreate the channel if it's new OR if the cached player was freed with a prior fighter
	# (instance_ids can be reused over a long session); this also self-prunes stale entries.
	if st.is_empty() or not is_instance_valid(st.get("player")):
		var pl := AudioStreamPlayer2D.new()
		pl.bus = &"Voice"
		fighter.add_child(pl)
		st = {"player": pl, "priority": -1}
		_voice[id] = st
	var pl2: AudioStreamPlayer2D = st["player"]
	if not VoicePolicy.should_interrupt(st["priority"], entry.priority, pl2.playing):
		return
	var s := pick_stream(entry)
	if s == null:
		return
	pl2.stream = s
	pl2.volume_db = entry.volume_db
	pl2.pitch_scale = 1.0 + rng.randf_range(-entry.pitch_jitter, entry.pitch_jitter)
	pl2.play()
	st["priority"] = entry.priority
	last_voice = {"stream": s, "fighter": fighter, "priority": entry.priority}

func _play_sfx(entry: SoundEntry, at_pos: Vector2) -> void:
	var s := pick_stream(entry)
	if s == null:
		return
	last_sfx = {"stream": s, "bus": entry.bus, "position": at_pos}
	if muted:
		return
	var p: AudioStreamPlayer2D = _sfx_pool[_next_sfx]
	_next_sfx = (_next_sfx + 1) % _sfx_pool.size()
	p.stream = s
	p.bus = entry.bus
	p.global_position = at_pos
	p.volume_db = entry.volume_db
	p.pitch_scale = 1.0 + rng.randf_range(-entry.pitch_jitter, entry.pitch_jitter)
	p.play()

# --- Per-move sound mapping (swing/hit/attack/pain) — runs alongside the legacy SoundTable. ---

## True when a move has a per-move sound mapping (so Fighter uses the new path + suppresses legacy).
func has_move_sounds(move_id: String) -> bool:
	return move_table != null and move_table.resolve(move_id) != null

## Windup: the move's swing whoosh (SFX) + the attacker's effort grunt (Voice, may be silent).
func play_move_swing(attacker: Node, move: MoveSequence) -> void:
	var ms: MoveSounds = move_table.resolve(move.id) if move_table != null else null
	if ms == null:
		return
	if ms.swing != null:
		_play_pool_sfx(ms.swing, attacker.global_position)
	var wid: StringName = attacker.wrestler_id
	if ms.attack.has(wid):
		_play_pool_voice(attacker, ms.attack[wid])

## Contact: the move's impact (SFX at the victim) + the victim's pain (Voice, may be silent).
func play_move_hit(attacker: Node, victim: Node, move: MoveSequence) -> void:
	var ms: MoveSounds = move_table.resolve(move.id) if move_table != null else null
	if ms == null:
		return
	if ms.hit != null:
		_play_pool_sfx(ms.hit, victim.global_position)
	var wid: StringName = attacker.wrestler_id
	if ms.pain.has(wid):
		_play_pool_voice(victim, ms.pain[wid])

func _play_pool_sfx(pool: SoundPool, at_pos: Vector2) -> void:
	var s := pool.pick_stream(rng)
	if s == null:
		return
	last_sfx = {"stream": s, "bus": pool.bus, "position": at_pos}
	if muted:
		return
	var p: AudioStreamPlayer2D = _sfx_pool[_next_sfx]
	_next_sfx = (_next_sfx + 1) % _sfx_pool.size()
	p.stream = s
	p.bus = pool.bus
	p.global_position = at_pos
	p.volume_db = pool.volume_db
	p.pitch_scale = 1.0 + rng.randf_range(-pool.pitch_jitter, pool.pitch_jitter)
	p.play()

func _play_pool_voice(fighter: Node, pool: SoundPool) -> void:
	var s := pool.pick_stream(rng)
	if s == null:
		return   # silence (chance gate) — no voice this hit
	if muted:
		last_voice = {"stream": s, "fighter": fighter, "priority": pool.priority}
		return
	var id := fighter.get_instance_id()
	var st: Dictionary = _voice.get(id, {})
	if st.is_empty() or not is_instance_valid(st.get("player")):
		var pl := AudioStreamPlayer2D.new()
		pl.bus = &"Voice"
		fighter.add_child(pl)
		st = {"player": pl, "priority": -1}
		_voice[id] = st
	var pl2: AudioStreamPlayer2D = st["player"]
	if not VoicePolicy.should_interrupt(st["priority"], pool.priority, pl2.playing):
		return
	pl2.stream = s
	pl2.volume_db = pool.volume_db
	pl2.pitch_scale = 1.0 + rng.randf_range(-pool.pitch_jitter, pool.pitch_jitter)
	pl2.play()
	st["priority"] = pool.priority
	last_voice = {"stream": s, "fighter": fighter, "priority": pool.priority}
