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
