extends "res://addons/gut/test.gd"

func _player_at(x: float, y: float) -> Player:
	var p := Player.new()
	add_child_autofree(p)
	p.global_position = Vector2(x, y)
	p.side = Fighter.Side.PLAYER
	p.separation_radii = Vector2.ZERO
	return p

func _enemy_at(x: float, y: float, mode: int) -> Fighter:
	var f := Fighter.new()
	add_child_autofree(f)
	f.global_position = Vector2(x, y)
	f.side = Fighter.Side.ENEMY
	f.separation_radii = Vector2.ZERO
	f.mode = mode
	return f

func test_far_standing_opponent_is_normal_range():
	var p := _player_at(100, 400)
	var e := _enemy_at(300, 400, Fighter.Mode.NORMAL)
	p.target = e
	assert_eq(p._current_range(), MoveTable.Rng.NORMAL)

func test_close_standing_opponent_is_close_range():
	var p := _player_at(100, 400)
	var e := _enemy_at(130, 410, Fighter.Mode.NORMAL)  # dx30<=50, dz10<=45
	p.target = e
	assert_eq(p._current_range(), MoveTable.Rng.CLOSE)

func test_grounded_opponent_in_range_is_grounded():
	var p := _player_at(100, 400)
	var e := _enemy_at(200, 400, Fighter.Mode.ONGROUND)  # dx100<=120
	p.target = e
	assert_eq(p._current_range(), MoveTable.Rng.GROUNDED)

func test_grounded_opponent_far_is_normal():
	var p := _player_at(100, 400)
	var e := _enemy_at(300, 400, Fighter.Mode.ONGROUND)  # dx200>120
	p.target = e
	assert_eq(p._current_range(), MoveTable.Rng.NORMAL)

func test_running_is_running_range():
	var p := _player_at(100, 400)
	var e := _enemy_at(130, 400, Fighter.Mode.NORMAL)
	p.target = e
	p.mode = Fighter.Mode.RUNNING
	assert_eq(p._current_range(), MoveTable.Rng.RUNNING)

func test_no_target_is_normal_range():
	var p := _player_at(100, 400)
	p.target = null
	assert_eq(p._current_range(), MoveTable.Rng.NORMAL)

func test_grounded_opponent_outside_depth_is_normal():
	var p := _player_at(100, 400)
	var e := _enemy_at(100, 600, Fighter.Mode.ONGROUND)  # dx0, dz200>120 -> out of grounded reach
	p.target = e
	assert_eq(p._current_range(), MoveTable.Rng.NORMAL)
