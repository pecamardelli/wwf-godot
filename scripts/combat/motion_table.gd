class_name MotionTable
extends Resource
## Ordered registry of special-move input patterns -> grapple MoveSequence (arcade
## doink_secret_moves table, DOINK.ASM:214). Scanned in authoring order; the FIRST
## MotionMove whose pattern matches the buffer wins (specials are checked before normals).

## Parallel arrays so the resource serializes cleanly. _moves[i] maps to _sequences[i].
@export var _moves: Array[MotionMove] = []
@export var _sequences: Array[MoveSequence] = []

func add(move: MotionMove, seq: MoveSequence) -> void:
	_moves.append(move)
	_sequences.append(seq)

## All moves in scan (authoring) order.
func moves() -> Array[MotionMove]:
	return _moves

## The MoveSequence mapped to the move with this id, or null.
func lookup(move_id: String) -> MoveSequence:
	for i in range(_moves.size()):
		if _moves[i].move_id == move_id:
			return _sequences[i]
	return null
