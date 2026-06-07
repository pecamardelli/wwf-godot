# Per-Move Sound Mapping Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A per-move, JSON-driven combat-sound model with four buckets (swing/hit/attack/pain), weighted variant selection, and probabilistic (sometimes-silent) voices — running alongside the current sound table, taking over only for mapped moves.

**Architecture:** New isolated resources (`SoundPool` with a pure weighted/chance selector, `MoveSounds`, `MoveSoundTable`) generated from `sound_mapping.json` by a build tool that fuzzy-resolves filenames. The `Sound` autoload gains `play_move_swing`/`play_move_hit`; `Fighter` calls them for mapped moves (suppressing the legacy impact/pain path) and keeps today's behavior for everything else.

**Tech Stack:** Godot 4.6 / GDScript, GUT tests (`test/unit/`).

**Conventions (from CLAUDE.md):**
- Run all tests: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit`
- Run ONE file: append `-gtest=res://test/unit/<file>.gd` (note: gutconfig dirs still run the whole suite; the full run is the source of truth).
- New `class_name` → rebuild the cache: `godot --headless --path . --import` before the runner sees it.
- `godot` on PATH. Commit trailers: NO `Co-Authored-By` / "Generated with Claude Code".

---

## File Structure

**Create:**
- `scripts/audio/sound_pool.gd` — `SoundPool` resource + pure `pick_index`/`pick_from_roll` selectors + `pick_stream`.
- `scripts/audio/move_sounds.gd` — `MoveSounds` resource (4 buckets).
- `scripts/audio/move_sound_table.gd` — `MoveSoundTable` resource (move_id → MoveSounds) + `resolve`.
- `scripts/audio/sound_file_resolver.gd` — `SoundFileResolver` pure normalize/resolve for the build tool.
- `tools/build_sound_mapping.gd` — reads `tools/sound_mapping.json`, fuzzy-imports WAVs, builds `move_sound_table.tres`.
- `tools/sound_mapping.json` — the JSON moved into the repo (version-controlled).
- `assets/audio/move_sound_table.tres` — generated.
- Tests: `test_sound_pool.gd`, `test_move_sound_table.gd`, `test_sound_file_resolver.gd`, `test_move_sound_firing.gd`, `test_sound_mapping_integration.gd`.

**Modify:**
- `scripts/audio/sound_manager.gd` — load `move_table`; `has_move_sounds`, `play_move_swing`, `play_move_hit`, pool play helpers.
- `scripts/fighter.gd` — fire swing+effort at `start_move` and hit+pain in `receive_hit` for mapped moves; suppress legacy for those.

---

## Task 1: SoundPool resource + weighted/chance selector

**Files:**
- Create: `scripts/audio/sound_pool.gd`
- Test: `test/unit/test_sound_pool.gd`

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_sound_pool.gd`:

```gdscript
extends "res://addons/gut/test.gd"
## SoundPool selection: weighted-always-pick (swing/hit) and chance-with-silence (attack/pain).

# --- pick_from_roll: deterministic boundary math (roll is pre-normalized) ---
func test_weighted_pick_from_roll_walks_cumulative():
	var w := [50.0, 50.0, 30.0]   # total 130
	assert_eq(SoundPool.pick_from_roll(w, 0.0, false), 0)
	assert_eq(SoundPool.pick_from_roll(w, 49.9, false), 0)
	assert_eq(SoundPool.pick_from_roll(w, 50.0, false), 1)
	assert_eq(SoundPool.pick_from_roll(w, 100.0, false), 2)
	assert_eq(SoundPool.pick_from_roll(w, 129.9, false), 2)

