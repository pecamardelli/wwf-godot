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

func test_blocked_hit_keeps_guard_no_reaction():
	var attacker := _at(100, Fighter.Side.ENEMY)
	var victim := _at(140, Fighter.Side.PLAYER)
	victim.mode = Fighter.Mode.BLOCK
	victim.receive_hit(attacker, load("res://assets/sequences/doink/punch.tres"))
	assert_eq(victim.mode, Fighter.Mode.BLOCK, "stays guarding after a blocked hit")
	assert_eq(victim._react_timer, 0.0, "a blocked hit does not enter the reaction-timer state")
	assert_eq(victim.health, Damage.LIFE_MAX - 1, "blocked punch still deals 1")

class _Guard extends Fighter:
	func wants_to_block() -> bool:
		return true

func test_block_preserves_facing_ignores_target():
	var me := _Guard.new()
	add_child_autofree(me)
	me.global_position = Vector2(100, 400)
	me.side = Fighter.Side.PLAYER
	me.separation_radii = Vector2.ZERO
	var enemy := _at(-100, Fighter.Side.ENEMY)   # target to the LEFT
	me._set_facing(1.0)                           # we were looking RIGHT
	me._physics_process(FRAME)                    # blocking: must NOT snap to the left-side target
	assert_eq(me.facing(), 1.0, "block preserves the facing we had, ignoring the target side")

class _RunLatch extends Fighter:
	var run_now: bool = false
	var held: Vector2 = Vector2.ZERO
	func wants_to_run() -> bool:
		return run_now
	func get_input_direction() -> Vector2:
		return held

func test_run_latches_and_persists_without_holding():
	var f := _RunLatch.new()
	add_child_autofree(f)
	f.mode = Fighter.Mode.NORMAL
	f.velocity = Vector2.ZERO
	f._set_facing(1.0)
	f.run_now = true
	f._physics_process(FRAME)     # press run once
	f.run_now = false             # release everything
	for _i in range(120):
		f._physics_process(FRAME)
	assert_eq(f.mode, Fighter.Mode.RUNNING, "still running after release (latched)")
	assert_almost_eq(f.velocity.x, ArcadeUnits.RUN_SPEED, 1.0, "persists at run speed toward facing")

func test_opposite_direction_stops_run():
	var f := _RunLatch.new()
	add_child_autofree(f)
	f.mode = Fighter.Mode.NORMAL
	f.velocity = Vector2.ZERO
	f._set_facing(1.0)
	f.run_now = true
	f._physics_process(FRAME)
	f.run_now = false
	for _i in range(30):
		f._physics_process(FRAME)
	assert_eq(f.mode, Fighter.Mode.RUNNING)
	f.held = Vector2.LEFT          # opposite of the +1 run direction
	f._physics_process(FRAME)
	assert_eq(f.mode, Fighter.Mode.NORMAL, "opposite direction stops the run")

func test_attacking_stops_run():
	var f := _RunLatch.new()
	add_child_autofree(f)
	f.mode = Fighter.Mode.NORMAL
	f.velocity = Vector2.ZERO
	f._set_facing(1.0)
	f.run_now = true
	f._physics_process(FRAME)
	f.run_now = false
	for _i in range(30):
		f._physics_process(FRAME)
	assert_eq(f.mode, Fighter.Mode.RUNNING)
	f.start_move(load("res://assets/sequences/doink/big_boot.tres"))
	assert_eq(f.mode, Fighter.Mode.NORMAL, "starting an attack stops the run")

func test_run_faces_its_direction_not_target():
	var f := _RunLatch.new()
	add_child_autofree(f)
	f.global_position = Vector2(100, 400)
	f.side = Fighter.Side.PLAYER
	f.separation_radii = Vector2.ZERO
	var enemy := _at(500, Fighter.Side.ENEMY)   # target to the RIGHT
	f._set_facing(1.0)                            # was looking right
	f.held = Vector2.LEFT                         # run LEFT (away from the target)
	f.run_now = true
	f._physics_process(FRAME)                     # latch run left
	f.run_now = false
	for _i in range(5):
		f._physics_process(FRAME)
	assert_eq(f.facing(), -1.0, "faces the run direction (left), not the right-side target — no moonwalk")

func test_left_drawn_reaction_anims_invert_flip():
	# left-drawn art faces left, so facing RIGHT must flip_h=true to render facing right
	assert_true(Fighter.flip_h_for("facepunched_front", 1.0))
	assert_true(Fighter.flip_h_for("defence", 1.0))
	assert_true(Fighter.flip_h_for("droped", 1.0))
	assert_false(Fighter.flip_h_for("shoved", -1.0))

func test_right_drawn_anims_use_normal_flip():
	assert_false(Fighter.flip_h_for("idle_front", 1.0))
	assert_true(Fighter.flip_h_for("idle_front", -1.0))
	assert_false(Fighter.flip_h_for("mid_punch_front", 1.0))
	assert_false(Fighter.flip_h_for("run", 1.0))
