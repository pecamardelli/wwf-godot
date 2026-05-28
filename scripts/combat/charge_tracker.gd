class_name ChargeTracker
extends RefCounted
## Tracks how long each button has been held; on release exposes the held duration
## for charge moves (arcade dtime counters + #charge_buzz release edge, RESEARCH §A.5).

var _held: Dictionary = {}             # button bit -> frames currently held
var _released_frames: Dictionary = {}  # button bit -> frames held at the release THIS update

## Call once per logic frame with the mask of currently-held buttons.
func update(held_mask: int) -> void:
	for bit in [MotionBuffer.B_PUNCH, MotionBuffer.B_BLOCK, MotionBuffer.B_SPUNCH,
			MotionBuffer.B_KICK, MotionBuffer.B_SKICK]:
		var was := int(_held.get(bit, 0))
		if (held_mask & bit) != 0:
			_held[bit] = was + 1
			_released_frames[bit] = 0
		else:
			_released_frames[bit] = was   # >0 only on the frame of release
			_held[bit] = 0

func held_frames(bit: int) -> int:
	return int(_held.get(bit, 0))

## Frames the button had been held at the moment it was released this frame (0 otherwise).
func just_released(bit: int) -> int:
	return int(_released_frames.get(bit, 0))

## True the frame `bit` is released after being held >= `min_arcade_ticks`.
func released_after(bit: int, min_arcade_ticks: int) -> bool:
	return just_released(bit) >= ArcadeUnits.ticks_to_frames(min_arcade_ticks)
