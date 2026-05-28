extends "res://addons/gut/test.gd"

func test_counts_held_frames_and_reports_on_release():
	var c := ChargeTracker.new()
	var bit := MotionBuffer.B_PUNCH
	for i in range(5):
		c.update(bit)                      # PUNCH held this frame
		assert_eq(c.just_released(bit), 0, "not released while held")
	assert_eq(c.held_frames(bit), 5)
	c.update(0)                            # released
	assert_eq(c.just_released(bit), 5, "release reports frames held")
	c.update(0)
	assert_eq(c.just_released(bit), 0, "release is a one-frame edge")
	assert_eq(c.held_frames(bit), 0, "counter reset after release")

func test_charge_threshold_helper():
	var c := ChargeTracker.new()
	var bit := MotionBuffer.B_PUNCH
	var frames := ArcadeUnits.ticks_to_frames(100)   # joybuzzer threshold
	for i in range(frames):
		c.update(bit)
	c.update(0)
	assert_true(c.released_after(bit, 100), "held >= 100 arcade ticks then released")

func test_short_press_does_not_charge():
	var c := ChargeTracker.new()
	var bit := MotionBuffer.B_PUNCH
	c.update(bit)
	c.update(0)
	assert_false(c.released_after(bit, 100))
