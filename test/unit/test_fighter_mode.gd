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

## A fighter that always "holds right", to prove input gating end-to-end.
class _StubFighter extends Fighter:
	func get_input_direction() -> Vector2:
		return Vector2.RIGHT

func test_input_gating_zeroes_velocity_in_helpless_mode():
	var f := _StubFighter.new()
	add_child_autofree(f)
	f.mode = Fighter.Mode.NORMAL
	f._physics_process(1.0 / 60.0)
	assert_gt(f.velocity.length(), 0.0, "moves when input is allowed (NORMAL)")
	f.mode = Fighter.Mode.DIZZY
	f._physics_process(1.0 / 60.0)
	assert_eq(f.velocity, Vector2.ZERO, "no movement while helpless (DIZZY)")
