extends "res://addons/gut/test.gd"
## The Sound autoload registers the default-on config flag, owns an Announcer child, and forwards
## announce() to it, recording the seam. The autoload self-mutes headless, so no real playback.

func before_each():
	Sound.last_announced = {}
	Sound.set_announcer_enabled(true)
	# Clear the gate so each test starts idle (else a prior test's cooldown could make the
	# disabled-noop test pass for the wrong reason — drop-by-cooldown instead of drop-by-disabled).
	Sound._announcer._cooldown_left = 0.0
	Sound._announcer._current_priority = -1

func after_all():
	Sound.set_announcer_enabled(true)

func test_config_flag_exists_and_defaults_true():
	assert_true(ProjectSettings.has_setting("wwfmania/audio/announcer_enabled"))
	assert_true(bool(ProjectSettings.get_setting("wwfmania/audio/announcer_enabled", true)))
	assert_true(Sound.is_announcer_enabled(), "announcer enabled by default")

func test_announce_records_seam():
	# Inject a tiny table so the category resolves (the real table is built in a later task).
	var e := SoundEntry.new(); e.bus = &"Announcer"; e.streams.append(AudioStreamWAV.new())
	var t := SoundTable.new(); t.default = {SoundCategory.ANNC_KO: e}
	Sound._announcer.table = t
	Sound._announcer._cooldown_left = 0.0
	Sound.announce(SoundCategory.ANNC_KO, 3)
	assert_eq(Sound.last_announced.get("category"), SoundCategory.ANNC_KO)
	assert_eq(Sound.last_announced.get("priority"), 3)

func test_disabled_announce_is_noop():
	var e := SoundEntry.new(); e.bus = &"Announcer"; e.streams.append(AudioStreamWAV.new())
	var t := SoundTable.new(); t.default = {SoundCategory.ANNC_KO: e}
	Sound._announcer.table = t
	Sound.set_announcer_enabled(false)
	Sound.last_announced = {}
	Sound.announce(SoundCategory.ANNC_KO, 3)
	assert_eq(Sound.last_announced, {}, "disabled -> no announcement")

func test_real_announcer_table_loaded_and_resolves():
	# Load the real table directly (a prior test swaps Sound._announcer.table for a synthetic one).
	assert_true(ResourceLoader.exists("res://assets/audio/announcer_table.tres"), "table built")
	var table: SoundTable = load("res://assets/audio/announcer_table.tres")
	assert_not_null(table, "announcer_table.tres loads")
	var ko: SoundEntry = table.resolve(&"", SoundCategory.ANNC_KO)
	assert_not_null(ko)
	assert_eq(ko.bus, &"Announcer")
	var imp: SoundEntry = table.resolve(&"", SoundCategory.ANNC_IMPRESSIVE)
	assert_gt(imp.streams.size(), 1, "impressive pool has variants")
