extends "res://addons/gut/test.gd"
## A landed hit fires an impact SFX at the victim; the victim grunts (PAIN). A knockdown adds a
## body-drop. We assert via the Sound autoload's test seams.

func _move(amode: int, grapple := false) -> MoveSequence:
	var m := MoveSequence.new()
	m.id = "t"
	m.attack_mode = amode
	m.is_grapple = grapple
	return m

func before_each():
	# The Sound autoload self-mutes under the headless test runner (no audio device); it still
	# resolves + records the seams we assert on below.
	Sound.last_sfx = {}
	Sound.last_voice = {}

func test_landed_hit_plays_impact_at_victim_position():
	var atk := Fighter.new(); add_child_autofree(atk)
	var vic := Fighter.new(); add_child_autofree(vic)
	atk.wrestler_id = &"doink"
	vic.global_position = Vector2(500, 420)
	vic.receive_hit(atk, _move(AMode.PUNCH))
	assert_eq(Sound.last_sfx.get("position"), Vector2(500, 420), "impact at the victim")
	assert_eq(Sound.last_sfx.get("bus"), &"SFX")

func test_landed_hit_makes_victim_grunt():
	var atk := Fighter.new(); add_child_autofree(atk)
	var vic := Fighter.new(); add_child_autofree(vic)
	atk.wrestler_id = &"doink"; vic.wrestler_id = &"doink"
	vic.receive_hit(atk, _move(AMode.PUNCH))
	assert_eq(Sound.last_voice.get("fighter"), vic, "victim voice channel grunted")

func test_blocked_hit_plays_no_impact_or_grunt():
	var atk := Fighter.new(); add_child_autofree(atk)
	var vic := Fighter.new(); add_child_autofree(vic)
	atk.wrestler_id = &"doink"; vic.wrestler_id = &"doink"
	vic.mode = Fighter.Mode.BLOCK
	vic.receive_hit(atk, _move(AMode.PUNCH))
	assert_eq(Sound.last_sfx, {}, "blocked -> no impact")
	assert_eq(Sound.last_voice, {}, "blocked -> no pain grunt")

func test_knockdown_throw_detach_plays_body_drop():
	var atk := Fighter.new(); add_child_autofree(atk)
	var vic := Fighter.new(); add_child_autofree(vic)
	atk.wrestler_id = &"doink"
	atk._grappling = vic
	vic._grappled_by = atk
	vic.global_position = Vector2(640, 500)
	atk._player.play(_move(AMode.HAMMER, true))   # any grapple move id
	atk._detach_victim()
	assert_eq(Sound.last_sfx.get("position"), Vector2(640, 500), "body-drop at the landing spot")

func _sfx_pool() -> SoundPool:
	var p := SoundPool.new(); p.streams = [AudioStreamWAV.new()]; p.weights = [1.0]
	p.chance_gated = false; p.bus = &"SFX"; return p

func test_knockdown_strike_uses_shared_hit_ground():
	# Not just throws: a regular knockdown (BIGBOOT) also drops the body to the floor, so it must
	# use the same shared hit_ground pool.
	var t := MoveSoundTable.new(); t.hit_ground = _sfx_pool()
	var prev = Sound.move_table
	Sound.move_table = t
	var atk := Fighter.new(); add_child_autofree(atk); atk.wrestler_id = &"doink"
	var vic := Fighter.new(); add_child_autofree(vic); vic.wrestler_id = &"doink"
	vic.global_position = Vector2(300, 410)
	vic.receive_hit(atk, _move(AMode.BIGBOOT))
	Sound.move_table = prev
	assert_eq(Sound.last_sfx.get("stream"), t.hit_ground.streams[0],
		"a knockdown strike's body-drop comes from the shared hit_ground pool")

func test_throw_detach_uses_shared_hit_ground_when_present():
	var t := MoveSoundTable.new(); t.hit_ground = _sfx_pool()
	var prev = Sound.move_table
	Sound.move_table = t
	var atk := Fighter.new(); add_child_autofree(atk); atk.wrestler_id = &"doink"
	var vic := Fighter.new(); add_child_autofree(vic); vic.global_position = Vector2(640, 500)
	atk._grappling = vic; vic._grappled_by = atk
	var mv := MoveSequence.new(); mv.id = "hip_toss"; mv.is_grapple = true
	atk._player.play(mv)
	atk._detach_victim()
	Sound.move_table = prev
	assert_eq(Sound.last_sfx.get("stream"), t.hit_ground.streams[0],
		"detach used the shared hit_ground pool, not the legacy body-drop")
