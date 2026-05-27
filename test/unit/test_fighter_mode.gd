extends "res://addons/gut/test.gd"

func test_input_allowed_only_in_normal_and_running():
	assert_true(Fighter.input_allowed(Fighter.Mode.NORMAL))
	assert_true(Fighter.input_allowed(Fighter.Mode.RUNNING))
	assert_false(Fighter.input_allowed(Fighter.Mode.DIZZY))
	assert_false(Fighter.input_allowed(Fighter.Mode.ONGROUND))
	assert_false(Fighter.input_allowed(Fighter.Mode.INAIR))
	assert_false(Fighter.input_allowed(Fighter.Mode.BLOCK))

func test_fighter_starts_in_normal():
	var f := Fighter.new()
	add_child_autofree(f)
	assert_eq(f.mode, Fighter.Mode.NORMAL)
