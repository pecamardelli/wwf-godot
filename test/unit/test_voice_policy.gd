extends "res://addons/gut/test.gd"
## One voice per fighter: the newest line ALWAYS takes the channel, cancelling whatever is
## currently playing — pain grunts retrigger on every hit, no priority gating.

func test_idle_channel_always_plays():
	assert_true(VoicePolicy.should_interrupt(5, 0, false))
	assert_true(VoicePolicy.should_interrupt(99, 1, false))

func test_busy_channel_is_always_interrupted():
	assert_true(VoicePolicy.should_interrupt(3, 3, true))    # equal -> interrupt
	assert_true(VoicePolicy.should_interrupt(3, 4, true))    # higher -> interrupt
	assert_true(VoicePolicy.should_interrupt(3, 2, true))    # lower -> STILL interrupt (newest wins)
