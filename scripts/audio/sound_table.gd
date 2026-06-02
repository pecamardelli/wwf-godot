class_name SoundTable
extends Resource
## Arcade DEFAULT_SOUND_TABLE + MASTER_SOUND_TABLE[wrestler]. Maps a category (an AMode move
## value for impacts, or a SoundCategory.* voice/event value) to a SoundEntry. `resolve` applies
## the WRSND fallback: wrestler override first, then default, then null.

## category(int) -> SoundEntry
@export var default: Dictionary = {}
## wrestler_id(StringName) -> { category(int) -> SoundEntry }
@export var per_wrestler: Dictionary = {}

func resolve(wrestler_id: StringName, category: int) -> SoundEntry:
	if per_wrestler.has(wrestler_id):
		var slots: Dictionary = per_wrestler[wrestler_id]
		if slots.has(category):
			return slots[category]
	return default.get(category, null)
