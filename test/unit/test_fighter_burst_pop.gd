extends "res://addons/gut/test.gd"

func _fighter_at(x: float, y: float, mode := Fighter.Mode.NORMAL) -> Fighter:
	var f := Fighter.new()
	add_child_autofree(f)
	f.global_position = Vector2(x, y)
	f.side = Fighter.Side.ENEMY
	f.separation_radii = Vector2.ZERO
	f.mode = mode
	return f

func _headbutt(pop: bool, dmg_override := 0, locks := false) -> MoveSequence:
	var m := MoveSequence.new()
	m.id = "test_headbutt"
	m.attack_mode = AMode.HDBUTT
	m.causes_dizzy = true
	m.victim_pop = pop
	m.damage_override = dmg_override
	m.locks_victim = locks
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

func test_pop_from_headbutt_pops_up_without_moving():
	var atk := _fighter_at(100, 400)
	var vic := _fighter_at(140, 400, Fighter.Mode.NORMAL)
	vic.pop_from_headbutt(atk)
	assert_eq(vic.mode, Fighter.Mode.DIZZY)
	assert_gt(vic._vy, 0.0)                       # pops UP
	assert_eq(vic.global_position.x, 140.0)       # but stays pinned in place (no knockback)

func test_locks_victim_hit_does_not_move_the_victim():
	var atk := _fighter_at(100, 400)
	var vic := _fighter_at(140, 400, Fighter.Mode.NORMAL)
	vic.receive_hit(atk, _headbutt(false, 0, true))   # burst hit: pins in place
	assert_eq(vic.global_position.x, 140.0)

func test_non_locking_hit_knocks_the_victim_back():
	var atk := _fighter_at(100, 400)
	var vic := _fighter_at(140, 400, Fighter.Mode.NORMAL)
	vic.receive_hit(atk, _headbutt(false, 0, false))   # normal hit: knocks back
	assert_gt(vic.global_position.x, 140.0)
