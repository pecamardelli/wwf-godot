extends "res://addons/gut/test.gd"
## End-to-end: the authored aerial sequences launch the fighter and land it.

const FRAME: float = 1.0 / 60.0
const FLY_KICK := preload("res://assets/sequences/doink/flying_kick.tres")
const CLOTHESLINE := preload("res://assets/sequences/doink/flying_clothesline.tres")

func test_flying_kick_launches_and_lands():
	var p := Player.new()
	add_child_autofree(p)
	var foe := Fighter.new()
	add_child_autofree(foe)
	p.global_position = Vector2(0, 400); p._set_facing(1.0)
	foe.global_position = Vector2(150, 400); foe.mode = Fighter.Mode.NORMAL
	p.target = foe
	p.start_move(FLY_KICK)
	var went_airborne := false
	var max_h := 0.0
	for _i in range(240):
		p._physics_process(FRAME)
		if p.mode == Fighter.Mode.INAIR:
			went_airborne = true
		max_h = maxf(max_h, p._height)
		if went_airborne and p.mode == Fighter.Mode.NORMAL and not p.is_attacking():
			break
	assert_true(went_airborne, "flying kick took the fighter airborne")
	assert_gt(max_h, 50.0, "rose off the mat")
	assert_almost_eq(p._height, 0.0, 0.001, "landed back on the mat")

func test_clothesline_launches_forward():
	var p := Player.new()
	add_child_autofree(p)
	p.global_position = Vector2(0, 400); p._set_facing(1.0)
	p.start_move(CLOTHESLINE)
	for _i in range(12):
		p._physics_process(FRAME)
	assert_gt(p.global_position.x, 0.0, "clothesline carried the body forward")