func test_chance_pick_from_roll_has_a_silence_band():
	var w := [0.2, 0.2]   # sum 0.4 -> 60% silence
	assert_eq(SoundPool.pick_from_roll(w, 0.0, true), 0)
	assert_eq(SoundPool.pick_from_roll(w, 0.19, true), 0)
	assert_eq(SoundPool.pick_from_roll(w, 0.2, true), 1)
	assert_eq(SoundPool.pick_from_roll(w, 0.39, true), 1)
	assert_eq(SoundPool.pick_from_roll(w, 0.4, true), -1)   # silence
	assert_eq(SoundPool.pick_from_roll(w, 0.99, true), -1)

# --- pick_index: rolls through the rng ---
func test_weighted_index_never_silent():
	var w := [0.0, 1.0]   # zero-weight entry is never picked
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	for _i in range(50):
		assert_eq(SoundPool.pick_index(w, rng, false), 1)

func test_chance_index_is_sometimes_silent():
	var w := [0.5]   # ~50% silence
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var silent := 0
	for _i in range(400):
		if SoundPool.pick_index(w, rng, true) == -1:
			silent += 1
	assert_between(silent, 120, 280, "roughly half are silent over 400 draws")

func test_zero_total_is_silent():
	assert_eq(SoundPool.pick_index([0.0, 0.0], RandomNumberGenerator.new(), false), -1)

# --- pick_stream wires the index to the streams array ---
func test_pick_stream_returns_null_on_silence():
	var p := SoundPool.new()
	p.streams = [AudioStreamWAV.new()]
	p.weights = [0.0]; p.chance_gated = true
	assert_null(p.pick_stream(RandomNumberGenerator.new()), "sum 0 -> silence -> null")

func test_pick_stream_returns_the_chosen_variant():
	var p := SoundPool.new()
	var a := AudioStreamWAV.new(); var b := AudioStreamWAV.new()
	p.streams = [a, b]; p.weights = [0.0, 1.0]; p.chance_gated = false
	assert_eq(p.pick_stream(RandomNumberGenerator.new()), b)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_sound_pool.gd -gexit`
Expected: FAIL (`SoundPool` not found).

- [ ] **Step 3: Create the resource + selector**

Create `scripts/audio/sound_pool.gd`:

```gdscript
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . --import` then
`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_sound_pool.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/audio/sound_pool.gd scripts/audio/sound_pool.gd.uid test/unit/test_sound_pool.gd test/unit/test_sound_pool.gd.uid
git commit -m "feat(sound): SoundPool — weighted/chance variant selection"
```

---

## Task 2: MoveSounds + MoveSoundTable resources

**Files:**
- Create: `scripts/audio/move_sounds.gd`, `scripts/audio/move_sound_table.gd`
- Test: `test/unit/test_move_sound_table.gd`

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_move_sound_table.gd`:

```gdscript
extends "res://addons/gut/test.gd"
## MoveSoundTable maps a move id to its four buckets; unmapped ids resolve to null.

func _pool() -> SoundPool:
	var p := SoundPool.new(); p.streams = [AudioStreamWAV.new()]; p.weights = [1.0]; return p

func test_resolve_returns_mapped_move():
	var ms := MoveSounds.new()
	ms.swing = _pool(); ms.hit = _pool()
	ms.attack = {&"doink": _pool()}; ms.pain = {&"doink": _pool()}
	var t := MoveSoundTable.new(); t.moves = {"punch": ms}
	var got := t.resolve("punch")
	assert_not_null(got)
	assert_not_null(got.swing); assert_not_null(got.hit)
	assert_true(got.attack.has(&"doink")); assert_true(got.pain.has(&"doink"))

func test_resolve_unmapped_is_null():
	var t := MoveSoundTable.new(); t.moves = {}
	assert_null(t.resolve("knee"), "unmapped move -> null (legacy path)")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_move_sound_table.gd -gexit`
Expected: FAIL (`MoveSounds`/`MoveSoundTable` not found).

- [ ] **Step 3: Create the resources**

Create `scripts/audio/move_sounds.gd`:

