class_name MoveSounds
extends Resource
## The sound buckets for one move (arcade whsh/grunt/smak/ouch). swing/hit are the move's own
## SFX; attack is keyed by the ATTACKER's wrestler id (its effort grunt); pain is keyed by the
## VICTIM's wrestler id (its own pain grunt). The body-drop thud is NOT here — it's a shared,
## move-independent pool on MoveSoundTable.hit_ground.

@export var swing: SoundPool = null            # whoosh at the windup (SFX)
@export var hit: SoundPool = null              # impact at contact (SFX)
@export var attack: Dictionary = {}            # attacker_id(StringName) -> SoundPool (effort, Voice)
@export var pain: Dictionary = {}              # victim_id(StringName) -> SoundPool (pain, Voice)
