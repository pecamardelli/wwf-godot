extends "res://addons/gut/test.gd"

func _make() -> Fighter:
	var f := Fighter.new(); add_child_autofree(f); return f

func _neck_seq() -> MoveSequence:
	return load("res://assets/sequences/doink/neck_grab.tres")

func test_neck_grab_enters_head_hold():
	var atk := _make(); var vic := _make()
	atk.start_move(_neck_seq())
	atk._player.advance(1.0 / 60.0)         # WAIT_HIT_OPP
	vic.receive_grab(atk, atk.current_move())
	atk._player.notify_grab_connected()
	for _i in range(6):                      # advance into SET_ATTACH then finish
		atk._physics_process(1.0 / 60.0)
	assert_eq(atk.mode, Fighter.Mode.HEADHOLD)
	assert_eq(vic.mode, Fighter.Mode.HEADHELD)

func test_immobilize_time_counts_down():
	var f := _make()
	f.set_immobilize_ticks(15)
	assert_true(f.is_immobilized())
	for _i in range(20):
		f._physics_process(1.0 / 60.0)
	assert_false(f.is_immobilized(), "immobilize wears off")

func test_head_hold_auto_breaks_after_timeout():
	var atk := _make(); var vic := _make()
	# Enter the hold directly with a short break window.
	atk.mode = Fighter.Mode.HEADHOLD; atk._grappling = vic; atk._set_headhold_break_ticks(60)
	vic.mode = Fighter.Mode.HEADHELD; vic._grappled_by = atk
	for _i in range(80):
		atk._physics_process(1.0 / 60.0)
		vic._physics_process(1.0 / 60.0)
	assert_eq(atk.mode, Fighter.Mode.NORMAL, "holder released")
	assert_eq(vic.mode, Fighter.Mode.NORMAL, "victim released")
	assert_null(atk._grappling)
	assert_null(vic._grappled_by)
