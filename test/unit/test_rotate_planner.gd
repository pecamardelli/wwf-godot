extends "res://addons/gut/test.gd"

func test_no_turn_when_same_state():
	assert_eq(RotatePlanner.plan(Facing.State.FR, Facing.State.FR), [])

func test_one_segment_forward():
	# FR -> BR uses the first forward segment
	assert_eq(RotatePlanner.plan(Facing.State.FR, Facing.State.BR), [2, 3, 4])
	# FL -> FR is the wrap segment
	assert_eq(RotatePlanner.plan(Facing.State.FL, Facing.State.FR), [11, 0, 1])

func test_one_segment_backward_is_reversed():
	# FR -> FL is shorter going backward (reverse the FL->FR segment)
	assert_eq(RotatePlanner.plan(Facing.State.FR, Facing.State.FL), [1, 0, 11])
	# BR -> FR backward reverses the FR->BR segment
	assert_eq(RotatePlanner.plan(Facing.State.BR, Facing.State.FR), [4, 3, 2])

func test_opposite_corner_takes_two_segments_forward_on_tie():
	# FR -> BL: forward and backward are both 2 segments -> tie picks forward
	assert_eq(RotatePlanner.plan(Facing.State.FR, Facing.State.BL), [2, 3, 4, 5, 6, 7])
	assert_eq(RotatePlanner.plan(Facing.State.BL, Facing.State.FR), [8, 9, 10, 11, 0, 1])
