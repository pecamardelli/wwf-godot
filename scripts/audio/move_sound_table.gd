class_name MoveSoundTable
extends Resource
## move_id -> MoveSounds. resolve() returns null for an unmapped move (caller falls back to the
## legacy category-keyed SoundTable).

@export var moves: Dictionary = {}             # move_id(String) -> MoveSounds

func resolve(move_id: String) -> MoveSounds:
	return moves.get(move_id, null)
