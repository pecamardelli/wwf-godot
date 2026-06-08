extends "res://addons/gut/test.gd"

func test_starts_inactive():
	var b := BurstState.new()
	assert_false(b.is_active())
	assert_eq(b.count, 0)

func test_start_sets_count_one():
	var b := BurstState.new()
	b.start()
	assert_true(b.is_active())
	assert_eq(b.count, 1)
	assert_false(b.continue_pressed)

func test_note_continue_enables_chain():
	var b := BurstState.new()
	b.start()
	assert_false(b.can_chain())
	b.note_continue()
	assert_true(b.can_chain())

func test_advance_increments_and_clears_continue():
	var b := BurstState.new()
	b.start()
	b.note_continue()
	b.advance()
	assert_eq(b.count, 2)
	assert_false(b.continue_pressed)
	assert_false(b.can_chain())

func test_caps_at_four():
	var b := BurstState.new()
	b.start()
	for i in range(3):
		b.note_continue()
		assert_true(b.can_chain())
		b.advance()
	assert_eq(b.count, 4)
	b.note_continue()                 # cannot buffer past the cap
	assert_false(b.continue_pressed)
	assert_false(b.can_chain())

func test_reset_clears():
	var b := BurstState.new()
	b.start()
	b.note_continue()
	b.advance()
	b.reset()
	assert_false(b.is_active())
	assert_eq(b.count, 0)
	assert_false(b.continue_pressed)
