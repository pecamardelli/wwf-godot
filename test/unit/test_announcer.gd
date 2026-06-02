extends "res://addons/gut/test.gd"
## The Announcer resolves a category to a line, gates on enabled/cooldown/priority, and records
## the `last_announced` seam. We construct it directly (muted) — no real audio device needed.

func _entry(streams_n: int) -> SoundEntry:
	var e := SoundEntry.new()
	e.bus = &"Announcer"
	for _i in range(streams_n):
		e.streams.append(AudioStreamWAV.new())
	return e

func _table() -> SoundTable:
	var t := SoundTable.new()
	t.default = {
		SoundCategory.ANNC_IMPRESSIVE: _entry(3),
		SoundCategory.ANNC_KO: _entry(1),
	}
	return t

func _announcer() -> Announcer:
	var a := Announcer.new()
	a.muted = true                # record the seam, never touch the audio engine
	a.table = _table()
	add_child_autofree(a)         # runs _ready (builds the player), harmless while muted
	return a

func test_play_records_seam_when_enabled():
	var a := _announcer()
	assert_true(a.play(SoundCategory.ANNC_IMPRESSIVE, 2))
	assert_eq(a.last_announced.get("category"), SoundCategory.ANNC_IMPRESSIVE)
	assert_eq(a.last_announced.get("priority"), 2)
	assert_not_null(a.last_announced.get("stream"))

func test_disabled_is_noop():
	var a := _announcer()
	a.enabled = false
	a.last_announced = {}
	assert_false(a.play(SoundCategory.ANNC_KO, 3))
	assert_eq(a.last_announced, {}, "disabled -> nothing recorded")

func test_cooldown_blocks_second_equal_line():
	var a := _announcer()
	a.cooldown_seconds = 3.5
	assert_true(a.play(SoundCategory.ANNC_IMPRESSIVE, 2))
	a.last_announced = {}
	assert_false(a.play(SoundCategory.ANNC_IMPRESSIVE, 2), "still on cooldown -> drop")
	assert_eq(a.last_announced, {})

func test_cooldown_decrements_then_allows():
	var a := _announcer()
	a.cooldown_seconds = 3.5
	assert_true(a.play(SoundCategory.ANNC_KO, 3))
	a._process(4.0)               # advance past the cooldown
	assert_true(a.play(SoundCategory.ANNC_KO, 3), "off cooldown -> plays again")

func test_missing_category_returns_false():
	var a := _announcer()
	assert_false(a.play(SoundCategory.ANNC_NEAR_KO, 1), "no table entry -> nothing")
