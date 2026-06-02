extends "res://addons/gut/test.gd"
## ANI_SOUND: a SequenceFrame can carry a SoundEntry that the player surfaces as a one-shot
## intent when the frame begins (read-and-clear, like the other consume_* intents).

func _frame(ticks: int, snd: SoundEntry = null) -> SequenceFrame:
	var f := SequenceFrame.new()
	f.duration_ticks = ticks
	f.sound = snd
	return f

func _seq(frames: Array) -> MoveSequence:
	var m := MoveSequence.new()
	var typed: Array[SequenceFrame] = []
	for f in frames:
		typed.append(f)
	m.frames = typed
	return m

func test_frame_sound_is_surfaced_then_cleared():
	var e := SoundEntry.new()
	var sp := SequencePlayer.new()
	sp.play(_seq([_frame(2, e), _frame(2, null)]))
	sp.advance(0.001)                       # begins frame 0 (has sound)
	var got := sp.consume_sounds()
	assert_eq(got, [e], "frame 0 sound surfaced")
	assert_eq(sp.consume_sounds(), [], "read-and-clear")

func test_frames_without_sound_surface_nothing():
	var sp := SequencePlayer.new()
	sp.play(_seq([_frame(2, null)]))
	sp.advance(0.001)
	assert_eq(sp.consume_sounds(), [])
