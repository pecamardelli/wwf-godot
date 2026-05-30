extends "res://addons/gut/test.gd"

const FRAME: float = 1.0 / 60.0

## Stub fighters that always hold a fixed direction, to drive movement end-to-end.
class _HoldRight extends Fighter:
	func get_input_direction() -> Vector2:
		return Vector2.RIGHT

class _HoldDownRight extends Fighter:
	func get_input_direction() -> Vector2:
		return Vector2(1, 1)

class _HoldDown extends Fighter:
	func get_input_direction() -> Vector2:
		return Vector2.DOWN

func test_vertical_walk_is_slower_than_horizontal():
	var f := _HoldDown.new()
	add_child_autofree(f)
	assert_lt(f.depth_speed_scale, 1.0, "depth axis is scaled down")

func test_vertical_walk_reaches_depth_scaled_top_speed():
	var f := _HoldDown.new()
	add_child_autofree(f)
	f.mode = Fighter.Mode.NORMAL
	f.velocity = Vector2.ZERO
	for _i in range(120):
		f._physics_process(FRAME)
	var expected := ArcadeUnits.WALK_CARDINAL * f.walk_speed_scale * f.depth_speed_scale
	assert_almost_eq(f.velocity.y, expected, 0.5, "vertical top speed = cardinal * walk_speed_scale * depth_speed_scale")

func _scaled_cardinal(f: Fighter) -> float:
	return ArcadeUnits.WALK_CARDINAL * f.walk_speed_scale

func test_walk_speed_is_scaled_below_arcade_top():
	# The feel layer slows the walk: scale is < 1 so top speed is below the arcade table.
	var f := _HoldRight.new()
	add_child_autofree(f)
	assert_lt(f.walk_speed_scale, 1.0, "walk is slowed relative to the arcade table")

func test_walk_accelerates_from_rest_does_not_jump_to_top():
	# One frame from rest must NOT already be at top speed — there is a ramp.
	var f := _HoldRight.new()
	add_child_autofree(f)
	f.mode = Fighter.Mode.NORMAL
	f.velocity = Vector2.ZERO
	f._physics_process(FRAME)
	assert_gt(f.velocity.x, 0.0, "starts moving")
	assert_lt(f.velocity.x, _scaled_cardinal(f), "has not reached top speed in one frame")

func test_walk_reaches_scaled_top_speed_over_time():
	var f := _HoldRight.new()
	add_child_autofree(f)
	f.mode = Fighter.Mode.NORMAL
	f.velocity = Vector2.ZERO
	for _i in range(120):
		f._physics_process(FRAME)
	assert_almost_eq(f.velocity.x, _scaled_cardinal(f), 0.5, "ramps up to the slowed top speed")

func test_diagonal_also_accelerates_from_rest():
	var f := _HoldDownRight.new()
	add_child_autofree(f)
	f.mode = Fighter.Mode.NORMAL
	f.velocity = Vector2.ZERO
	f._physics_process(FRAME)
	var top := ArcadeUnits.WALK_DIAGONAL_AXIS * f.walk_speed_scale
	assert_gt(f.velocity.length(), 0.0, "diagonal starts moving")
	assert_lt(f.velocity.x, top, "diagonal x has not reached top speed in one frame")
	assert_lt(f.velocity.y, top, "diagonal y has not reached top speed in one frame")

func test_helpless_mode_snaps_velocity_to_zero():
	# Stun cuts control instantly (arcade): no coasting/deceleration while helpless.
	var f := _HoldRight.new()
	add_child_autofree(f)
	f.mode = Fighter.Mode.NORMAL
	for _i in range(60):
		f._physics_process(FRAME)
	assert_gt(f.velocity.length(), 0.0)
	f.mode = Fighter.Mode.DIZZY
	f._physics_process(FRAME)
	assert_eq(f.velocity, Vector2.ZERO, "control cut snaps to a stop")

