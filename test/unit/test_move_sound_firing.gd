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
	var vic := Fighter.new(); add_child_autofree(vic); vic.wrestler_id = &"doink"
	vic.global_position = Vector2(640, 500)
	Sound.play_move_hit(atk, vic, _move())
	assert_eq(Sound.last_sfx.get("position"), Vector2(640, 500), "hit SFX at the victim")
	assert_eq(Sound.last_voice.get("fighter"), vic, "pain on the victim's channel")

func test_hit_pain_keys_off_the_victim_not_the_attacker():
	# The pain pool is the VICTIM's grunt: defined for "doink", the victim is doink, the attacker
	# is someone else. Pain must still play (keyed by who's hurt, not who's hitting).
	var ms := MoveSounds.new()
	ms.swing = _sfx_pool(); ms.hit = _sfx_pool()
	ms.attack = {}; ms.pain = {&"doink": _voice_pool()}
	var t := MoveSoundTable.new(); t.moves = {"punch": ms}
	Sound.move_table = t
	var atk := Fighter.new(); add_child_autofree(atk); atk.wrestler_id = &"bret"
	var vic := Fighter.new(); add_child_autofree(vic); vic.wrestler_id = &"doink"
	Sound.play_move_hit(atk, vic, _move())
	assert_eq(Sound.last_voice.get("stream"), ms.pain[&"doink"].streams[0],
		"the doink victim grunts with its own pain even though the attacker is bret")

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

# --- hit_ground: a single SHARED body-drop pool on the table (not per-move) -----------------------

func _shared_hit_ground_table() -> MoveSoundTable:
	var t := MoveSoundTable.new(); t.hit_ground = _sfx_pool(); return t

func test_has_shared_hit_ground():
	var t := MoveSoundTable.new()   # no shared pool
	Sound.move_table = t
	assert_false(Sound.has_shared_hit_ground(), "no shared pool -> false")
	Sound.move_table = _shared_hit_ground_table()
	assert_true(Sound.has_shared_hit_ground(), "shared pool present -> true")

func test_empty_shared_hit_ground_pool_is_not_reported():
	var t := MoveSoundTable.new(); t.hit_ground = SoundPool.new()   # present but no variants
	Sound.move_table = t
	assert_false(Sound.has_shared_hit_ground(), "an empty pool must fall back to legacy")

func test_play_body_drop_uses_shared_hit_ground():
	var t := _shared_hit_ground_table()
	Sound.move_table = t
	var vic := Fighter.new(); add_child_autofree(vic); vic.wrestler_id = &"doink"
	vic.global_position = Vector2(640, 500)
	Sound.play_body_drop(vic)
	assert_eq(Sound.last_sfx.get("position"), Vector2(640, 500), "thud at the victim")
	assert_eq(Sound.last_sfx.get("bus"), &"SFX", "body-drop on the SFX bus")
	assert_eq(Sound.last_sfx.get("stream"), t.hit_ground.streams[0],
		"thud comes from the shared hit_ground pool")

func test_play_body_drop_falls_back_to_legacy_without_shared_pool():
	# No shared pool -> legacy SoundTable BODY_DROP at the victim.
	Sound.move_table = MoveSoundTable.new()
	var vic := Fighter.new(); add_child_autofree(vic); vic.wrestler_id = &"doink"
	vic.global_position = Vector2(120, 400)
	Sound.play_body_drop(vic)
	assert_eq(Sound.last_sfx.get("position"), Vector2(120, 400), "legacy body-drop at the victim")

# --- throw pain: per-move chance-gated pool, keyed by the attacker, played on the victim ----------

func _pain_table(pain_pool: SoundPool) -> MoveSoundTable:
	var ms := MoveSounds.new()
	ms.pain = {&"doink": pain_pool}
	var t := MoveSoundTable.new(); t.moves = {"hip_toss": ms}; return t

func test_play_throw_pain_uses_per_move_pain_pool():
	var t := _pain_table(_voice_pool())
	Sound.move_table = t
	var mv := MoveSequence.new(); mv.id = "hip_toss"
	var vic := Fighter.new(); add_child_autofree(vic); vic.wrestler_id = &"doink"
	Sound.play_throw_pain(vic, mv)
	assert_eq(Sound.last_voice.get("fighter"), vic, "victim grunts on its own voice channel")
	assert_eq(Sound.last_voice.get("stream"), t.moves["hip_toss"].pain[&"doink"].streams[0],
		"pain comes from the per-move pain pool")

func test_play_throw_pain_respects_chance_gate():
	# A summed-probability-0 pool must stay silent (the chance gate), proving probability is honored.
	Sound.move_table = _pain_table(_silent_voice_pool())
	var mv := MoveSequence.new(); mv.id = "hip_toss"
	var vic := Fighter.new(); add_child_autofree(vic); vic.wrestler_id = &"doink"
	Sound.play_throw_pain(vic, mv)
	assert_eq(Sound.last_voice, {}, "summed probability 0 -> the gate keeps the victim silent")

func test_play_throw_pain_keys_off_the_victim():
	# pain pool defined for "doink"; the victim is doink (the bret attacker is irrelevant to pain).
	Sound.move_table = _pain_table(_voice_pool())
	var mv := MoveSequence.new(); mv.id = "hip_toss"
	var vic := Fighter.new(); add_child_autofree(vic); vic.wrestler_id = &"doink"
	Sound.play_throw_pain(vic, mv)
	assert_eq(Sound.last_voice.get("stream"), Sound.move_table.resolve("hip_toss").pain[&"doink"].streams[0],
		"the victim's own pain pool drives the grunt")

func test_play_throw_pain_falls_back_to_legacy_when_unmapped():
	# A move with no per-move pain pool -> legacy always-on PAIN on the victim.
	var mv := MoveSequence.new(); mv.id = "knee"
	var vic := Fighter.new(); add_child_autofree(vic); vic.wrestler_id = &"doink"
	Sound.play_throw_pain(vic, mv)
	assert_eq(Sound.last_voice.get("fighter"), vic, "legacy pain on the victim's channel")
