class_name MoveTable
extends Resource
## Maps range × relative-direction × button -> MoveSequence (arcade mode_table/action_table/JJXM).
## Stored as a flat dict keyed "range|dir|button". Lookup falls back dir-specific -> NEUTRAL.

# Range/Button enum names are avoided: they shadow native Godot classes (Range, Button)
# and fail to parse in Godot 4.x. Rng/Btn are the dispatch-key dimensions.
enum Rng { NORMAL, CLOSE, RUNNING }
enum Dir { NEUTRAL, TOWARD, AWAY, DOWN }
enum Btn { LOW_PUNCH, HIGH_PUNCH, LOW_KICK, HIGH_KICK }

@export var entries: Dictionary = {}   # "r|d|b" -> MoveSequence

static func key(rng: int, dir: int, btn: int) -> String:
	return "%d|%d|%d" % [rng, dir, btn]

func add(rng: int, dir: int, btn: int, seq: MoveSequence) -> void:
	entries[key(rng, dir, btn)] = seq

## Look up a move: try the dir-specific entry, then the NEUTRAL entry for that range/button.
func lookup(rng: int, dir: int, btn: int) -> MoveSequence:
	if entries.has(key(rng, dir, btn)):
		return entries[key(rng, dir, btn)]
	return entries.get(key(rng, Dir.NEUTRAL, btn), null)
