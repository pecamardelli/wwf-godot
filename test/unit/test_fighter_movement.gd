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

func test_no_pivot_when_already_facing_target():
	var me := _at_xy(100, 400, Fighter.Side.PLAYER)
	var enemy := _at_xy(300, 500, Fighter.Side.ENEMY)  # right + nearer camera -> FR (default)
	me.target = enemy                                   # explicit (don't depend on tick-order targeting)
	me._set_facing(1.0)
	me._physics_process(1.0 / 60.0)
	assert_false(me._turning, "no pivot needed: already facing the target corner")
