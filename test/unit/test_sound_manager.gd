extends "res://addons/gut/test.gd"
## SoundManager resolves + plays. We assert via the test seam (`last_sfx` / `last_voice`) and
## the per-fighter voice node — no real audio device needed (headless uses the dummy driver).

## A fighter-like stub: Node2D + a wrestler_id (Fighter.wrestler_id is added later, in Task 8).
class _StubFighter extends Node2D:
	var wrestler_id: StringName = &"doink"

func _stream() -> AudioStream:
	return AudioStreamWAV.new()   # empty but valid stream object

func _entry(bus: StringName, pri: int, n: int) -> SoundEntry:
	var e := SoundEntry.new()
	e.bus = bus
	e.priority = pri
	for _i in range(n):
		e.streams.append(_stream())
	return e

func _mgr() -> Node:
	var m = load("res://scripts/audio/sound_manager.gd").new()
	add_child_autofree(m)
	return m

func test_pick_stream_is_deterministic_with_seed():
	var m = _mgr()
	var e := _entry(&"SFX", 0, 3)
	m.rng.seed = 42
	var a: AudioStream = m.pick_stream(e)
	m.rng.seed = 42
	var b: AudioStream = m.pick_stream(e)
	assert_eq(a, b, "same seed -> same variant")
	assert_true(e.streams.has(a))

func test_pick_stream_single_variant_and_empty():
	var m = _mgr()
	var one := _entry(&"SFX", 0, 1)
	assert_eq(m.pick_stream(one), one.streams[0])
	assert_null(m.pick_stream(_entry(&"SFX", 0, 0)))
	assert_null(m.pick_stream(null))

func test_play_impact_records_sfx_at_position():
	var m = _mgr()
	var t := SoundTable.new()
	t.default = {AMode.PUNCH: _entry(&"SFX", 0, 2)}
	m.table = t
	m.play_impact(&"doink", AMode.PUNCH, Vector2(300, 400))
	assert_eq(m.last_sfx.get("position"), Vector2(300, 400))
	assert_eq(m.last_sfx.get("bus"), &"SFX")
	assert_not_null(m.last_sfx.get("stream"))

func test_play_impact_missing_category_is_noop():
	var m = _mgr()
	m.table = SoundTable.new()   # empty
	m.last_sfx = {}
	m.play_impact(&"doink", AMode.KICK, Vector2.ZERO)
	assert_eq(m.last_sfx, {}, "no entry -> nothing played")

func test_voice_attaches_one_player_per_fighter_and_obeys_priority():
	var m = _mgr()
	var fighter := Node2D.new()
	add_child_autofree(fighter)
	var loud := _entry(&"Voice", 5, 1)
	var quiet := _entry(&"Voice", 1, 1)
	m.play_voice(fighter, loud)
	var n1 := fighter.get_child_count()
	assert_eq(m.last_voice.get("priority"), 5)
	# a lower-priority line while the loud one "plays" is dropped; channel reused (no 2nd node)
	m.play_voice(fighter, quiet)
	assert_eq(fighter.get_child_count(), n1, "reuses the one voice channel node")

func test_play_category_routes_voice_to_voice_channel():
	var m = _mgr()
	var t := SoundTable.new()
	t.per_wrestler = {&"doink": {SoundCategory.PAIN: _entry(&"Voice", 2, 1)}}
	m.table = t
	var fighter := _StubFighter.new()
	add_child_autofree(fighter)
	m.play_category(fighter, SoundCategory.PAIN)
	assert_eq(m.last_voice.get("priority"), 2)

func test_voice_channel_recreated_after_player_freed():
	# A freed voice player (fighter gone) must not leave a dangling cached ref — the channel
	# is recreated rather than touched while invalid.
	var m = _mgr()
	var fighter := Node2D.new()
	add_child_autofree(fighter)
	m.play_voice(fighter, _entry(&"Voice", 3, 1))
	var first: AudioStreamPlayer2D = m._voice[fighter.get_instance_id()]["player"]
	first.free()                       # simulate the player going away
	assert_false(is_instance_valid(first))
	m.play_voice(fighter, _entry(&"Voice", 3, 1))   # must not crash on the stale entry
	var second: AudioStreamPlayer2D = m._voice[fighter.get_instance_id()]["player"]
	assert_true(is_instance_valid(second), "a fresh voice channel was created")
	assert_ne(first, second)
