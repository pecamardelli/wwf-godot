extends Node
## Autoload `Sound`. Owns a polyphonic SFX player pool and one voice channel per fighter.
## Resolves categories through the SoundTable (arcade WRSND) and plays positionally
## (AudioStreamPlayer2D, so pan/attenuation follow screen position).

const TABLE_PATH := "res://assets/audio/doink_sound_table.tres"
const POOL_SIZE := 8

var table: SoundTable = null
var rng := RandomNumberGenerator.new()

var _sfx_pool: Array[AudioStreamPlayer2D] = []
var _next_sfx := 0
var _voice: Dictionary = {}   # fighter instance_id -> {player: AudioStreamPlayer2D, priority: int}

# --- Test seams: the last thing played (asserted in unit tests; ignored in the game). ---
var last_sfx: Dictionary = {}
var last_voice: Dictionary = {}

func _ready() -> void:
	if table == null and ResourceLoader.exists(TABLE_PATH):
		table = load(TABLE_PATH)
	for _i in range(POOL_SIZE):
		var p := AudioStreamPlayer2D.new()
		p.bus = &"SFX"
		add_child(p)
		_sfx_pool.append(p)

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
	var id := fighter.get_instance_id()
	var st: Dictionary = _voice.get(id, {})
	if st.is_empty():
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
	var p: AudioStreamPlayer2D = _sfx_pool[_next_sfx]
	_next_sfx = (_next_sfx + 1) % _sfx_pool.size()
	p.stream = s
	p.bus = entry.bus
	p.global_position = at_pos
	p.volume_db = entry.volume_db
	p.pitch_scale = 1.0 + rng.randf_range(-entry.pitch_jitter, entry.pitch_jitter)
	p.play()
	last_sfx = {"stream": s, "bus": entry.bus, "position": at_pos}
