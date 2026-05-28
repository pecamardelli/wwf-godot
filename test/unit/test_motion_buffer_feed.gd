extends "res://addons/gut/test.gd"

# Drives Player.feed_input directly (no Input singleton) to prove edge-based filling.
func test_feed_pushes_stick_change_then_button_down():
	var p := Player.new()
	add_child_autofree(p)
	# Frame 1: hold AWAY (facing right => left stick). Stick change -> one entry.
	p.feed_input(Vector2.LEFT, 0, 1.0)
	assert_eq(p.motion_buffer.size(), 1)
	assert_eq(p.motion_buffer.code_at(0) & MotionBuffer.J_AWAY, MotionBuffer.J_AWAY)
	# Frame 2: same stick, no new button -> NO new entry (edges only).
	p.feed_input(Vector2.LEFT, 0, 1.0)
	assert_eq(p.motion_buffer.size(), 1, "held stick with no change pushes nothing")
	# Frame 3: press PUNCH while still holding AWAY -> button-down entry carries the stick.
	p.feed_input(Vector2.LEFT, MotionBuffer.B_PUNCH, 1.0)
	assert_eq(p.motion_buffer.size(), 2)
	var top: int = p.motion_buffer.code_at(0)
	assert_eq(top & MotionBuffer.B_PUNCH, MotionBuffer.B_PUNCH)
	assert_eq(top & MotionBuffer.J_AWAY, MotionBuffer.J_AWAY, "button entry ORs current stick")

func test_feed_advances_tick_and_feeds_charge():
	var p := Player.new()
	add_child_autofree(p)
	for i in range(3):
		p.feed_input(Vector2.ZERO, MotionBuffer.B_PUNCH, 1.0)   # hold PUNCH 3 frames
	assert_eq(p.charge.held_frames(MotionBuffer.B_PUNCH), 3)
	assert_gt(p._input_tick, 0, "tick advances each feed")
