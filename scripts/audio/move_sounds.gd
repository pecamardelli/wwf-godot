class_name MoveSounds
extends Resource
## The four sound buckets for one move (arcade whsh/grunt/smak/ouch). swing/hit are universal;
## attack/pain are keyed by the performing wrestler id.

@export var swing: SoundPool = null            # whoosh at the windup (SFX)
@export var hit: SoundPool = null              # impact at contact (SFX)
@export var attack: Dictionary = {}            # wrestler_id(StringName) -> SoundPool (effort, Voice)
@export var pain: Dictionary = {}              # wrestler_id(StringName) -> SoundPool (pain, Voice)
