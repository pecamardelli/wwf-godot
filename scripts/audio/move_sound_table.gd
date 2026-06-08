class_name MoveSoundTable
extends Resource
## move_id -> MoveSounds. resolve() returns null for an unmapped move (caller falls back to the
## legacy category-keyed SoundTable). `hit_ground` is a SHARED, move-independent pool: the body
## thud played whenever ANY fighter hits the floor (every throw landing and knockdown), so the
## impact set lives once here instead of duplicated per move.

@export var moves: Dictionary = {}             # move_id(String) -> MoveSounds
@export var hit_ground: SoundPool = null       # shared body-drop thud (any fighter hits the ground)

func resolve(move_id: String) -> MoveSounds:
	return moves.get(move_id, null)