```gdscript
class_name MoveSounds
extends Resource
## The four sound buckets for one move (arcade whsh/grunt/smak/ouch). swing/hit are universal;
## attack/pain are keyed by the performing wrestler id.

@export var swing: SoundPool = null            # whoosh at the windup (SFX)
@export var hit: SoundPool = null              # impact at contact (SFX)
@export var attack: Dictionary = {}            # wrestler_id(StringName) -> SoundPool (effort, Voice)
@export var pain: Dictionary = {}              # wrestler_id(StringName) -> SoundPool (pain, Voice)
```

Create `scripts/audio/move_sound_table.gd`:

```gdscript
class_name MoveSoundTable
extends Resource
## move_id -> MoveSounds. resolve() returns null for an unmapped move (caller falls back to the
## legacy category-keyed SoundTable).

@export var moves: Dictionary = {}             # move_id(String) -> MoveSounds

func resolve(move_id: String) -> MoveSounds:
	return moves.get(move_id, null)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . --import` then
`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_move_sound_table.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/audio/move_sounds.gd scripts/audio/move_sounds.gd.uid \
	scripts/audio/move_sound_table.gd scripts/audio/move_sound_table.gd.uid \
	test/unit/test_move_sound_table.gd test/unit/test_move_sound_table.gd.uid
git commit -m "feat(sound): MoveSounds + MoveSoundTable resources"
```

---

## Task 3: Sound autoload — play_move_swing / play_move_hit

**Files:**
- Modify: `scripts/audio/sound_manager.gd`
- Test: `test/unit/test_move_sound_firing.gd`

The autoload loads a `MoveSoundTable` and plays its pools through the existing SFX pool / Voice channels. Pools differ from `SoundEntry`, so add pool-aware play helpers.

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_move_sound_firing.gd`:

```gdscript
extends "res://addons/gut/test.gd"
## Sound.play_move_swing/hit pick from the move's pools and route swing/hit -> SFX, attack/pain ->
## the fighter's Voice channel. Asserted through the existing mute-time seams.

func _sfx_pool() -> SoundPool:
	var p := SoundPool.new(); p.streams = [AudioStreamWAV.new()]; p.weights = [1.0]
	p.chance_gated = false; p.bus = &"SFX"; return p

func _voice_pool() -> SoundPool:
	var p := SoundPool.new(); p.streams = [AudioStreamWAV.new()]; p.weights = [1.0]
	p.chance_gated = true; p.bus = &"Voice"; return p

func _silent_voice_pool() -> SoundPool:
	var p := SoundPool.new(); p.streams = [AudioStreamWAV.new()]; p.weights = [0.0]
	p.chance_gated = true; p.bus = &"Voice"; return p

func _table(attack_pool: SoundPool, pain_pool: SoundPool) -> MoveSoundTable:
	var ms := MoveSounds.new()
	ms.swing = _sfx_pool(); ms.hit = _sfx_pool()
	ms.attack = {&"doink": attack_pool}; ms.pain = {&"doink": pain_pool}
	var t := MoveSoundTable.new(); t.moves = {"punch": ms}; return t

func _move() -> MoveSequence:
	var m := MoveSequence.new(); m.id = "punch"; return m

func before_each():
	Sound.last_sfx = {}; Sound.last_voice = {}
	Sound.move_table = _table(_voice_pool(), _voice_pool())

func after_all():
	Sound.move_table = null

func test_has_move_sounds():
	assert_true(Sound.has_move_sounds("punch"))
	assert_false(Sound.has_move_sounds("knee"))

func test_swing_plays_sfx_and_effort_voice():
	var atk := Fighter.new(); add_child_autofree(atk)
	atk.wrestler_id = &"doink"; atk.global_position = Vector2(300, 410)
	Sound.play_move_swing(atk, _move())
	assert_eq(Sound.last_sfx.get("position"), Vector2(300, 410), "swing SFX at the attacker")
	assert_eq(Sound.last_voice.get("fighter"), atk, "effort grunt on the attacker's channel")

