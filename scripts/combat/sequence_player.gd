class_name SequencePlayer
extends RefCounted
## Steps a MoveSequence over wall-clock time. Frame durations are arcade ticks,
## converted via ArcadeUnits.ticks_to_seconds (logic runs at 60 Hz, 1 frame != 1 tick).

var sequence: MoveSequence = null
var attack_live: bool = false
var active_attack_box: Box3 = null

var _index: int = -1
var _time_left: float = 0.0   # seconds remaining on the current frame

## Begin a sequence. play(null) clears/stops the player (used to cancel a move).
func play(seq: MoveSequence) -> void:
	sequence = seq
	_index = -1
	_time_left = 0.0
	attack_live = false
	active_attack_box = null

func is_playing() -> bool:
	return sequence != null

## Advance by `delta` seconds. Returns true on the step that finishes the sequence.
func advance(delta: float) -> bool:
	if sequence == null:
		return false
	_time_left -= delta
	# Enter the first frame, or any frames whose time elapsed this step.
	while _time_left <= 0.0:
		_index += 1
		if _index >= sequence.frames.size():
			_finish()
			return true
		var f: SequenceFrame = sequence.frames[_index]
		_apply_command(f)
		_time_left += ArcadeUnits.ticks_to_seconds(f.duration_ticks)
	return false

func current_frame() -> SequenceFrame:
	if sequence == null or _index < 0 or _index >= sequence.frames.size():
		return null
	return sequence.frames[_index]

func _apply_command(f: SequenceFrame) -> void:
	match f.command:
		SequenceFrame.Command.ATTACK_ON:
			attack_live = true
			active_attack_box = f.attack_box
		SequenceFrame.Command.ATTACK_OFF:
			attack_live = false
			active_attack_box = null
		_:
			# NONE and STARTATTACK are no-ops here: STARTATTACK is the arcade's
			# declarative startup marker (ANI_STARTATTACK); the hitbox opens on ATTACK_ON.
			pass

func _finish() -> void:
	sequence = null
	attack_live = false
	active_attack_box = null
	_index = -1
