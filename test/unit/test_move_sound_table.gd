extends "res://addons/gut/test.gd"
## MoveSoundTable maps a move id to its four buckets; unmapped ids resolve to null.

func _pool() -> SoundPool:
	var p := SoundPool.new(); p.streams = [AudioStreamWAV.new()]; p.weights = [1.0]; return p

func test_resolve_returns_mapped_move():
	var ms := MoveSounds.new()
	ms.swing = _pool(); ms.hit = _pool()
	ms.attack = {&"doink": _pool()}; ms.pain = {&"doink": _pool()}
	var t := MoveSoundTable.new(); t.moves = {"punch": ms}
	var got := t.resolve("punch")
	assert_not_null(got)
	assert_not_null(got.swing); assert_not_null(got.hit)
	assert_true(got.attack.has(&"doink")); assert_true(got.pain.has(&"doink"))

func test_resolve_unmapped_is_null():
	var t := MoveSoundTable.new(); t.moves = {}
	assert_null(t.resolve("knee"), "unmapped move -> null (legacy path)")
