extends "res://addons/gut/test.gd"

func test_fighter_exposes_current_range_for_subclasses():
	var f := Fighter.new(); add_child_autofree(f)
	f.global_position = Vector2(100, 400); f.separation_radii = Vector2.ZERO
	var e := Fighter.new(); add_child_autofree(e)
	e.global_position = Vector2(300, 400); e.separation_radii = Vector2.ZERO
	e.mode = Fighter.Mode.NORMAL
	f.target = e
	assert_eq(f._current_range(), MoveTable.Rng.NORMAL)

func _basic_profile() -> AIProfile:
	var p := AIProfile.new()
	p.skill = 6
	p.reaction_delay = Vector2i(8, 8)
	p.enabled_stances = [AIController.Stance.PRESSING]
	p.stance_weights = {AIController.Stance.PRESSING: 1.0}
	p.preferred_range = AIProfile.PreferredRange.CLOSE
	return p

func _enemy() -> Enemy:
	var e := Enemy.new(); add_child_autofree(e)
	e.separation_radii = Vector2.ZERO
	e.profile = _basic_profile()
	e.side = Fighter.Side.ENEMY
	return e

func test_enemy_feeds_intent_into_movement_hook():
	var e := _enemy()
	e._intent.move_dir = Vector2(1, 0)
	assert_eq(e.get_input_direction(), Vector2(1, 0))

func test_enemy_block_intent_drives_guarding():
	var e := _enemy()
	e._intent.action = AIIntent.Action.BLOCK
	assert_true(e.wants_to_block())

func test_enemy_walks_toward_distant_player():
	var e := _enemy(); e.global_position = Vector2(100, 400)
	var p := Player.new(); add_child_autofree(p)
	p.global_position = Vector2(500, 400); p.separation_radii = Vector2.ZERO
	p.side = Fighter.Side.PLAYER
	e.target = p
	var x0 := e.global_position.x
	for _n in range(30):
		e._physics_process(1.0 / 60.0)
	assert_gt(e.global_position.x, x0, "enemy closed distance toward the player")

func test_enemy_strikes_player_in_range():
	var e := _enemy(); e.global_position = Vector2(100, 400)
	e.profile.enabled_stances = [AIController.Stance.KAMIKAZE]
	e.profile.stance_weights = {AIController.Stance.KAMIKAZE: 1.0}
	e._ai.current_stance = AIController.Stance.KAMIKAZE
	e.profile.special_frequency = 0.0
	var p := Player.new(); add_child_autofree(p)
	p.global_position = Vector2(130, 400); p.separation_radii = Vector2.ZERO
	p.side = Fighter.Side.PLAYER
	e.target = p
	var attacked := false
	for _n in range(40):
		e._physics_process(1.0 / 60.0)
		if e.is_attacking():
			attacked = true
			break
	assert_true(attacked, "kamikaze enemy throws a strike at close range")
