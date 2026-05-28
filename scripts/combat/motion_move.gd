class_name MotionMove
extends Resource
## One special-move input pattern (arcade {value,mask} list, RESEARCH §A.3-A.4).
## Steps are ordered NEWEST-FIRST: values[0]/masks[0] is the trigger (most recent input),
## later indices are progressively older. A buffer entry matches step k when
## (entry.code & masks[k]) == values[k]. The whole motion must complete within
## max_ticks ARCADE ticks (converted to frames at match time).

@export var move_id: String = ""
@export var values: PackedInt32Array = PackedInt32Array()
@export var masks: PackedInt32Array = PackedInt32Array()
@export var max_ticks: int = 32

func step_count() -> int:
	return values.size()