func test_hit_plays_sfx_at_victim_and_pain_on_victim():
	var atk := Fighter.new(); add_child_autofree(atk); atk.wrestler_id = &"doink"
	var vic := Fighter.new(); add_child_autofree(vic); vic.global_position = Vector2(640, 500)
	Sound.play_move_hit(atk, vic, _move())
	assert_eq(Sound.last_sfx.get("position"), Vector2(640, 500), "hit SFX at the victim")
	assert_eq(Sound.last_voice.get("fighter"), vic, "pain on the victim's channel")

func test_silent_voice_pool_plays_no_voice():
	Sound.move_table = _table(_silent_voice_pool(), _silent_voice_pool())
	var atk := Fighter.new(); add_child_autofree(atk); atk.wrestler_id = &"doink"
	Sound.play_move_swing(atk, _move())
	assert_eq(Sound.last_voice, {}, "sum-0 effort pool -> no grunt")
	assert_ne(Sound.last_sfx, {}, "...but the swing SFX still plays")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_move_sound_firing.gd -gexit`
Expected: FAIL (`has_move_sounds`/`play_move_swing` not found).

- [ ] **Step 3: Implement the autoload additions**

In `scripts/audio/sound_manager.gd`, add the table constant + field. After line 8 (`ANNOUNCER_TABLE_PATH`), add:

```gdscript
const MOVE_TABLE_PATH := "res://assets/audio/move_sound_table.tres"
```

After line 11 (`var table: SoundTable = null`), add:

```gdscript
var move_table: MoveSoundTable = null
```

In `_ready()`, after the `table` load block (after line 37 `table = load(TABLE_PATH)`), add:

```gdscript
	if move_table == null and ResourceLoader.exists(MOVE_TABLE_PATH):
		move_table = load(MOVE_TABLE_PATH)
```

At the end of the file, add the query + play methods:

```gdscript
## True when a move has a per-move sound mapping (so Fighter uses the new path + suppresses legacy).
func has_move_sounds(move_id: String) -> bool:
	return move_table != null and move_table.resolve(move_id) != null

## Windup: the move's swing whoosh (SFX) + the attacker's effort grunt (Voice, may be silent).
func play_move_swing(attacker: Node, move: MoveSequence) -> void:
	var ms: MoveSounds = move_table.resolve(move.id) if move_table != null else null
	if ms == null:
		return
	if ms.swing != null:
		_play_pool_sfx(ms.swing, attacker.global_position)
	var wid: StringName = attacker.wrestler_id
	if ms.attack.has(wid):
		_play_pool_voice(attacker, ms.attack[wid])

## Contact: the move's impact (SFX at the victim) + the victim's pain (Voice, may be silent).
func play_move_hit(attacker: Node, victim: Node, move: MoveSequence) -> void:
	var ms: MoveSounds = move_table.resolve(move.id) if move_table != null else null
	if ms == null:
		return
	if ms.hit != null:
		_play_pool_sfx(ms.hit, victim.global_position)
	var wid: StringName = attacker.wrestler_id
	if ms.pain.has(wid):
		_play_pool_voice(victim, ms.pain[wid])

func _play_pool_sfx(pool: SoundPool, at_pos: Vector2) -> void:
	var s := pool.pick_stream(rng)
	if s == null:
		return
	last_sfx = {"stream": s, "bus": pool.bus, "position": at_pos}
	if muted:
		return
	var p: AudioStreamPlayer2D = _sfx_pool[_next_sfx]
	_next_sfx = (_next_sfx + 1) % _sfx_pool.size()
	p.stream = s
	p.bus = pool.bus
	p.global_position = at_pos
	p.volume_db = pool.volume_db
	p.pitch_scale = 1.0 + rng.randf_range(-pool.pitch_jitter, pool.pitch_jitter)
	p.play()

