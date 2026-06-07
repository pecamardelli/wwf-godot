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
