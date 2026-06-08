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

func test_die_sets_dead_mode():
	var f := _fighter()
	f.die()
	assert_eq(f.mode, Fighter.Mode.DEAD)
	assert_true(f.is_dead())

func test_die_is_idempotent():
	var f := _fighter()
	f.die()
	f.die()   # second call is a no-op (no error, still DEAD)
	assert_eq(f.mode, Fighter.Mode.DEAD)

func test_die_while_holding_a_victim_releases_it():
	var captor := _fighter()
	var vic := _fighter()
	captor._grappling = vic
	vic._grappled_by = captor
	vic.mode = Fighter.Mode.GRABBED
	captor.mode = Fighter.Mode.GRABBING
	captor.die()
	assert_null(captor._grappling, "captor lets go of the victim")
	assert_null(vic._grappled_by, "victim is no longer held")
	assert_eq(vic.mode, Fighter.Mode.NORMAL, "released victim returns to NORMAL")

func test_die_while_held_releases_the_captor():
	var captor := _fighter()
	var vic := _fighter()
	captor._grappling = vic
	vic._grappled_by = captor
	captor.mode = Fighter.Mode.GRABBING
	vic.mode = Fighter.Mode.GRABBED
	vic.die()
	assert_null(vic._grappled_by)
	assert_null(captor._grappling, "captor no longer drives the dead victim")
	assert_eq(captor.mode, Fighter.Mode.NORMAL, "captor returns to NORMAL")