func _play_pool_voice(fighter: Node, pool: SoundPool) -> void:
	var s := pool.pick_stream(rng)
	if s == null:
		return   # silence (chance gate) — no voice this hit
	if muted:
		last_voice = {"stream": s, "fighter": fighter, "priority": pool.priority}
		return
	var id := fighter.get_instance_id()
	var st: Dictionary = _voice.get(id, {})
	if st.is_empty() or not is_instance_valid(st.get("player")):
		var pl := AudioStreamPlayer2D.new()
		pl.bus = &"Voice"
		fighter.add_child(pl)
		st = {"player": pl, "priority": -1}
		_voice[id] = st
	var pl2: AudioStreamPlayer2D = st["player"]
	if not VoicePolicy.should_interrupt(st["priority"], pool.priority, pl2.playing):
		return
	pl2.stream = s
	pl2.volume_db = pool.volume_db
	pl2.pitch_scale = 1.0 + rng.randf_range(-pool.pitch_jitter, pool.pitch_jitter)
	pl2.play()
	st["priority"] = pool.priority
	last_voice = {"stream": s, "fighter": fighter, "priority": pool.priority}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . --import` then
`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_move_sound_firing.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/audio/sound_manager.gd test/unit/test_move_sound_firing.gd test/unit/test_move_sound_firing.gd.uid
git commit -m "feat(sound): Sound.play_move_swing/hit through per-move pools"
```

---

## Task 4: Fighter — fire mapped sounds, suppress legacy

**Files:**
- Modify: `scripts/fighter.gd`
- Test: `test/unit/test_move_sound_firing.gd` (extend)

- [ ] **Step 1: Add the failing tests**

Append to `test/unit/test_move_sound_firing.gd`:

```gdscript
func test_mapped_strike_swings_at_move_start():
	var atk := Fighter.new(); add_child_autofree(atk); atk.wrestler_id = &"doink"
	atk.start_move(_move())
	assert_ne(Sound.last_sfx, {}, "a mapped move plays a swing at start")

func test_mapped_hit_uses_new_path_not_legacy():
	# Legacy path plays via the SoundTable; the new path plays via move pools. With a move_table
	# entry present, the hit SFX must come from the pool (we assert it fired at the victim).
	var atk := Fighter.new(); add_child_autofree(atk); atk.wrestler_id = &"doink"
	var vic := Fighter.new(); add_child_autofree(vic); vic.global_position = Vector2(700, 480)
	vic.receive_hit(atk, _move())
	assert_eq(Sound.last_sfx.get("position"), Vector2(700, 480), "hit SFX at the victim via the pool")
	assert_eq(Sound.last_voice.get("fighter"), vic, "pain via the pool on the victim")

func test_unmapped_move_still_uses_legacy_path():
	var atk := Fighter.new(); add_child_autofree(atk); atk.wrestler_id = &"doink"
	var vic := Fighter.new(); add_child_autofree(vic); vic.global_position = Vector2(120, 400)
	var knee := MoveSequence.new(); knee.id = "knee"; knee.attack_mode = AMode.KNEE
	vic.receive_hit(atk, knee)
	# legacy play_impact still fires an SFX (the real doink table maps every AMode to an impact pool;
	# under the synthetic move_table this move is unmapped, so the legacy branch runs).
	assert_ne(Sound.last_sfx, {}, "unmapped move still makes an impact via the legacy path")
```

- [ ] **Step 2: Run to verify they fail**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_move_sound_firing.gd -gexit`
Expected: `test_mapped_strike_swings_at_move_start` FAILS (no swing wired yet).

- [ ] **Step 3: Fire swing at move start**

In `scripts/fighter.gd`, in `start_move` (after `_player.play(move)` / before/after `_play_sequence_anim()` at the end of the function — locate the lines `_player.play(move)` … `_play_sequence_anim()`), add the swing call right after `_player.play(move)`:

```gdscript
	_player.play(move)
	if Sound.has_move_sounds(move.id):
		Sound.play_move_swing(self, move)
	_hit_by_current_move.clear()
	_play_sequence_anim()
```

