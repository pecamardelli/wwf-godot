class_name SoundEntry
extends Resource
## One category's playable sound: a pool of interchangeable variants (random-picked, like the
## arcade's per-move sound slots) plus playback params. Maps to one arcade sound id/slot.

@export var streams: Array[AudioStream] = []   # variants; one is picked at random per play
@export var priority: int = 0                  # higher interrupts lower on a fighter's voice channel
@export var bus: StringName = &"SFX"           # &"SFX" or &"Voice"
@export var volume_db: float = 0.0
@export var pitch_jitter: float = 0.0          # +/- random pitch spread (0 = none)
