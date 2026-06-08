extends "res://addons/gut/test.gd"

func _fighter_at(x: float, y: float, mode := Fighter.Mode.NORMAL) -> Fighter:
	var f := Fighter.new()
	add_child_autofree(f)
	f.global_position = Vector2(x, y)
	f.side = Fighter.Side.ENEMY
	f.separation_radii = Vector2.ZERO
	f.mode = mode
	return f

func _headbutt(pop: bool, dmg_override := 0) -> MoveSequence:
	var m := MoveSequence.new()
	m.id = "test_headbutt"
	m.attack_mode = AMode.HDBUTT
	m.causes_dizzy = true
	m.victim_pop = pop
	m.damage_override = dmg_override
	return m

func test_victim_pop_true_hops():
	var atk := _fighter_at(100, 400)
	var vic := _fighter_at(140, 400, Fighter.Mode.NORMAL)
	vic.receive_hit(atk, _headbutt(true))
	assert_eq(vic.mode, Fighter.Mode.DIZZY)
	assert_gt(vic._vy, 0.0)

func test_victim_pop_false_no_hop():
	var atk := _fighter_at(100, 400)
	var vic := _fighter_at(140, 400, Fighter.Mode.NORMAL)
	vic.receive_hit(atk, _headbutt(false))
	assert_eq(vic.mode, Fighter.Mode.DIZZY)
	assert_eq(vic._vy, 0.0)

func test_damage_override_hits_harder():
	var atk := _fighter_at(100, 400)
	var vic := _fighter_at(140, 400, Fighter.Mode.NORMAL)
	vic.health = 163
	vic.receive_hit(atk, _headbutt(false, 17))   # 17*345/256 = 22
	assert_eq(vic.health, 141)

func test_pop_from_headbutt_pops_and_pushes_away():
	var atk := _fighter_at(100, 400)
	var vic := _fighter_at(140, 400, Fighter.Mode.NORMAL)
	vic.pop_from_headbutt(atk)
	assert_eq(vic.mode, Fighter.Mode.DIZZY)
	assert_gt(vic._vy, 0.0)
	assert_gt(vic.global_position.x, 140.0)   # knocked away from the attacker (to the right)