- [ ] **Step 4: Route hit/pain through the new path + suppress legacy**

In `scripts/fighter.gd`, in `receive_hit`, replace the two legacy lines (currently 815-816):

```gdscript
	Sound.play_impact(attacker.wrestler_id, move.attack_mode, global_position)
	Sound.play_category(self, SoundCategory.PAIN)
```

with:

```gdscript
	if Sound.has_move_sounds(move.id):
		Sound.play_move_hit(attacker, self, move)   # per-move swing/hit/attack/pain model
	else:
		Sound.play_impact(attacker.wrestler_id, move.attack_mode, global_position)
		Sound.play_category(self, SoundCategory.PAIN)
```

(Leave the `BODY_DROP` and `announce(...)` lines below unchanged — they are separate concerns.)

- [ ] **Step 5: Run the new tests + full suite**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_move_sound_firing.gd -gexit`
Expected: PASS.
Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit`
Expected: all green. The existing `test_fighter_sound.gd` uses move id `"t"` (unmapped), so it keeps exercising the legacy path — no regression.

- [ ] **Step 6: Commit**

```bash
git add scripts/fighter.gd test/unit/test_move_sound_firing.gd
git commit -m "feat(sound): Fighter fires per-move swing/hit/pain (legacy fallback for unmapped)"
```

---

## Task 5: SoundFileResolver — fuzzy filename matching

**Files:**
- Create: `scripts/audio/sound_file_resolver.gd`
- Test: `test/unit/test_sound_file_resolver.gd`

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_sound_file_resolver.gd`:

```gdscript
extends "res://addons/gut/test.gd"
## Normalize filenames (lowercase, strip spaces/underscores) so the JSON's "swing4.wav" matches the
## source file "Swing 4.wav". resolve() looks up a prebuilt normalized index.

func test_normalize_strips_case_and_spaces():
	assert_eq(SoundFileResolver.normalize("Swing 4.wav"), "swing4.wav")
	assert_eq(SoundFileResolver.normalize("swing4.wav"), "swing4.wav")
	assert_eq(SoundFileResolver.normalize("Doink attack 8.wav"), "doinkattack8.wav")
	assert_eq(SoundFileResolver.normalize("Punch2.wav"), "punch2.wav")

func test_resolve_hits_the_index():
	var index := {
		"swing4.wav": "/src/Punches/Swing 4.wav",
		"punch2.wav": "/src/Punches/Punch2.wav",
	}
	assert_eq(SoundFileResolver.resolve("swing4.wav", index), "/src/Punches/Swing 4.wav")
	assert_eq(SoundFileResolver.resolve("Punch2.wav", index), "/src/Punches/Punch2.wav")

func test_resolve_missing_returns_empty():
	assert_eq(SoundFileResolver.resolve("nope.wav", {}), "")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_sound_file_resolver.gd -gexit`
Expected: FAIL (`SoundFileResolver` not found).

- [ ] **Step 3: Create the resolver**

Create `scripts/audio/sound_file_resolver.gd`:

```gdscript
class_name SoundFileResolver
## Fuzzy filename matching for the sound build tool: the JSON uses a normalized form ("swing4.wav")
## while the source files have spaces/case ("Swing 4.wav"). Both sides normalize the same way.

## Lowercase and remove spaces + underscores (the extension is kept, also lowercased).
static func normalize(name: String) -> String:
	return name.to_lower().replace(" ", "").replace("_", "")

## Look up a (possibly un-normalized) `name` in a prebuilt {normalized -> full_path} index.
## Returns the full path, or "" if absent.
static func resolve(name: String, index: Dictionary) -> String:
	return index.get(normalize(name), "")
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . --import` then
`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_sound_file_resolver.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/audio/sound_file_resolver.gd scripts/audio/sound_file_resolver.gd.uid \
	test/unit/test_sound_file_resolver.gd test/unit/test_sound_file_resolver.gd.uid
