extends "res://addons/gut/test.gd"
## Full path: buffered hip-toss motion -> Player.scan_specials fires the grapple ->
## AttackResolver connects the grab -> puppet playback -> DAMAGE_OPP -> DETACH knockdown.

var resolver: AttackResolver

func before_each():
	resolver = AttackResolver.new()
	add_child_autofree(resolver)

func _player(pos: Vector2, side: int) -> Player:
	var p := Player.new(); p.side = side
	p.motions = load("res://assets/motions/doink_motions.tres")
	add_child_autofree(p); p.global_position = pos
	return p

func test_hip_toss_full_flow():
	var atk := _player(Vector2(100, 400), Fighter.Side.PLAYER)
	atk._set_facing(1.0)
	var vic := _player(Vector2(150, 400), Fighter.Side.ENEMY)
	var before := vic.health
	# Buffer the hip-toss motion: away, away, PUNCH (held away), all "now".
	atk.motion_buffer.push(MotionBuffer.J_AWAY | MotionBuffer.J_LEFT, 1)
	atk.motion_buffer.push(MotionBuffer.J_AWAY | MotionBuffer.J_LEFT, 2)
	atk.motion_buffer.push(MotionBuffer.B_PUNCH | MotionBuffer.J_AWAY | MotionBuffer.J_LEFT, 3)
	atk._input_tick = 3
	assert_true(atk.scan_specials(), "hip toss fired")
	assert_eq(atk.mode, Fighter.Mode.NORMAL, "not yet GRABBING until the box connects")
	# Drive the sim through the full throw (~36-tick throw + contact freeze at 4 ticks/frame).
	for _i in range(70):
		atk._physics_process(1.0 / 60.0)
		resolver.resolve_tick()
		vic._physics_process(1.0 / 60.0)
	assert_lt(vic.health, before, "victim took puppet damage")
	assert_eq(vic.mode, Fighter.Mode.ONGROUND, "victim knocked down after detach")
	assert_eq(atk.mode, Fighter.Mode.NORMAL, "attacker returns to NORMAL (not stuck in GRABBING)")

func test_hip_toss_lifts_the_victim():
	var atk := _player(Vector2(100, 400), Fighter.Side.PLAYER); atk._set_facing(1.0)
	var vic := _player(Vector2(150, 400), Fighter.Side.ENEMY)
	atk.motion_buffer.push(MotionBuffer.J_AWAY | MotionBuffer.J_LEFT, 1)
	atk.motion_buffer.push(MotionBuffer.J_AWAY | MotionBuffer.J_LEFT, 2)
	atk.motion_buffer.push(MotionBuffer.B_PUNCH | MotionBuffer.J_AWAY | MotionBuffer.J_LEFT, 3)
	atk._input_tick = 3
	atk.scan_specials()
	var max_lift := 0.0
	for _i in range(70):
		atk._physics_process(1.0 / 60.0); resolver.resolve_tick(); vic._physics_process(1.0 / 60.0)
		max_lift = maxf(max_lift, atk.global_position.y - vic.global_position.y)
	# Proves the victim is driven UP off the ground (atk.y - off.y) during the throw —
	# the lift scales with _GRAB_OFFSET_SCALE_Y, applied when the .tres is regenerated.
	assert_gt(max_lift, 40.0, "victim is lifted well off the ground during the toss")
