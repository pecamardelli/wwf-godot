extends "res://addons/gut/test.gd"

func test_defaults_to_idle_no_movement():
	var i := AIIntent.new()
	assert_eq(i.action, AIIntent.Action.IDLE)
	assert_eq(i.move_dir, Vector2.ZERO)
	assert_eq(i.button, -1)
	assert_eq(i.move_id, "")
	assert_false(i.want_run)

func test_fields_are_assignable():
	var i := AIIntent.new()
	i.action = AIIntent.Action.STRIKE
	i.button = MoveTable.Btn.LOW_KICK
	i.move_dir = Vector2(1, 0)
	i.want_run = true
	assert_eq(i.action, AIIntent.Action.STRIKE)
	assert_eq(i.button, MoveTable.Btn.LOW_KICK)
