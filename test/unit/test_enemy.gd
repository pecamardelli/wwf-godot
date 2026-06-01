extends "res://addons/gut/test.gd"

func test_fighter_exposes_current_range_for_subclasses():
	var f := Fighter.new(); add_child_autofree(f)
	f.global_position = Vector2(100, 400); f.separation_radii = Vector2.ZERO
	var e := Fighter.new(); add_child_autofree(e)
	e.global_position = Vector2(300, 400); e.separation_radii = Vector2.ZERO
	e.mode = Fighter.Mode.NORMAL
	f.target = e
	assert_eq(f._current_range(), MoveTable.Rng.NORMAL)
