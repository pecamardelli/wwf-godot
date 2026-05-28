extends "res://addons/gut/test.gd"

func test_encode_stick_is_facing_relative():
	# Facing right (+1): holding right = TOWARD + real RIGHT; holding left = AWAY + real LEFT.
	var right := MotionBuffer.encode_stick(Vector2.RIGHT, 1.0)
	assert_eq(right & MotionBuffer.J_TOWARD, MotionBuffer.J_TOWARD, "right while facing right = toward")
	assert_eq(right & MotionBuffer.J_RIGHT, MotionBuffer.J_RIGHT, "real screen-right bit set")
	assert_eq(right & MotionBuffer.J_AWAY, 0)
	var left := MotionBuffer.encode_stick(Vector2.LEFT, 1.0)
	assert_eq(left & MotionBuffer.J_AWAY, MotionBuffer.J_AWAY, "left while facing right = away")
	assert_eq(left & MotionBuffer.J_LEFT, MotionBuffer.J_LEFT, "real screen-left bit set")
	# Facing left (-1): holding left is now TOWARD.
	var left_facing_left := MotionBuffer.encode_stick(Vector2.LEFT, -1.0)
	assert_eq(left_facing_left & MotionBuffer.J_TOWARD, MotionBuffer.J_TOWARD, "left while facing left = toward")

func test_encode_stick_vertical():
	var down := MotionBuffer.encode_stick(Vector2.DOWN, 1.0)
	assert_eq(down & MotionBuffer.J_DOWN, MotionBuffer.J_DOWN)
	var up := MotionBuffer.encode_stick(Vector2.UP, 1.0)
	assert_eq(up & MotionBuffer.J_UP, MotionBuffer.J_UP)

func test_push_keeps_newest_at_front():
	var b := MotionBuffer.new()
	b.push(MotionBuffer.B_PUNCH, 10)
	b.push(MotionBuffer.B_KICK, 11)
	assert_eq(b.size(), 2)
	assert_eq(b.code_at(0), MotionBuffer.B_KICK, "newest at index 0")
	assert_eq(b.tick_at(0), 11)
	assert_eq(b.code_at(1), MotionBuffer.B_PUNCH)
	assert_eq(b.newest_tick(), 11)

func test_push_evicts_oldest_past_capacity():
	var b := MotionBuffer.new()
	for i in range(MotionBuffer.CAPACITY + 5):
		b.push(i, i)
	assert_eq(b.size(), MotionBuffer.CAPACITY, "ring capped at CAPACITY")
	assert_eq(b.code_at(0), MotionBuffer.CAPACITY + 4, "newest retained")
	assert_eq(b.tick_at(MotionBuffer.CAPACITY - 1), 5, "oldest retained = first not evicted")

func test_newest_tick_empty_is_negative():
	assert_eq(MotionBuffer.new().newest_tick(), -1)
