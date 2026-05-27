extends "res://addons/gut/test.gd"

func _fighter(x: float, y: float, side: int) -> Fighter:
	var f := Fighter.new()
	add_child_autofree(f)
	f.global_position = Vector2(x, y)
	f.side = side
	return f

func test_picks_nearest_opposite_side():
	var me := _fighter(0, 400, Fighter.Side.PLAYER)
	var near := _fighter(60, 400, Fighter.Side.ENEMY)
	var far := _fighter(300, 400, Fighter.Side.ENEMY)
	assert_eq(Targeting.pick(me, [near, far]), near)

func test_skips_self_and_same_side():
	var me := _fighter(0, 400, Fighter.Side.PLAYER)
	var ally := _fighter(40, 400, Fighter.Side.PLAYER)
	var enemy := _fighter(200, 400, Fighter.Side.ENEMY)
	assert_eq(Targeting.pick(me, [me, ally, enemy]), enemy, "self + same-side skipped")

func test_downed_enemy_is_deprioritized():
	var me := _fighter(0, 400, Fighter.Side.PLAYER)
	var standing := _fighter(120, 400, Fighter.Side.ENEMY)
	var downed := _fighter(80, 400, Fighter.Side.ENEMY)  # closer, but on the ground
	downed.mode = Fighter.Mode.ONGROUND                  # score ×2 -> 160 > 120
	assert_eq(Targeting.pick(me, [standing, downed]), standing)

func test_last_hit_target_is_stickier():
	var me := _fighter(0, 400, Fighter.Side.PLAYER)
	var a := _fighter(100, 400, Fighter.Side.ENEMY)
	var b := _fighter(95, 400, Fighter.Side.ENEMY)       # slightly closer
	me._who_i_hit = a                                    # a ×0.75 -> 75 < 95
	assert_eq(Targeting.pick(me, [a, b]), a)

func test_prefers_a_live_enemy_over_a_dead_closer_one():
	var me := _fighter(0, 400, Fighter.Side.PLAYER)
	var dead := _fighter(40, 400, Fighter.Side.ENEMY)
	dead.health = 0
	var alive := _fighter(200, 400, Fighter.Side.ENEMY)
	assert_eq(Targeting.pick(me, [dead, alive]), alive)

func test_returns_null_when_no_opponents():
	var me := _fighter(0, 400, Fighter.Side.PLAYER)
	var ally := _fighter(40, 400, Fighter.Side.PLAYER)
	assert_null(Targeting.pick(me, [ally]))
