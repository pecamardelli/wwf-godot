extends "res://addons/gut/test.gd"
## The announcer plays a new line only when idle AND off cooldown, OR when a strictly
## higher-priority event preempts an in-progress line (preempt ignores cooldown).

func test_idle_and_off_cooldown_plays():
	assert_true(AnnouncerPolicy.should_play(0.0, false, -1, 1))

func test_idle_but_on_cooldown_drops():
	assert_false(AnnouncerPolicy.should_play(1.5, false, -1, 1))

func test_busy_equal_or_lower_drops():
	assert_false(AnnouncerPolicy.should_play(0.0, true, 2, 2), "equal while busy -> drop")
	assert_false(AnnouncerPolicy.should_play(0.0, true, 2, 1), "lower while busy -> drop")

func test_busy_higher_preempts_even_on_cooldown():
	assert_true(AnnouncerPolicy.should_play(3.0, true, 2, 3), "higher preempts despite cooldown")
