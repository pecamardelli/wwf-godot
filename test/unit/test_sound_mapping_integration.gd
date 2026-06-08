extends "res://addons/gut/test.gd"
## With the REAL generated move_sound_table loaded, a Doink punch swings at start and hits+pains on
## contact through the per-move pools (not the legacy category path).

func before_each():
	Sound.last_sfx = {}; Sound.last_voice = {}
	# Reload the REAL table: a prior test file (test_move_sound_firing) swaps in a synthetic table
	# and nulls it in after_all, so don't rely on the autoload's _ready load surviving.
	if ResourceLoader.exists("res://assets/audio/move_sound_table.tres"):
		Sound.move_table = load("res://assets/audio/move_sound_table.tres")

func test_real_table_has_punch_and_headbutt():
	assert_true(ResourceLoader.exists("res://assets/audio/move_sound_table.tres"), "table built")
	assert_true(Sound.has_move_sounds("punch"), "punch is mapped")
	assert_true(Sound.has_move_sounds("headbutt"), "headbutt is mapped")
	assert_false(Sound.has_move_sounds("knee"), "knee is not mapped")

func test_headbutt_burst_aliases_the_headbutt_sounds():
	# The burst hit shares the single headbutt's exact sound mapping (same MoveSounds instance).
	assert_true(Sound.has_move_sounds("headbutt_burst"), "headbutt_burst is mapped (alias)")
	assert_same(Sound.move_table.resolve("headbutt_burst"), Sound.move_table.resolve("headbutt"),
		"burst resolves to the SAME MoveSounds as the single headbutt")

func test_shared_hit_ground_pool_built():
	# hit_ground is a single shared pool on the table, not duplicated per move.
	assert_true(Sound.has_shared_hit_ground(), "shared body-drop pool is built")
	assert_eq(Sound.move_table.hit_ground.streams.size(), 5, "all five ring-impact variants resolved")
	# It is NOT nested under any move.
	assert_true(Sound.has_move_sounds("hip_toss"), "hip_toss is still mapped (attack/pain)")

func test_hip_toss_doink_pain_pool_matches_the_mapping():
	var ms: MoveSounds = Sound.move_table.resolve("hip_toss")
	assert_true(ms.pain.has(&"doink"), "Doink has a hip-toss pain pool")
	var pool: SoundPool = ms.pain[&"doink"]
	assert_true(pool.chance_gated, "pain is chance-gated (probability), not always-on precedence")
	# The built pool must mirror the mapping's variant count and summed probability (robust to tuning).
	var json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/sound_mapping.json"))
	var variants: Array = json["hip_toss"]["pain"]["doink"]
	var expected := 0.0
	for v in variants:
		expected += float(v["probability"])
	assert_eq(pool.streams.size(), variants.size(), "every mapped pain variant resolved")
	var total := 0.0
	for w in pool.weights:
		total += w
	assert_almost_eq(total, expected, 0.0001, "summed pain probability honors the mapping")
	assert_lt(total, 1.0, "a chance gate leaves room for silence (the victim isn't always vocal)")

func test_punch_swings_then_hits():
	var punch: MoveSequence = load("res://assets/sequences/doink/punch.tres")
	var atk := Fighter.new(); add_child_autofree(atk); atk.wrestler_id = &"doink"
	atk.global_position = Vector2(300, 410)
	atk.start_move(punch)
	assert_ne(Sound.last_sfx, {}, "swing whoosh at move start")
	Sound.last_sfx = {}
	var vic := Fighter.new(); add_child_autofree(vic); vic.global_position = Vector2(360, 410)
	vic.wrestler_id = &"doink"
	vic.receive_hit(atk, punch)
	assert_eq(Sound.last_sfx.get("position"), Vector2(360, 410), "impact at the victim")
