extends "res://addons/gut/test.gd"
## A real fight in a headless scene: Enemy approaches, strikes/grabs the player, and dies.

func _world() -> Node2D:
	var root := Node2D.new(); add_child_autofree(root)
	var ar := AttackResolver.new()
	ar.name = "AttackResolver"   # Godot 4 does not auto-name nodes by class; set it explicitly
	root.add_child(ar)
	return root

func _profile() -> AIProfile:
	var p := AIProfile.new()
	p.skill = 8
	p.reaction_delay = Vector2i(6, 6)
	p.special_frequency = 0.3
	p.preferred_range = AIProfile.PreferredRange.CLOSE
	p.enabled_stances = [AIController.Stance.KAMIKAZE]
	p.stance_weights = {AIController.Stance.KAMIKAZE: 1.0}
	return p

func test_enemy_approaches_and_damages_the_player():
	var root := _world()
	var e := Enemy.new(); root.add_child(e); autofree(e)
	e.global_position = Vector2(100, 400); e.separation_radii = Vector2.ZERO
	e.side = Fighter.Side.ENEMY; e.profile = _profile(); e._ai.current_stance = AIController.Stance.KAMIKAZE
	var p := Player.new(); root.add_child(p); autofree(p)
	p.global_position = Vector2(160, 400); p.separation_radii = Vector2.ZERO
	p.side = Fighter.Side.PLAYER
	var p_start := p.health
	for _n in range(180):       # ~3 s
		e._physics_process(1.0 / 60.0)
		p._physics_process(1.0 / 60.0)
		root.get_node("AttackResolver").resolve_tick() if root.has_node("AttackResolver") else null
	assert_lt(p.health, p_start, "enemy landed at least one hit on the player over 3 s")

func test_enemy_dies_and_player_can_be_grabbed():
	var root := _world()
	var e := Enemy.new(); root.add_child(e); autofree(e)
	e.global_position = Vector2(150, 400); e.separation_radii = Vector2.ZERO
	e.side = Fighter.Side.ENEMY; e.profile = _profile()
	var p := Player.new(); root.add_child(p); autofree(p)
	p.global_position = Vector2(160, 400); p.separation_radii = Vector2.ZERO
	p.side = Fighter.Side.PLAYER
	# enemy dies at 0 health
	e.health = 0
	assert_true(e.is_dead())
	# the player (a Fighter) is grab-eligible by the resolver when standing
	var ar := AttackResolver.new(); autofree(ar)
	assert_true(ar._can_be_grabbed(p), "a standing player can be grabbed by an enemy")
