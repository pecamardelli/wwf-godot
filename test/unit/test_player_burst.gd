extends "res://addons/gut/test.gd"

const BURST := preload("res://assets/sequences/doink/headbutt_burst.tres")

func _player_at(x: float, y: float) -> Player:
	var p := Player.new()
	add_child_autofree(p)
	p.global_position = Vector2(x, y)
	p.side = Fighter.Side.PLAYER
	p.separation_radii = Vector2.ZERO
	return p

func _enemy_at(x: float, y: float) -> Fighter:
	var e := Fighter.new()
	add_child_autofree(e)
	e.global_position = Vector2(x, y)
	e.side = Fighter.Side.ENEMY
	e.separation_radii = Vector2.ZERO
	e.mode = Fighter.Mode.NORMAL
	return e

# Drive a single burst hit, then end its move so the chain decision can run.
func _land_one_burst_hit(p: Player, e: Fighter) -> void:
	p.start_move(BURST)
	e.receive_hit(p, BURST)      # appends e to p._hit_by_current_move; e enters dizzy (no pop)
	p._player.play(null)         # simulate the burst hit's sequence finishing (not is_attacking)

func test_chain_continues_when_buffered_and_close():
	var p := _player_at(100, 400)
	var e := _enemy_at(130, 410)   # CLOSE
	p.target = e
	p._burst.start()               # count 1
	_land_one_burst_hit(p, e)
	p._burst.note_continue()       # player re-pressed during the hit
	assert_true(p._service_burst_end(true))
	assert_true(p.is_attacking(), "started the next burst hit")
	assert_eq(p._burst.count, 2)

func test_burst_ends_and_pops_when_not_buffered():
	var p := _player_at(100, 400)
	var e := _enemy_at(130, 410)
	p.target = e
	p._burst.start()
	_land_one_burst_hit(p, e)
	assert_eq(e._vy, 0.0, "intermediate hit did not pop")
	assert_true(p._service_burst_end(true))      # no continue buffered
	assert_false(p.is_attacking(), "no chain")
	assert_eq(p._burst.count, 0, "burst reset")
	assert_gt(e._vy, 0.0, "ender popped the victim")

func test_cap_at_four_forces_end_and_pop():
	var p := _player_at(100, 400)
	var e := _enemy_at(130, 410)
	p.target = e
	p._burst.count = 4             # at the cap
	_land_one_burst_hit(p, e)
	p._burst.note_continue()       # ignored at the cap
	assert_true(p._service_burst_end(true))
	assert_false(p.is_attacking())
	assert_eq(p._burst.count, 0)
	assert_gt(e._vy, 0.0)

func test_out_of_range_ends_with_pop():
	var p := _player_at(100, 400)
	var e := _enemy_at(130, 410)
	p.target = e
	p._burst.start()
	_land_one_burst_hit(p, e)
	p._burst.note_continue()
	assert_true(p._service_burst_end(false))     # close = false -> cannot chain
	assert_false(p.is_attacking())
	assert_eq(p._burst.count, 0)
	assert_gt(e._vy, 0.0)