func _at_xy(x: float, y: float, side: int) -> Fighter:
	var f := Fighter.new()
	add_child_autofree(f)
	f.global_position = Vector2(x, y)
	f.side = side
	f.separation_radii = Vector2.ZERO
	return f

func test_depth_facing_pivots_to_back_when_target_behind():
	var me := _at_xy(100, 400, Fighter.Side.PLAYER)
	# target far above (smaller Y = behind in depth) and to the right
	var enemy := _at_xy(140, 200, Fighter.Side.ENEMY)
	for _i in range(40):
		me._physics_process(1.0 / 60.0)
	assert_false(me._turning, "pivot has completed")
	assert_eq(me._depth_facing, Facing.BACK, "turns to face the behind/up target (back view)")
	assert_eq(me.facing(), 1.0, "still horizontally facing the right-side target")

class _RunHolder extends Fighter:
	var run_now: bool = false
	var held: Vector2 = Vector2.ZERO
	func wants_to_run() -> bool:
		return run_now
	func get_input_direction() -> Vector2:
		return held

func test_latching_run_abandons_an_in_progress_pivot():
	# A turn-pivot in flight must not freeze on its first rotate frame when a run latches
	# (running snaps facing and shows the run clip).
	var f := _RunHolder.new()
	add_child_autofree(f)
	f.global_position = Vector2(100, 400)
	f.separation_radii = Vector2.ZERO
	f.mode = Fighter.Mode.NORMAL
	f._turning = true                       # pretend a pivot is mid-flight
	f.held = Vector2.RIGHT
	f.run_now = true
	f._physics_process(1.0 / 60.0)          # latch the run
	assert_eq(f.mode, Fighter.Mode.RUNNING, "run latched")
	assert_false(f._turning, "the in-progress pivot is abandoned when running")

func test_no_pivot_when_already_facing_target():
	var me := _at_xy(100, 400, Fighter.Side.PLAYER)
	var enemy := _at_xy(300, 500, Fighter.Side.ENEMY)  # right + nearer camera -> FR (default)
	me.target = enemy                                   # explicit (don't depend on tick-order targeting)
	me._set_facing(1.0)
	me._physics_process(1.0 / 60.0)
	assert_false(me._turning, "no pivot needed: already facing the target corner")

const FIGHTER_SCENE := preload("res://scenes/Fighter.tscn")

func _spawn() -> Fighter:
	var f: Fighter = FIGHTER_SCENE.instantiate()
	add_child_autofree(f)                       # triggers _ready -> resolves `sprite`
	f.global_position = Vector2(100, 400)
	f.separation_radii = Vector2.ZERO
	return f

func test_vertical_walk_plays_vertical_clip():
	var f := _spawn()
	f._depth_facing = Facing.FRONT
	f._update_animation(Vector2.UP)
	assert_eq(f.sprite.animation, "walk_vertical_front")

func test_diagonal_walk_plays_diagonal_clip():
	var f := _spawn()
	f._depth_facing = Facing.FRONT
	f._set_facing(1.0)
	# up-right is the diagonal sprite's axis when facing right/front (GMS); down-right would
	# fall back to the horizontal clip.
	f._update_animation(Vector2(1, -1))
	assert_eq(f.sprite.animation, "walk_diagonal_front")

func test_back_depth_plays_back_variant():
	var f := _spawn()
	f._depth_facing = Facing.BACK
	f._update_animation(Vector2.RIGHT)
	assert_eq(f.sprite.animation, "walk_horisontal_back")

func test_no_movement_plays_idle_clip():
	var f := _spawn()
	f._depth_facing = Facing.FRONT
	f._update_animation(Vector2.ZERO)
	assert_eq(f.sprite.animation, "idle_front")
	f._depth_facing = Facing.BACK
	f._update_animation(Vector2.ZERO)
	assert_eq(f.sprite.animation, "idle_back")

