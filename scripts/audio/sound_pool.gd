class_name SoundPool
extends Resource
## A pool of interchangeable sound variants with per-variant weights and a selection rule.
## chance_gated=false (swing/hit): weights are `precedence`; one variant always plays, picked
## weighted. chance_gated=true (attack/pain): weights are `probability`; their sum is the chance
## ANY variant plays, the remainder is silence (index -1).

@export var streams: Array[AudioStream] = []   # variant WAVs (parallel to weights)
@export var weights: Array[float] = []         # precedence (weighted) or probability (chance)
@export var chance_gated: bool = false
@export var bus: StringName = &"SFX"           # &"SFX" (swing/hit) or &"Voice" (attack/pain)
@export var volume_db: float = 0.0
@export var pitch_jitter: float = 0.0
@export var priority: int = 0                  # voice-channel interrupt priority

## Walk the cumulative weights and return the index whose band contains `roll`. For weighted,
## `roll` is in [0, total) so it always lands on a variant. For chance, `roll` is in [0, 1) and a
## roll past the summed probabilities falls through to -1 (silence).
static func pick_from_roll(weights: Array, roll: float, _chance_gated: bool) -> int:
	var cum := 0.0
	for i in weights.size():
		cum += weights[i]
		if roll < cum:
			return i
	return -1

## Roll the rng and pick. Weighted: roll in [0,total), never silent. Chance: roll in [0,1),
## silent when the roll exceeds the summed probabilities. Empty/zero-total -> silent.
static func pick_index(weights: Array, rng: RandomNumberGenerator, chance_gated: bool) -> int:
	var total := 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		return -1
	var roll := rng.randf() if chance_gated else rng.randf() * total
	return pick_from_roll(weights, roll, chance_gated)

## The chosen variant, or null on silence / out-of-range.
func pick_stream(rng: RandomNumberGenerator) -> AudioStream:
	var i := pick_index(weights, rng, chance_gated)
	if i < 0 or i >= streams.size():
		return null
	return streams[i]
