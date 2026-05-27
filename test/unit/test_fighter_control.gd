extends "res://addons/gut/test.gd"

const FRAME := 1.0 / 60.0

func test_fighter_defaults_to_player_side():
	var f := Fighter.new()
	add_child_autofree(f)
	assert_eq(f.side, Fighter.Side.PLAYER)

func test_is_dead_when_health_zero():
	var f := Fighter.new()
	add_child_autofree(f)
	assert_false(f.is_dead())
	f.health = 0
	assert_true(f.is_dead())

func _at(x: float, side: int) -> Fighter:
	var f := Fighter.new()
	add_child_autofree(f)
	f.global_position = Vector2(x, 400)
	f.side = side
	f.separation_radii = Vector2.ZERO
	return f

func test_acquires_nearest_enemy_target():
	var me := _at(0, Fighter.Side.PLAYER)
	var enemy := _at(120, Fighter.Side.ENEMY)
	me._physics_process(FRAME)
	assert_eq(me.target, enemy)

func test_retargets_when_current_target_dies():
	var me := _at(0, Fighter.Side.PLAYER)
	var near := _at(100, Fighter.Side.ENEMY)
	var far := _at(260, Fighter.Side.ENEMY)
	me._physics_process(FRAME)
	assert_eq(me.target, near)
	near.health = 0                      # current target dies
	me._physics_process(FRAME)           # must retarget immediately
	assert_eq(me.target, far)

func test_faces_target_continuously():
	var me := _at(100, Fighter.Side.PLAYER)
	var enemy := _at(300, Fighter.Side.ENEMY)   # to the right
	me._physics_process(FRAME)
	assert_eq(me.facing(), 1.0, "faces right toward the right-side target")
	enemy.global_position.x = -50               # move target to the left
	me._physics_process(FRAME)
	assert_eq(me.facing(), -1.0, "turns to keep facing the target")
