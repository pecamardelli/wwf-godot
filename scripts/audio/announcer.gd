class_name Announcer
extends Node
## The play-by-play commentator: a single non-positional channel on the Announcer bus, highest
## priority (arcade sp_anncer). Resolves a category to a random line from the announcer table,
## gated by AnnouncerPolicy (cooldown + priority). Owned by the `Sound` autoload.

var table: SoundTable = null
var enabled := true
var muted := false                 # mirrors Sound.muted (no real playback under the headless test runner)
var cooldown_seconds := 3.5
var rng := RandomNumberGenerator.new()

var _player: AudioStreamPlayer = null
var _cooldown_left := 0.0
var _current_priority := -1

## Test seam: the last line that played/recorded ({category, priority, stream}).
var last_announced: Dictionary = {}

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = &"Announcer"
	add_child(_player)

func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)

## Try to play a commentary line for `category` at `priority`. Returns true if it played/recorded.
func play(category: int, priority: int) -> bool:
	if not enabled or table == null:
		return false
	var busy: bool = _player != null and _player.playing
	if not AnnouncerPolicy.should_play(_cooldown_left, busy, _current_priority, priority):
		return false
	var entry: SoundEntry = table.resolve(&"", category)
	var s: AudioStream = _pick(entry)
	if s == null:
		return false
	last_announced = {"category": category, "priority": priority, "stream": s}
	_cooldown_left = cooldown_seconds
	_current_priority = priority
	if muted:
		return true
	_player.stream = s
	_player.play()
	return true

## Random variant from an entry (mirrors Sound.pick_stream; the announcer owns its own rng so it
## stays unit-testable in isolation). Null-safe.
func _pick(entry: SoundEntry) -> AudioStream:
	if entry == null or entry.streams.is_empty():
		return null
	if entry.streams.size() == 1:
		return entry.streams[0]
	return entry.streams[rng.randi_range(0, entry.streams.size() - 1)]
