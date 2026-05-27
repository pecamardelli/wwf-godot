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

func test_knockback_pushes_victim_away_from_attacker():
	var attacker := _fighter_at(100)   # attacker on the LEFT
	var victim := _fighter_at(140)     # victim on the RIGHT (separation disabled in _fighter_at)
	var resolver := AttackResolver.new()
	add_child_autofree(resolver)
	attacker.start_move(_punch())
	for _i in range(20):
		attacker._physics_process(FRAME)
		victim._physics_process(FRAME)
		resolver.resolve_tick()
	assert_gt(victim.global_position.x, 140.0, "victim knocked to the RIGHT, away from the left-side attacker")

func test_second_hit_within_repeat_window_uses_two_thirds_column():
	var attacker := _fighter_at(100)
	var victim := _fighter_at(140)
	var resolver := AttackResolver.new()
	add_child_autofree(resolver)
	attacker.start_move(_punch())                 # first hit: full punch = 10
	for _i in range(20):
		attacker._physics_process(FRAME)
		victim._physics_process(FRAME)
		resolver.resolve_tick()
	attacker.start_move(_punch())                 # second hit, well within ~0.94s window
	for _i in range(20):
		attacker._physics_process(FRAME)
		victim._physics_process(FRAME)
		resolver.resolve_tick()
	# repeat column: RD_PUNCH=floor(8*2/3)=5 -> 5*345/256 = 6. 163 - 10 - 6 = 147.
	assert_eq(victim.health, 147, "second hit within the window uses the 2/3 repeat damage")

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

func test_starting_a_move_faces_the_nearest_opponent():
	var attacker := _fighter_at(140)   # attacker to the RIGHT of the victim
	var victim := _fighter_at(100)
	attacker.start_move(_punch())
	assert_eq(attacker.facing(), -1.0, "turns to face the opponent on its left")

func test_punch_auto_faces_then_hits_opponent_on_the_left():
	var attacker := _fighter_at(140)
	var victim := _fighter_at(100)
	var resolver := AttackResolver.new()
	add_child_autofree(resolver)
	attacker.start_move(_punch())
	for _i in range(20):
		attacker._physics_process(FRAME)
		victim._physics_process(FRAME)
		resolver.resolve_tick()
	assert_lt(victim.health, Damage.LIFE_MAX, "auto-facing makes the box project left and connect")
