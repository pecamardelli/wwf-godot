extends "res://addons/gut/test.gd"

func _fighter() -> Fighter:
	var f := Fighter.new()
	add_child_autofree(f)
	f.global_position = Vector2(100, 400)
	f.separation_radii = Vector2.ZERO
	return f

func test_dead_mode_counts_as_dead_even_at_full_health():
	var f := _fighter()
	f.mode = Fighter.Mode.DEAD
	assert_true(f.is_dead(), "DEAD mode => is_dead even with HP")

func test_zero_health_counts_as_dead():
	var f := _fighter()
	f.health = 0
	assert_true(f.is_dead())

func test_normal_full_health_is_not_dead():
	var f := _fighter()
	assert_false(f.is_dead())
