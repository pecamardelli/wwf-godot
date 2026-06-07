extends "res://addons/gut/test.gd"
## Fighter height physics: apply_launch -> INAIR, rises then lands back to the mat.

const FRAME: float = 1.0 / 60.0

func test_launch_enters_inair():
	var f := Fighter.new()
	add_child_autofree(f)
	f.mode = Fighter.Mode.NORMAL
	f.apply_launch(ArcadeUnits.FLYKICK_YVEL, Vector2.ZERO)
	assert_eq(f.mode, Fighter.Mode.INAIR)
	assert_gt(f._vy, 0.0, "seeded with upward velocity")

func test_rises_then_lands():
	var f := Fighter.new()
	add_child_autofree(f)
	f.mode = Fighter.Mode.NORMAL
	f.apply_launch(ArcadeUnits.FLYKICK_YVEL, Vector2.ZERO)
	var max_h := 0.0
	var landed := false
	for _i in range(180):
		f._physics_process(FRAME)
		max_h = maxf(max_h, f._height)
		if f.mode == Fighter.Mode.NORMAL:
			landed = true
			break
	assert_gt(max_h, 50.0, "rose meaningfully off the mat")
	assert_true(landed, "returned to NORMAL on landing")
	assert_almost_eq(f._height, 0.0, 0.001, "height clamped to the mat")
	assert_almost_eq(f._vy, 0.0, 0.001, "vertical velocity cleared on landing")

func test_planar_velocity_carries_horizontally():
	var f := Fighter.new()
	add_child_autofree(f)
	f.mode = Fighter.Mode.NORMAL
	f.global_position = Vector2(0, 400)
	f.apply_launch(ArcadeUnits.FLYKICK_YVEL, Vector2(200, 0))
	for _i in range(8):
		f._physics_process(FRAME)
	assert_gt(f.global_position.x, 0.0, "moved forward in the air")
