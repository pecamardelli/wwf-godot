extends "res://addons/gut/test.gd"
## Enemy.ai_enabled gate: with AI off, the enemy stands still — no movement, no attacks — even
## with a fightable player right next to it.

func _world() -> Node2D:
	var root := Node2D.new(); add_child_autofree(root)
	var ar := AttackResolver.new()
	ar.name = "AttackResolver"
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

func test_ai_disabled_enemy_stands_still_and_does_not_attack():
	var root := _world()
	var e := Enemy.new(); root.add_child(e); autofree(e)
	e.global_position = Vector2(100, 400); e.separation_radii = Vector2.ZERO
	e.side = Fighter.Side.ENEMY; e.profile = _profile()
	e.ai_enabled = false                       # AI OFF -> should be inert
	var p := Player.new(); root.add_child(p); autofree(p)
	p.global_position = Vector2(160, 400); p.separation_radii = Vector2.ZERO
	p.side = Fighter.Side.PLAYER
	var e_start := e.global_position
	var p_start := p.health
	for _n in range(180):       # ~3 s
		e._physics_process(1.0 / 60.0)
		p._physics_process(1.0 / 60.0)
		root.get_node("AttackResolver").resolve_tick()
	assert_almost_eq(e.global_position.x, e_start.x, 0.01, "AI-off enemy did not move (x)")
	assert_almost_eq(e.global_position.y, e_start.y, 0.01, "AI-off enemy did not move (z)")
	assert_false(e.is_attacking(), "AI-off enemy never starts a move")
	assert_eq(p.health, p_start, "AI-off enemy never damages the player")

func test_ai_enabled_by_default():
	var e := Enemy.new(); add_child_autofree(e)
	assert_true(e.ai_enabled, "Enemy class default is AI ON (sandbox UI flips it off)")

func test_disabling_ai_cancels_an_in_progress_run():
	# Regression: a RUNNING enemy that gets AI disabled must STOP, not keep sprinting off-screen
	# (the run latch persists on zero input). Put it in a run, disable AI, then tick.
	var root := _world()
	var e := Enemy.new(); root.add_child(e); autofree(e)
	e.global_position = Vector2(100, 400); e.separation_radii = Vector2.ZERO
	e.side = Fighter.Side.ENEMY; e.profile = _profile()
	e.mode = Fighter.Mode.RUNNING
	e._run_dir_x = 1.0
	e.velocity = Vector2(ArcadeUnits.RUN_SPEED, 0)
	e.ai_enabled = false
	var start_x := e.global_position.x
	for _n in range(120):       # ~2 s
		e._physics_process(1.0 / 60.0)
	assert_ne(e.mode, Fighter.Mode.RUNNING, "the run is cancelled when AI is disabled")
	assert_lt(e.global_position.x - start_x, 5.0, "the enemy stops almost immediately (no sprint-off)")
