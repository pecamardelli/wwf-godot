extends "res://addons/gut/test.gd"
## SoundTable.resolve mirrors arcade WRSND: try the wrestler's override slot, else the default
## slot, else null.

func _entry(tag: StringName) -> SoundEntry:
	var e := SoundEntry.new()
	e.bus = tag   # abuse `bus` as an identity tag for the test
	return e

func _table() -> SoundTable:
	var t := SoundTable.new()
	var def_punch := _entry(&"def_punch")
	var def_body := _entry(&"def_body")
	t.default = {AMode.PUNCH: def_punch, SoundCategory.BODY_DROP: def_body}
	var doink_punch := _entry(&"doink_punch")
	var doink_pain := _entry(&"doink_pain")
	t.per_wrestler = {&"doink": {AMode.PUNCH: doink_punch, SoundCategory.PAIN: doink_pain}}
	return t

func test_wrestler_override_wins():
	var t := _table()
	assert_eq(t.resolve(&"doink", AMode.PUNCH).bus, &"doink_punch")

func test_falls_back_to_default_when_wrestler_has_no_slot():
	var t := _table()
	# doink has no BODY_DROP override -> default
	assert_eq(t.resolve(&"doink", SoundCategory.BODY_DROP).bus, &"def_body")

func test_unknown_wrestler_uses_default():
	var t := _table()
	assert_eq(t.resolve(&"bret", AMode.PUNCH).bus, &"def_punch")

func test_missing_category_returns_null():
	var t := _table()
	assert_null(t.resolve(&"doink", AMode.KICK))   # no override, no default for KICK
	assert_null(t.resolve(&"bret", SoundCategory.PAIN))
