extends "res://addons/gut/test.gd"
## One voice per fighter: a new line plays if the channel is idle, or if it ranks >= the current
## line; a lower-priority line while busy is dropped. Mirrors the arcade per-channel sndpri.

func test_idle_channel_always_plays():
	assert_true(VoicePolicy.should_interrupt(5, 0, false))   # not busy -> play even if lower pri
	assert_true(VoicePolicy.should_interrupt(99, 1, false))

func test_busy_plays_only_when_ge():
	assert_true(VoicePolicy.should_interrupt(3, 3, true))    # equal -> interrupt (newest wins on tie)
	assert_true(VoicePolicy.should_interrupt(3, 4, true))    # higher -> interrupt
	assert_false(VoicePolicy.should_interrupt(3, 2, true))   # lower -> drop