func test_getup_rise_gates_recovery_then_returns_to_normal():
	var f := _spawn()
	f.mode = Fighter.Mode.ONGROUND
	f._fall_orientation = Fighter.Fall.FACE_UP
	f._react_timer = 1.0 / 60.0           # one tick of down-time left
	f._physics_process(1.0 / 60.0)        # DOWN expires -> RISE begins
	assert_true(f._getup_rising, "enters the RISE phase after down-time")
	assert_eq(f.mode, Fighter.Mode.ONGROUND, "still no control during the rise")
	for _i in range(60):                  # get_up_front is 0.75s; 1s loop finishes it
		f._physics_process(1.0 / 60.0)
	assert_false(f._getup_rising, "rise finished")
	assert_eq(f.mode, Fighter.Mode.NORMAL, "control returns only after the getup clip ends")

func test_getup_clip_chosen_by_fall_orientation():
	var f := _spawn()
	f._fall_orientation = Fighter.Fall.FACE_DOWN_ROLL
	assert_eq(f._getup_anim(), "get_up_back_2")
	f._fall_orientation = Fighter.Fall.FACE_DOWN
	assert_eq(f._getup_anim(), "get_up_back")
	f._fall_orientation = Fighter.Fall.FACE_UP
	assert_eq(f._getup_anim(), "get_up_front")

func test_downed_victim_does_not_reface_when_attacker_crosses():
	# Arcade: helpless/down states never re-face (mode_onground is a ret). A downed wrestler
	# keeps the facing it fell with even if the attacker walks to the other side.
	var me := _at_xy(100, 400, Fighter.Side.PLAYER)
	var enemy := _at_xy(300, 400, Fighter.Side.ENEMY)
	me._set_facing(1.0)                  # fell facing right
	me.mode = Fighter.Mode.ONGROUND
	me._react_timer = 2.0                # lying down
	enemy.global_position.x = -100       # attacker crosses to the left
	for _i in range(10):
		me._physics_process(1.0 / 60.0)
	assert_eq(me.facing(), 1.0, "a downed fighter does not track the attacker")

func test_can_walk_over_a_downed_body():
	var me := _at_xy(100, 400, Fighter.Side.PLAYER)
	me.separation_radii = Vector2(50, 20)
	var downed := _at_xy(110, 400, Fighter.Side.ENEMY)   # overlapping on the lane
	# a STANDING body pushes me out...
	var before := me.global_position
	me._apply_separation()
	assert_ne(me.global_position, before, "standing body still separates")
	# ...a DOWNED body does not (walk over it)
	me.global_position = before
	downed.mode = Fighter.Mode.ONGROUND
	me._apply_separation()
	assert_eq(me.global_position, before, "no push from a body on the ground")

func test_hip_toss_victim_lands_facing_away():
	# Hip toss flips the victim over: it lands facing OPPOSITE the attacker, not the puppet's
	# attacker-facing orientation it had during the throw.
	var atk := _at_xy(100, 400, Fighter.Side.PLAYER)
	var vic := _at_xy(140, 400, Fighter.Side.ENEMY)
	atk._facing = 1.0
	vic._facing = 1.0                       # puppet oriented to the attacker during the throw
	atk._grappling = vic
	vic._grappled_by = atk
	atk._player.play(load("res://assets/sequences/doink/hip_toss.tres"))
	atk._detach_victim()
	assert_eq(vic._facing, -1.0, "hip-tossed victim lands facing opposite the attacker")

func test_fresh_hit_cancels_in_progress_getup_rise():
	# Re-hit while rising must cancel the RISE so it can't linger as a phantom hold.
	var f := _spawn()
	f._getup_rising = true
	f._getup_rise_time = 0.5
	f._enter_reaction({"anim": "shoved", "mode": Fighter.Mode.NORMAL,
		"hitstun_ticks": 12, "knockback": 10.0, "getup_ticks": 0}, 1)
	assert_false(f._getup_rising, "a new hit cancels the in-progress getup rise")
	assert_eq(f._getup_rise_time, 0.0)