git commit -m "feat(sound): SoundFileResolver — normalized fuzzy filename match"
```

---

## Task 6: Build tool — JSON → imported WAVs → move_sound_table.tres

**Files:**
- Create: `tools/build_sound_mapping.gd`, `tools/sound_mapping.json`
- Generated: `assets/audio/move_sound_table.tres`, copied WAVs under `assets/audio/`

- [ ] **Step 1: Move the JSON into the repo**

```bash
cp "/media/pablin/DATOS/JUEGOS/Wrestlemania/sound_mapping.json" tools/sound_mapping.json
```

Then rename the top-level `mid_punch` key to `punch` so it matches the move id:

Edit `tools/sound_mapping.json` line 2: change `"mid_punch": {` to `"punch": {`.

- [ ] **Step 2: Write the build tool**

Create `tools/build_sound_mapping.gd`:

```gdscript
extends SceneTree
## Build assets/audio/move_sound_table.tres from tools/sound_mapping.json.
## Pass 1: fuzzy-resolve every referenced WAV against the source tree and COPY it into the project.
##   If anything was newly copied, exit 2 and ask for --import (Godot must import the new WAVs).
## Pass 2 (after --import): all WAVs importable -> build SoundPool/MoveSounds/MoveSoundTable + save.
## Run: godot --headless --path . -s tools/build_sound_mapping.gd  (then --import, then re-run)

const JSON_PATH := "res://tools/sound_mapping.json"
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
	for move_id in json:
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
	for move_id in json:
		var buckets: Dictionary = json[move_id]
		var ms := MoveSounds.new()
		ms.swing = _sfx_pool(buckets.get("swing", []), dest_of)
		ms.hit = _sfx_pool(buckets.get("hit", []), dest_of)
		ms.attack = _voice_pools(buckets.get("attack", {}), dest_of)
		ms.pain = _voice_pools(buckets.get("pain", {}), dest_of)
		t.moves[move_id] = ms
		print("%s: swing %d, hit %d, attack %s, pain %s" % [move_id,
			ms.swing.streams.size(), ms.hit.streams.size(), ms.attack.keys(), ms.pain.keys()])
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
		var dir := stack.pop_back()
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
```

- [ ] **Step 3: Run the tool (pass 1 — copies WAVs)**

Run: `godot --headless --path . -s tools/build_sound_mapping.gd`
Expected: prints "Copied N new WAV(s). Run: … --import" and exits (code 2). If instead it prints "Unresolved sound files", a filename in the JSON doesn't exist in the source tree — fix the JSON and re-run.

- [ ] **Step 4: Import the copied WAVs, then run pass 2**

Run: `godot --headless --path . --import`
Run: `godot --headless --path . -s tools/build_sound_mapping.gd`
Expected: prints a per-move summary (`punch: swing 3, hit 6, attack [doink], pain [doink]` etc.) and `move_sound_table -> OK`, creating `assets/audio/move_sound_table.tres`.
Run: `godot --headless --path . --import`  (register the new .tres)

- [ ] **Step 5: Verify the table loads and resolves**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit`
Expected: all green (the autoload now loads the real `move_sound_table.tres`; existing sound tests use unmapped ids so they still hit the legacy path).

- [ ] **Step 6: Commit**

```bash
git add tools/build_sound_mapping.gd tools/build_sound_mapping.gd.uid tools/sound_mapping.json \
	assets/audio/move_sound_table.tres assets/audio/sfx assets/audio/voice
git commit -m "feat(sound): build tool + sound_mapping.json -> move_sound_table.tres (punch, headbutt)"
```

---

## Task 7: End-to-end integration test

**Files:**
- Test: `test/unit/test_sound_mapping_integration.gd`

- [ ] **Step 1: Write the test**

Create `test/unit/test_sound_mapping_integration.gd`:

```gdscript
extends "res://addons/gut/test.gd"
## With the REAL generated move_sound_table loaded, a Doink punch swings at start and hits+pains on
## contact through the per-move pools (not the legacy category path).

func before_each():
	Sound.last_sfx = {}; Sound.last_voice = {}
	# Reload the REAL table: a prior test file (test_move_sound_firing) swaps in a synthetic table
	# and nulls it in after_all, so don't rely on the autoload's _ready load surviving.
	if ResourceLoader.exists("res://assets/audio/move_sound_table.tres"):
		Sound.move_table = load("res://assets/audio/move_sound_table.tres")

func test_real_table_has_punch_and_headbutt():
	assert_true(ResourceLoader.exists("res://assets/audio/move_sound_table.tres"), "table built")
	assert_true(Sound.has_move_sounds("punch"), "punch is mapped")
	assert_true(Sound.has_move_sounds("headbutt"), "headbutt is mapped")
	assert_false(Sound.has_move_sounds("knee"), "knee is not mapped")

func test_punch_swings_then_hits():
	var punch: MoveSequence = load("res://assets/sequences/doink/punch.tres")
	var atk := Fighter.new(); add_child_autofree(atk); atk.wrestler_id = &"doink"
	atk.global_position = Vector2(300, 410)
	atk.start_move(punch)
	assert_ne(Sound.last_sfx, {}, "swing whoosh at move start")
	Sound.last_sfx = {}
	var vic := Fighter.new(); add_child_autofree(vic); vic.global_position = Vector2(360, 410)
	vic.wrestler_id = &"doink"
	vic.receive_hit(atk, punch)
	assert_eq(Sound.last_sfx.get("position"), Vector2(360, 410), "impact at the victim")
```

- [ ] **Step 2: Run the test + full suite**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_sound_mapping_integration.gd -gexit`
Expected: PASS.
Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit`
Expected: all green.

- [ ] **Step 3: Commit**

```bash
git add test/unit/test_sound_mapping_integration.gd test/unit/test_sound_mapping_integration.gd.uid
git commit -m "test(sound): end-to-end per-move sound mapping (real table)"
```

---

## Task 8: Manual playtest checklist (no code)

- [ ] Launch the sandbox, enable enemy AI, trade punches/headbutts. Confirm: a whoosh on each swing (even a whiff), a distinct impact on contact, effort grunts on roughly half the punches (not every one), pain cries less than every hit.
- [ ] Confirm other moves (kick, knee, grapples) sound exactly as before (legacy path).
- [ ] To tune: edit `tools/sound_mapping.json` (precedence/probability/files), then
  `godot --headless --path . -s tools/build_sound_mapping.gd` → `--import` → (re-run tool) → `--import`.

---

## Self-Review Notes

- **Spec coverage:** §2 JSON → Task 6; §3 semantics → Task 1 (`pick_from_roll`/`pick_index`); §4 resources → Tasks 1-2; §5 firing/timing/suppression → Tasks 3-4; §6 build pipeline + fuzzy resolve → Tasks 5-6; §8 testing → every task + Task 7. Non-goals respected (announcer/body-drop/ANI_SOUND untouched; no priority system; build-time only).
- **Type consistency:** `SoundPool.pick_from_roll/pick_index/pick_stream` (Task 1) used by `_pool_for` (Task 6) and `_play_pool_*` (Task 3). `MoveSounds.{swing,hit,attack,pain}` (Task 2) consumed in Tasks 3,6. `MoveSoundTable.resolve` (Task 2) used in Tasks 3,4,7. `Sound.has_move_sounds/play_move_swing/play_move_hit` (Task 3) called in Task 4. `SoundFileResolver.normalize/resolve` (Task 5) used in Task 6. `wrestler_id` is an existing `Fighter` field (`fighter.gd:24`).
- **Two-pass build:** Task 6 deliberately exits with code 2 after copying WAVs (Godot must `--import` before the tool can `load()` them); the re-run builds the table. This mirrors the existing `import_sounds.gd` → `--import` → `build_doink_sound_table.gd` flow.
