extends "res://addons/gut/test.gd"

const FRAME := 1.0 / 60.0

func _fighter_at(x: float) -> Fighter:
	var f := Fighter.new()
	add_child_autofree(f)
	f.global_position = Vector2(x, 400)
	f.separation_radii = Vector2.ZERO   # isolate hit detection from the soft-separation drift
	return f

func _punch() -> MoveSequence:
	return load("res://assets/sequences/doink/punch.tres")

func test_fighter_starts_at_full_health():
	assert_eq(_fighter_at(0).health, Damage.LIFE_MAX)

func test_starting_a_move_marks_attacking():
	var f := _fighter_at(0)
	f.start_move(_punch())
	assert_true(f.is_attacking())

func test_punch_in_range_damages_victim():
	var attacker := _fighter_at(100)
	var victim := _fighter_at(140)
	var resolver := AttackResolver.new()
	add_child_autofree(resolver)
	attacker.start_move(_punch())
	for _i in range(20):
		attacker._physics_process(FRAME)
		victim._physics_process(FRAME)
		resolver.resolve_tick()
	assert_lt(victim.health, Damage.LIFE_MAX, "victim took damage")

func test_punch_out_of_range_does_nothing():
	var attacker := _fighter_at(100)
	var victim := _fighter_at(400)
	var resolver := AttackResolver.new()
	add_child_autofree(resolver)
	attacker.start_move(_punch())
	for _i in range(20):
		attacker._physics_process(FRAME)
		victim._physics_process(FRAME)
		resolver.resolve_tick()
	assert_eq(victim.health, Damage.LIFE_MAX, "no hit out of range")

func test_a_single_swing_hits_only_once():
	var attacker := _fighter_at(100)
	var victim := _fighter_at(140)
	var resolver := AttackResolver.new()
	add_child_autofree(resolver)
	attacker.start_move(_punch())
	for _i in range(30):
		attacker._physics_process(FRAME)
		victim._physics_process(FRAME)
		resolver.resolve_tick()
	assert_eq(victim.health, Damage.LIFE_MAX - 10, "one hit per swing, punch=10 after offense mod")

func test_knockdown_puts_victim_onground():
	var attacker := _fighter_at(100)
	var victim := _fighter_at(140)
	var resolver := AttackResolver.new()
	add_child_autofree(resolver)
	attacker.start_move(load("res://assets/sequences/doink/big_boot.tres"))
	for _i in range(30):
		attacker._physics_process(FRAME)
		victim._physics_process(FRAME)
		resolver.resolve_tick()
	assert_eq(victim.mode, Fighter.Mode.ONGROUND, "knocked down")
