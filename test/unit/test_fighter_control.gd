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

class _WalkLeft extends Fighter:
	func get_input_direction() -> Vector2:
		return Vector2.LEFT

func test_keeps_facing_target_while_walking_away():
	var me := _WalkLeft.new()
	add_child_autofree(me)
	me.global_position = Vector2(100, 400)
	me.side = Fighter.Side.PLAYER
	me.separation_radii = Vector2.ZERO
	var enemy := _at(300, Fighter.Side.ENEMY)   # target to the RIGHT
	for _i in range(5):
		me._physics_process(FRAME)
	assert_eq(me.facing(), 1.0, "back-pedals: still faces the right-side target while walking left")

func test_walk_dir_multiplier_backward_and_opp_down():
	var f := Fighter.new()
	add_child_autofree(f)
	assert_almost_eq(f.walk_dir_multiplier(false, false), 1.0, 0.001)                       # toward, target standing
	assert_almost_eq(f.walk_dir_multiplier(true, false), ArcadeUnits.BACKWARD_MULT, 0.001)  # away
	assert_almost_eq(f.walk_dir_multiplier(false, true), ArcadeUnits.OPP_DOWN_MULT, 0.001)  # target down
	assert_almost_eq(f.walk_dir_multiplier(true, true), ArcadeUnits.BACKWARD_MULT * ArcadeUnits.OPP_DOWN_MULT, 0.001)

class _RunningRight extends Fighter:
	func get_input_direction() -> Vector2:
		return Vector2.RIGHT
	func wants_to_run() -> bool:
		return true

func test_run_uses_run_speed():
	var f := _RunningRight.new()
	add_child_autofree(f)
	f.mode = Fighter.Mode.NORMAL
	f.velocity = Vector2.ZERO
	for _i in range(120):
		f._physics_process(FRAME)
	assert_eq(f.mode, Fighter.Mode.RUNNING)
	assert_almost_eq(f.velocity.x, ArcadeUnits.RUN_SPEED, 1.0)

class _Blocker extends Fighter:
	func wants_to_block() -> bool:
		return true

func test_block_enters_block_mode_and_holds_still():
	var f := _Blocker.new()
	add_child_autofree(f)
	f.mode = Fighter.Mode.NORMAL
	f._physics_process(FRAME)
	assert_eq(f.mode, Fighter.Mode.BLOCK)
	assert_eq(f.velocity, Vector2.ZERO, "no movement while blocking")

func test_block_reduces_damage_to_one():
	var attacker := _at(100, Fighter.Side.ENEMY)
	var victim := _at(140, Fighter.Side.PLAYER)
	victim.mode = Fighter.Mode.BLOCK
	victim.receive_hit(attacker, load("res://assets/sequences/doink/punch.tres"))
	assert_eq(victim.health, Damage.LIFE_MAX - 1, "blocked punch deals 1")

func test_mash_reduces_remaining_getup_time():
	var f := _at(0, Fighter.Side.PLAYER)
	f.mode = Fighter.Mode.ONGROUND
	f._react_timer = 2.0
	var before := f._react_timer
	f.mash_recover()
	assert_lt(f._react_timer, before, "a mash press shortens the down-time")

func test_mash_cannot_go_below_zero():
	var f := _at(0, Fighter.Side.PLAYER)
	f.mode = Fighter.Mode.ONGROUND
	f._react_timer = 0.05
	f.mash_recover()
	assert_gte(f._react_timer, 0.0, "never negative")

func test_mash_only_works_while_onground():
	var f := _at(0, Fighter.Side.PLAYER)
	f.mode = Fighter.Mode.NORMAL
	f._react_timer = 1.0
	f.mash_recover()
	assert_eq(f._react_timer, 1.0, "mash does nothing unless downed")

func test_landing_a_hit_records_who_i_hit():
	var attacker := _at(100, Fighter.Side.PLAYER)
	var victim := _at(140, Fighter.Side.ENEMY)
	victim.receive_hit(attacker, load("res://assets/sequences/doink/punch.tres"))
	assert_eq(attacker._who_i_hit, victim, "landing a hit records the victim for targeting stickiness")
