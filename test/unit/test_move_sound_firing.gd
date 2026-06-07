extends "res://addons/gut/test.gd"
## Sound.play_move_swing/hit pick from the move's pools and route swing/hit -> SFX, attack/pain ->
## the fighter's Voice channel. Asserted through the existing mute-time seams.

func _sfx_pool() -> SoundPool:
	var p := SoundPool.new(); p.streams = [AudioStreamWAV.new()]; p.weights = [1.0]
	p.chance_gated = false; p.bus = &"SFX"; return p

func _voice_pool() -> SoundPool:
	var p := SoundPool.new(); p.streams = [AudioStreamWAV.new()]; p.weights = [1.0]
	p.chance_gated = true; p.bus = &"Voice"; return p

func _silent_voice_pool() -> SoundPool:
	var p := SoundPool.new(); p.streams = [AudioStreamWAV.new()]; p.weights = [0.0]
	p.chance_gated = true; p.bus = &"Voice"; return p

func _table(attack_pool: SoundPool, pain_pool: SoundPool) -> MoveSoundTable:
	var ms := MoveSounds.new()
	ms.swing = _sfx_pool(); ms.hit = _sfx_pool()
	ms.attack = {&"doink": attack_pool}; ms.pain = {&"doink": pain_pool}
	var t := MoveSoundTable.new(); t.moves = {"punch": ms}; return t

func _move() -> MoveSequence:
	# Real sequence (id "punch") so Task 4's start_move/_play_sequence_anim exercise the true path
	# (real anim/frame data) rather than a frameless synthetic move.
	return load("res://assets/sequences/doink/punch.tres")

func before_each():
	Sound.last_sfx = {}; Sound.last_voice = {}
	Sound.move_table = _table(_voice_pool(), _voice_pool())

func after_all():
	Sound.move_table = null

func test_has_move_sounds():
	assert_true(Sound.has_move_sounds("punch"))
	assert_false(Sound.has_move_sounds("knee"))

func test_swing_plays_sfx_and_effort_voice():
	var atk := Fighter.new(); add_child_autofree(atk)
	atk.wrestler_id = &"doink"; atk.global_position = Vector2(300, 410)
	Sound.play_move_swing(atk, _move())
	assert_eq(Sound.last_sfx.get("position"), Vector2(300, 410), "swing SFX at the attacker")
	assert_eq(Sound.last_voice.get("fighter"), atk, "effort grunt on the attacker's channel")

func test_hit_plays_sfx_at_victim_and_pain_on_victim():
	var atk := Fighter.new(); add_child_autofree(atk); atk.wrestler_id = &"doink"
	var vic := Fighter.new(); add_child_autofree(vic); vic.global_position = Vector2(640, 500)
	Sound.play_move_hit(atk, vic, _move())
	assert_eq(Sound.last_sfx.get("position"), Vector2(640, 500), "hit SFX at the victim")
	assert_eq(Sound.last_voice.get("fighter"), vic, "pain on the victim's channel")

func test_silent_voice_pool_plays_no_voice():
	Sound.move_table = _table(_silent_voice_pool(), _silent_voice_pool())
	var atk := Fighter.new(); add_child_autofree(atk); atk.wrestler_id = &"doink"
	Sound.play_move_swing(atk, _move())
	assert_eq(Sound.last_voice, {}, "sum-0 effort pool -> no grunt")
	assert_ne(Sound.last_sfx, {}, "...but the swing SFX still plays")

func test_mapped_strike_swings_at_move_start():
	var atk := Fighter.new(); add_child_autofree(atk); atk.wrestler_id = &"doink"
	atk.start_move(_move())
	assert_ne(Sound.last_sfx, {}, "a mapped move plays a swing at start")

func test_mapped_hit_uses_new_path_not_legacy():
	# Legacy path plays via the SoundTable; the new path plays via move pools. With a move_table
	# entry present, the hit SFX must come from the pool (we assert it fired at the victim).
	var atk := Fighter.new(); add_child_autofree(atk); atk.wrestler_id = &"doink"
	var vic := Fighter.new(); add_child_autofree(vic); vic.global_position = Vector2(700, 480)
	vic.receive_hit(atk, _move())
	assert_eq(Sound.last_sfx.get("position"), Vector2(700, 480), "hit SFX at the victim via the pool")
	assert_eq(Sound.last_voice.get("fighter"), vic, "pain via the pool on the victim")

func test_unmapped_move_still_uses_legacy_path():
	var atk := Fighter.new(); add_child_autofree(atk); atk.wrestler_id = &"doink"
	var vic := Fighter.new(); add_child_autofree(vic); vic.global_position = Vector2(120, 400)
	var knee := MoveSequence.new(); knee.id = "knee"; knee.attack_mode = AMode.KNEE
	vic.receive_hit(atk, knee)
	# legacy play_impact still fires an SFX (the real doink table maps every AMode to an impact pool;
	# under the synthetic move_table this move is unmapped, so the legacy branch runs).
	assert_ne(Sound.last_sfx, {}, "unmapped move still makes an impact via the legacy path")
