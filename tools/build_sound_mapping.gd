extends SceneTree
## Build assets/audio/move_sound_table.tres from tools/sound_mapping.json.
## Pass 1: fuzzy-resolve every referenced WAV against the source tree and COPY it into the project.
##   If anything was newly copied, exit 2 and ask for --import (Godot must import the new WAVs).
## Pass 2 (after --import): all WAVs importable -> build SoundPool/MoveSounds/MoveSoundTable + save.
## Run: godot --headless --path . -s tools/build_sound_mapping.gd  (then --import, then re-run)

const JSON_PATH := "res://tools/sound_mapping.json"
const SHARED_HIT_GROUND := "hit_ground"   # reserved top-level key: shared body-drop SFX (not a move)
const SRC_ROOT := "/media/pablin/DATOS/JUEGOS/Wrestlemania/WWF Sources/Sounds"
const OUT := "res://assets/audio/move_sound_table.tres"
const SFX_DIR := "res://assets/audio/sfx"          # swing + hit
const VOICE_DIR := "res://assets/audio/voice"      # voice/<wid>

func _init() -> void:
	var json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(JSON_PATH))
	if json == null:
		push_error("could not parse %s" % JSON_PATH); quit(1); return
	var index := _build_source_index(SRC_ROOT)
	var copied := 0
	var missing: Array[String] = []
	# Pass 1: resolve + copy every referenced file; collect dest res:// paths.
	var dest_of := {}   # original filename -> res:// dest path
	# Shared, move-independent SFX bucket (top-level array, NOT a move): the body-drop thud.
	for v in json.get(SHARED_HIT_GROUND, []):
		copied += _stage(v["file"], SFX_DIR, index, dest_of, missing)
	for move_id in json:
		if move_id == SHARED_HIT_GROUND:
			continue   # reserved shared bucket, handled above
		if json[move_id] is String:
			continue   # alias (move_id -> other move_id); resolved in pass 2, stages no files
		var buckets: Dictionary = json[move_id]
		for kind in ["swing", "hit"]:
			for v in buckets.get(kind, []):
				copied += _stage(v["file"], SFX_DIR, index, dest_of, missing)
		for kind in ["attack", "pain"]:
			var per_w: Dictionary = buckets.get(kind, {})
			for wid in per_w:
				for v in per_w[wid]:
					copied += _stage(v["file"], "%s/%s" % [VOICE_DIR, wid], index, dest_of, missing)
	if not missing.is_empty():
		push_error("Unresolved sound files:\n- " + "\n- ".join(missing)); quit(1); return
	# Any dest that isn't importable yet -> need --import before we can load AudioStreams.
	var not_ready: Array[String] = []
	for f in dest_of:
		if not ResourceLoader.exists(dest_of[f]):
			not_ready.append(dest_of[f])
	if not not_ready.is_empty():
		print("Copied %d new WAV(s). Run:  godot --headless --path . --import" % copied)
		print("then re-run this tool to build the table (%d file(s) await import)." % not_ready.size())
		quit(2); return
	# Pass 2: build the table.
	var t := MoveSoundTable.new()
	# Shared body-drop pool (optional: left null when absent -> play_body_drop falls back to BODY_DROP).
	var shared_hg: Array = json.get(SHARED_HIT_GROUND, [])
	if not shared_hg.is_empty():
		t.hit_ground = _sfx_pool(shared_hg, dest_of)
	print("shared hit_ground: %d" % (t.hit_ground.streams.size() if t.hit_ground != null else 0))
	for move_id in json:
		if move_id == SHARED_HIT_GROUND:
			continue
		if json[move_id] is String:
			continue   # alias; resolved after every real move is built (below)
		var buckets: Dictionary = json[move_id]
		var ms := MoveSounds.new()
		ms.swing = _sfx_pool(buckets.get("swing", []), dest_of)
		ms.hit = _sfx_pool(buckets.get("hit", []), dest_of)
		ms.attack = _voice_pools(buckets.get("attack", {}), dest_of)
		ms.pain = _voice_pools(buckets.get("pain", {}), dest_of)
		t.moves[move_id] = ms
		print("%s: swing %d, hit %d, attack %s, pain %s" % [move_id,
			ms.swing.streams.size(), ms.hit.streams.size(), ms.attack.keys(), ms.pain.keys()])
	# Aliases: point an alias move_id at the SAME MoveSounds as its target (no duplicated data).
	for move_id in json:
		if move_id == SHARED_HIT_GROUND or not (json[move_id] is String):
			continue
		var target: String = json[move_id]
		if not t.moves.has(target):
			push_error("alias %s -> unknown move %s" % [move_id, target]); quit(1); return
		t.moves[move_id] = t.moves[target]
		print("%s -> alias of %s" % [move_id, target])
	var uid_text := Uid.preserve_or_mint(OUT)
	var err := ResourceSaver.save(t, OUT)
	if err == OK:
		Uid.stamp(OUT, uid_text)
	print("move_sound_table -> ", error_string(err))
	quit(0 if err == OK else 1)

## Recursively index the source tree: normalized filename -> absolute path (first wins; warns on dup).
func _build_source_index(root: String) -> Dictionary:
	var index := {}
	var stack: Array[String] = [root]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		var d := DirAccess.open(dir)
		if d == null:
			continue
		d.list_dir_begin()
		var name := d.get_next()
		while name != "":
			var full := dir + "/" + name
			if d.current_is_dir():
				if name != "." and name != "..":
					stack.append(full)
			elif name.to_lower().ends_with(".wav"):
				var key := SoundFileResolver.normalize(name)
				if not index.has(key):
					index[key] = full
			name = d.get_next()
		d.list_dir_end()
	return index

## Resolve `file` to a source path, copy it into `dest_dir` (if not already there), record the
## dest res:// path in `dest_of`. Returns 1 if a new copy was made, else 0. Appends to `missing`.
func _stage(file: String, dest_dir: String, index: Dictionary, dest_of: Dictionary, missing: Array) -> int:
	if dest_of.has(file):
		return 0
	var src := SoundFileResolver.resolve(file, index)
	if src == "":
		missing.append(file)
		return 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest_dir))
	var dest_name := SoundFileResolver.normalize(file)
	var dest := "%s/%s" % [dest_dir, dest_name]
	dest_of[file] = dest
	var abs_dest := ProjectSettings.globalize_path(dest)
	if FileAccess.file_exists(abs_dest):
		return 0
	DirAccess.copy_absolute(src, abs_dest)
	return 1

func _pool_for(variants: Array, dest_of: Dictionary, chance_gated: bool, bus: StringName) -> SoundPool:
	var p := SoundPool.new()
	p.chance_gated = chance_gated
	p.bus = bus
	for v in variants:
		var dest: String = dest_of.get(v["file"], "")
		if dest == "" or not ResourceLoader.exists(dest):
			continue
		p.streams.append(load(dest))
		p.weights.append(float(v.get("precedence", v.get("probability", 0))))
	return p

func _sfx_pool(variants: Array, dest_of: Dictionary) -> SoundPool:
	return _pool_for(variants, dest_of, false, &"SFX")

func _voice_pools(per_w: Dictionary, dest_of: Dictionary) -> Dictionary:
	var out := {}
	for wid in per_w:
		out[StringName(wid)] = _pool_for(per_w[wid], dest_of, true, &"Voice")
	return out
