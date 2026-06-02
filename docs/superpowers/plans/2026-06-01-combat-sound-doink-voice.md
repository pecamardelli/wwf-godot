# Combat Sound — Universal SFX + Doink Voice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give combat audible feel — universal punch/impact/body-drop SFX fired on hit, plus Doink's pain/taunt voice and per-frame voice specials — via a data-driven, arcade-faithful sound system.

**Architecture:** A `SoundManager` autoload owns audio buses, a polyphonic `AudioStreamPlayer2D` SFX pool, and one positional voice channel per fighter. A `SoundTable` resource maps a move category → `SoundEntry` (random-variant stream pool) with per-wrestler overrides over a universal default — the arcade's `MASTER_SOUND_TABLE`/`DEFAULT_SOUND_TABLE` + `WRSND` fallback. On-hit impacts key off `move.attack_mode` (which already mirrors the arcade move categories in `AMode`). Per-frame sounds ride a new `SequenceFrame.sound` field surfaced through `SequencePlayer` as a consume-style intent — the arcade `ANI_SOUND` opcode.

**Tech Stack:** Godot 4.6 · GDScript · GUT (headless unit tests) · `AudioStreamWAV` assets.

**Spec:** `docs/superpowers/specs/2026-06-01-combat-sound-doink-voice-design.md`

**Conventions (match existing code):**
- Pure/testable helpers live in `scripts/audio/` with a `class_name`; stateful glue stays in `Fighter`/the autoload (CLAUDE.md).
- Tests: `test/unit/test_<thing>.gd`, `extends "res://addons/gut/test.gd"`.
- A new `class_name` needs the class cache rebuilt before the headless runner sees it:
  `godot --headless --path . --import`
- Run the suite:
  `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit`
- Commit after every task.

---

## File structure

**Create:**
- `default_bus_layout.tres` — Master → SFX / Voice / Music buses.
- `scripts/audio/sound_category.gd` — `class_name SoundCategory`: voice/event category constants (impact categories = `AMode` values).
- `scripts/audio/sound_entry.gd` — `class_name SoundEntry`: a category's stream variants + priority/bus/volume/jitter.
- `scripts/audio/voice_policy.gd` — `class_name VoicePolicy`: pure interrupt-decision.
- `scripts/audio/sound_table.gd` — `class_name SoundTable`: default + per-wrestler maps, `resolve()`.
- `scripts/audio/sound_manager.gd` — autoload `Sound`: pool, voice channels, play methods, test seams.
- `tools/import_sounds.gd` — copy+rename the needed WAVs from `WWF Sources/Sounds` into `assets/audio/`.
- `tools/build_doink_sound_table.gd` — build `assets/audio/doink_sound_table.tres` from imported assets.
- `assets/audio/entries/doink_buzzer.tres`, `.../doink_hammer.tres` — explicit `SoundEntry` for `ANI_SOUND` specials.
- Tests: `test/unit/test_sound_entry.gd`, `test_voice_policy.gd`, `test_sound_table.gd`, `test_sound_manager.gd`, `test_sound_buses.gd`, `test_sequence_player_sound.gd`, `test_fighter_sound.gd`.

**Modify:**
- `project.godot` — add `[autoload] Sound=...`.
- `scripts/combat/sequence_frame.gd` — add `@export var sound: SoundEntry`.
- `scripts/combat/sequence_player.gd` — surface a `consume_sounds()` intent.
- `scripts/fighter.gd` — add `wrestler_id`; fire impacts/voice/body-drop at hit/reaction/detach; consume frame sounds.
- `assets/sequences/doink/*.tres` — attach `ANI_SOUND` specials (joy_buzzer, hammer).
- `scenes/Sandbox.tscn` — set `wrestler_id` on the Doink fighters (manual verify).

---

## Task 1: Audio bus layout

**Files:**
- Create: `default_bus_layout.tres`
- Modify: `project.godot` (add `[audio]` reference is implicit — Godot auto-loads `res://default_bus_layout.tres`)
- Test: `test/unit/test_sound_buses.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends "res://addons/gut/test.gd"
## The audio bus layout the sound system routes through must exist at runtime.

func test_buses_exist():
	assert_true(AudioServer.get_bus_index("Master") >= 0, "Master bus present")
	assert_true(AudioServer.get_bus_index("SFX") >= 0, "SFX bus present")
	assert_true(AudioServer.get_bus_index("Voice") >= 0, "Voice bus present")
	assert_true(AudioServer.get_bus_index("Music") >= 0, "Music bus present (stub)")

func test_sfx_and_voice_route_to_master():
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index("SFX")), &"Master")
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index("Voice")), &"Master")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_sound_buses.gd -gexit`
Expected: FAIL — only the default `Master` bus exists; `SFX`/`Voice`/`Music` indices are `-1`.

- [ ] **Step 3: Create the bus layout**

Create `default_bus_layout.tres`:

```
[gd_resource type="AudioBusLayout" format=3]

[resource]
bus/0/name = &"Master"
bus/0/solo = false
bus/0/mute = false
bus/0/bypass_fx = false
bus/0/volume_db = 0.0
bus/0/send = &""
bus/1/name = &"SFX"
bus/1/solo = false
bus/1/mute = false
bus/1/bypass_fx = false
bus/1/volume_db = 0.0
bus/1/send = &"Master"
bus/2/name = &"Voice"
bus/2/solo = false
bus/2/mute = false
bus/2/bypass_fx = false
bus/2/volume_db = 0.0
bus/2/send = &"Master"
bus/3/name = &"Music"
bus/3/solo = false
bus/3/mute = false
bus/3/bypass_fx = false
bus/3/volume_db = 0.0
bus/3/send = &"Master"
```

Godot auto-loads `res://default_bus_layout.tres` at startup, so no `project.godot` change is needed for the layout itself. Verify `project.godot` has no conflicting `audio/buses/default_bus_layout` override (it does not).

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_sound_buses.gd -gexit`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add default_bus_layout.tres test/unit/test_sound_buses.gd
git commit -m "feat(audio): Master→SFX/Voice/Music bus layout"
```

---

## Task 2: SoundCategory + SoundEntry resources

**Files:**
- Create: `scripts/audio/sound_category.gd`, `scripts/audio/sound_entry.gd`
- Test: `test/unit/test_sound_entry.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends "res://addons/gut/test.gd"

func test_category_voice_constants_are_above_amode_range():
	# Impact categories ARE AMode values (0..12). Voice/event cats must not collide.
	assert_gt(SoundCategory.PAIN, AMode.BOXGLOVE)
	assert_gt(SoundCategory.EFFORT, AMode.BOXGLOVE)
	assert_gt(SoundCategory.TAUNT, AMode.BOXGLOVE)
	assert_gt(SoundCategory.BODY_DROP, AMode.BOXGLOVE)
	# distinct
	var ids := [SoundCategory.PAIN, SoundCategory.EFFORT, SoundCategory.TAUNT, SoundCategory.BODY_DROP]
	assert_eq(ids.size(), 4)
	assert_eq(ids, [SoundCategory.PAIN, SoundCategory.EFFORT, SoundCategory.TAUNT, SoundCategory.BODY_DROP])

func test_sound_entry_defaults():
	var e := SoundEntry.new()
	assert_eq(e.streams.size(), 0)
	assert_eq(e.priority, 0)
	assert_eq(e.bus, &"SFX")
	assert_eq(e.volume_db, 0.0)
	assert_eq(e.pitch_jitter, 0.0)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `godot --headless --path . --import` then
`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_sound_entry.gd -gexit`
Expected: FAIL — `SoundCategory`/`SoundEntry` are not defined classes.

- [ ] **Step 3: Create the resources**

Create `scripts/audio/sound_category.gd`:

```gdscript
class_name SoundCategory
## Sound categories. Impact categories ARE the arcade move categories — which our `AMode`
## enum already mirrors (PUNCH, HDBUTT, KICK, ...) — so a move's `attack_mode` is used directly
## as the lookup key (arcade WRSND indexes the sound table by move type). The voice/event
## categories below live ABOVE the AMode range so they never collide with an impact category.
const PAIN := 100        # victim grunt on taking a hit (arcade pain voice)
const EFFORT := 101      # attacker effort grunt (arcade ANI_SOUND grunts, e.g. 82h)
const TAUNT := 102       # laugh/taunt
const BODY_DROP := 103   # the thud of a body hitting the floor (arcade bounce_l1 / RUGSLAM_IMPACT)
```

Create `scripts/audio/sound_entry.gd`:

```gdscript
class_name SoundEntry
extends Resource
## One category's playable sound: a pool of interchangeable variants (random-picked, like the
## arcade's per-move sound slots) plus playback params. Maps to one arcade sound id/slot.

@export var streams: Array[AudioStream] = []   # variants; one is picked at random per play
@export var priority: int = 0                  # higher interrupts lower on a fighter's voice channel
@export var bus: StringName = &"SFX"           # &"SFX" or &"Voice"
@export var volume_db: float = 0.0
@export var pitch_jitter: float = 0.0          # +/- random pitch spread (0 = none)
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot --headless --path . --import` then
`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_sound_entry.gd -gexit`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add scripts/audio/sound_category.gd scripts/audio/sound_entry.gd test/unit/test_sound_entry.gd
git commit -m "feat(audio): SoundCategory + SoundEntry resources"
```

---

## Task 3: VoicePolicy (pure interrupt decision)

**Files:**
- Create: `scripts/audio/voice_policy.gd`
- Test: `test/unit/test_voice_policy.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends "res://addons/gut/test.gd"
## One voice per fighter: a new line plays if the channel is idle, or if it ranks >= the current
## line; a lower-priority line while busy is dropped. Mirrors the arcade per-channel sndpri.

func test_idle_channel_always_plays():
	assert_true(VoicePolicy.should_interrupt(5, 0, false))   # not busy -> play even if lower pri
	assert_true(VoicePolicy.should_interrupt(99, 1, false))

func test_busy_plays_only_when_ge():
	assert_true(VoicePolicy.should_interrupt(3, 3, true))    # equal -> interrupt (newest wins on tie)
	assert_true(VoicePolicy.should_interrupt(3, 4, true))    # higher -> interrupt
	assert_false(VoicePolicy.should_interrupt(3, 2, true))   # lower -> drop
```

- [ ] **Step 2: Run it to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_voice_policy.gd -gexit`
Expected: FAIL — `VoicePolicy` not defined.

- [ ] **Step 3: Implement**

Create `scripts/audio/voice_policy.gd`:

```gdscript
class_name VoicePolicy
## Pure decision for a fighter's single voice channel (arcade per-channel priority).

## Should a new voice line take the channel? Yes if idle, or if it ranks at least as high as the
## currently-playing line (newest wins on a tie). A lower-priority line while busy is dropped.
static func should_interrupt(current_priority: int, new_priority: int, busy: bool) -> bool:
	if not busy:
		return true
	return new_priority >= current_priority
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_voice_policy.gd -gexit`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add scripts/audio/voice_policy.gd test/unit/test_voice_policy.gd
git commit -m "feat(audio): VoicePolicy interrupt decision"
```

---

## Task 4: SoundTable (resolve + per-wrestler fallback)

**Files:**
- Create: `scripts/audio/sound_table.gd`
- Test: `test/unit/test_sound_table.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends "res://addons/gut/test.gd"
## SoundTable.resolve mirrors arcade WRSND: try the wrestler's override slot, else the default
## slot, else null.

func _entry(tag: StringName) -> SoundEntry:
	var e := SoundEntry.new()
	e.bus = tag   # abuse `bus` as an identity tag for the test
	return e

func _table() -> SoundTable:
	var t := SoundTable.new()
	var def_punch := _entry(&"def_punch")
	var def_body := _entry(&"def_body")
	t.default = {AMode.PUNCH: def_punch, SoundCategory.BODY_DROP: def_body}
	var doink_punch := _entry(&"doink_punch")
	var doink_pain := _entry(&"doink_pain")
	t.per_wrestler = {&"doink": {AMode.PUNCH: doink_punch, SoundCategory.PAIN: doink_pain}}
	return t

func test_wrestler_override_wins():
	var t := _table()
	assert_eq(t.resolve(&"doink", AMode.PUNCH).bus, &"doink_punch")

func test_falls_back_to_default_when_wrestler_has_no_slot():
	var t := _table()
	# doink has no BODY_DROP override -> default
	assert_eq(t.resolve(&"doink", SoundCategory.BODY_DROP).bus, &"def_body")

func test_unknown_wrestler_uses_default():
	var t := _table()
	assert_eq(t.resolve(&"bret", AMode.PUNCH).bus, &"def_punch")

func test_missing_category_returns_null():
	var t := _table()
	assert_null(t.resolve(&"doink", AMode.KICK))   # no override, no default for KICK
	assert_null(t.resolve(&"bret", SoundCategory.PAIN))
```

- [ ] **Step 2: Run it to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_sound_table.gd -gexit`
Expected: FAIL — `SoundTable` not defined.

- [ ] **Step 3: Implement**

Create `scripts/audio/sound_table.gd`:

```gdscript
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_sound_table.gd -gexit`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add scripts/audio/sound_table.gd test/unit/test_sound_table.gd
git commit -m "feat(audio): SoundTable resolve with per-wrestler fallback"
```

---

## Task 5: SoundManager autoload (playback + test seams)

**Files:**
- Create: `scripts/audio/sound_manager.gd`
- Modify: `project.godot` (register autoload `Sound`)
- Test: `test/unit/test_sound_manager.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends "res://addons/gut/test.gd"
## SoundManager resolves + plays. We assert via the test seam (`last_sfx` / `last_voice`) and
## the per-fighter voice node — no real audio device needed (headless uses the dummy driver).

## A fighter-like stub: Node2D + a wrestler_id (Fighter.wrestler_id is added later, in Task 8).
class _StubFighter extends Node2D:
	var wrestler_id: StringName = &"doink"

func _stream() -> AudioStream:
	return AudioStreamWAV.new()   # empty but valid stream object

func _entry(bus: StringName, pri: int, n: int) -> SoundEntry:
	var e := SoundEntry.new()
	e.bus = bus
	e.priority = pri
	for _i in range(n):
		e.streams.append(_stream())
	return e

func _mgr() -> Node:
	var m = load("res://scripts/audio/sound_manager.gd").new()
	add_child_autofree(m)
	return m

func test_pick_stream_is_deterministic_with_seed():
	var m = _mgr()
	var e := _entry(&"SFX", 0, 3)
	m.rng.seed = 42
	var a := m.pick_stream(e)
	m.rng.seed = 42
	var b := m.pick_stream(e)
	assert_eq(a, b, "same seed -> same variant")
	assert_true(e.streams.has(a))

func test_pick_stream_single_variant_and_empty():
	var m = _mgr()
	var one := _entry(&"SFX", 0, 1)
	assert_eq(m.pick_stream(one), one.streams[0])
	assert_null(m.pick_stream(_entry(&"SFX", 0, 0)))
	assert_null(m.pick_stream(null))

func test_play_impact_records_sfx_at_position():
	var m = _mgr()
	var t := SoundTable.new()
	t.default = {AMode.PUNCH: _entry(&"SFX", 0, 2)}
	m.table = t
	m.play_impact(&"doink", AMode.PUNCH, Vector2(300, 400))
	assert_eq(m.last_sfx.get("position"), Vector2(300, 400))
	assert_eq(m.last_sfx.get("bus"), &"SFX")
	assert_not_null(m.last_sfx.get("stream"))

func test_play_impact_missing_category_is_noop():
	var m = _mgr()
	m.table = SoundTable.new()   # empty
	m.last_sfx = {}
	m.play_impact(&"doink", AMode.KICK, Vector2.ZERO)
	assert_eq(m.last_sfx, {}, "no entry -> nothing played")

func test_voice_attaches_one_player_per_fighter_and_obeys_priority():
	var m = _mgr()
	var fighter := Node2D.new()
	add_child_autofree(fighter)
	var loud := _entry(&"Voice", 5, 1)
	var quiet := _entry(&"Voice", 1, 1)
	m.play_voice(fighter, loud)
	var n1 := fighter.get_child_count()
	assert_eq(m.last_voice.get("priority"), 5)
	# a lower-priority line while the loud one "plays" is dropped; channel reused (no 2nd node)
	m.play_voice(fighter, quiet)
	assert_eq(fighter.get_child_count(), n1, "reuses the one voice channel node")

func test_play_category_routes_voice_to_voice_channel():
	var m = _mgr()
	var t := SoundTable.new()
	t.per_wrestler = {&"doink": {SoundCategory.PAIN: _entry(&"Voice", 2, 1)}}
	m.table = t
	var fighter := _StubFighter.new()
	add_child_autofree(fighter)
	m.play_category(fighter, SoundCategory.PAIN)
	assert_eq(m.last_voice.get("priority"), 2)
```

- [ ] **Step 2: Create a stub autoload, register it**

Create `scripts/audio/sound_manager.gd` as a loadable stub (so the project boots and the test
fails on assertions, not on a missing file):

```gdscript
extends Node
## Autoload `Sound` (stub — bodies filled in the next step).
const TABLE_PATH := "res://assets/audio/doink_sound_table.tres"
var table: SoundTable = null
var rng := RandomNumberGenerator.new()
var last_sfx: Dictionary = {}
var last_voice: Dictionary = {}
func pick_stream(_entry: SoundEntry) -> AudioStream: return null
func play_impact(_wrestler_id: StringName, _category: int, _at_pos: Vector2) -> void: pass
func play_category(_fighter: Node, _category: int) -> void: pass
func play_entry(_entry: SoundEntry, _fighter: Node) -> void: pass
func play_voice(_fighter: Node, _entry: SoundEntry) -> void: pass
```

Register the autoload in `project.godot` (add this section after `[application]`):

```
[autoload]

Sound="*res://scripts/audio/sound_manager.gd"
```

(The leading `*` enables it as a singleton accessible globally as `Sound`.)

- [ ] **Step 3: Run it to verify it fails**

Run: `godot --headless --path . --import` then
`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_sound_manager.gd -gexit`
Expected: project boots; tests FAIL on assertions (`pick_stream` returns null, `last_sfx` stays empty).

- [ ] **Step 4: Implement the autoload**

Replace `scripts/audio/sound_manager.gd` with the full implementation:

```gdscript
extends Node
## Autoload `Sound`. Owns a polyphonic SFX player pool and one voice channel per fighter.
## Resolves categories through the SoundTable (arcade WRSND) and plays positionally
## (AudioStreamPlayer2D, so pan/attenuation follow screen position).

const TABLE_PATH := "res://assets/audio/doink_sound_table.tres"
const POOL_SIZE := 8

var table: SoundTable = null
var rng := RandomNumberGenerator.new()

var _sfx_pool: Array[AudioStreamPlayer2D] = []
var _next_sfx := 0
var _voice: Dictionary = {}   # fighter instance_id -> {player: AudioStreamPlayer2D, priority: int}

# --- Test seams: the last thing played (asserted in unit tests; ignored in the game). ---
var last_sfx: Dictionary = {}
var last_voice: Dictionary = {}

func _ready() -> void:
	if table == null and ResourceLoader.exists(TABLE_PATH):
		table = load(TABLE_PATH)
	for _i in range(POOL_SIZE):
		var p := AudioStreamPlayer2D.new()
		p.bus = &"SFX"
		add_child(p)
		_sfx_pool.append(p)

## Pick a random variant from an entry (deterministic under a seeded rng). Null-safe.
func pick_stream(entry: SoundEntry) -> AudioStream:
	if entry == null or entry.streams.is_empty():
		return null
	if entry.streams.size() == 1:
		return entry.streams[0]
	return entry.streams[rng.randi_range(0, entry.streams.size() - 1)]

## On-hit impact: resolve the attacker's table slot for the move category, play at `at_pos`.
func play_impact(wrestler_id: StringName, category: int, at_pos: Vector2) -> void:
	if table == null:
		return
	_play_sfx(table.resolve(wrestler_id, category), at_pos)

## Resolve `category` for the fighter's wrestler and route by the entry's bus (Voice -> the
## fighter's voice channel; anything else -> the SFX pool at the fighter's position).
func play_category(fighter: Node, category: int) -> void:
	if table == null:
		return
	var wid: StringName = fighter.get("wrestler_id") if fighter.get("wrestler_id") != null else &""
	play_entry(table.resolve(wid, category), fighter)

func play_entry(entry: SoundEntry, fighter: Node) -> void:
	if entry == null:
		return
	if entry.bus == &"Voice":
		play_voice(fighter, entry)
	else:
		_play_sfx(entry, fighter.global_position)

func play_voice(fighter: Node, entry: SoundEntry) -> void:
	if entry == null:
		return
	var id := fighter.get_instance_id()
	var st: Dictionary = _voice.get(id, {})
	if st.is_empty():
		var pl := AudioStreamPlayer2D.new()
		pl.bus = &"Voice"
		fighter.add_child(pl)
		st = {"player": pl, "priority": -1}
		_voice[id] = st
	var pl2: AudioStreamPlayer2D = st["player"]
	if not VoicePolicy.should_interrupt(st["priority"], entry.priority, pl2.playing):
		return
	var s := pick_stream(entry)
	if s == null:
		return
	pl2.stream = s
	pl2.volume_db = entry.volume_db
	pl2.pitch_scale = 1.0 + rng.randf_range(-entry.pitch_jitter, entry.pitch_jitter)
	pl2.play()
	st["priority"] = entry.priority
	last_voice = {"stream": s, "fighter": fighter, "priority": entry.priority}

func _play_sfx(entry: SoundEntry, at_pos: Vector2) -> void:
	var s := pick_stream(entry)
	if s == null:
		return
	var p: AudioStreamPlayer2D = _sfx_pool[_next_sfx]
	_next_sfx = (_next_sfx + 1) % _sfx_pool.size()
	p.stream = s
	p.bus = entry.bus
	p.global_position = at_pos
	p.volume_db = entry.volume_db
	p.pitch_scale = 1.0 + rng.randf_range(-entry.pitch_jitter, entry.pitch_jitter)
	p.play()
	last_sfx = {"stream": s, "bus": entry.bus, "position": at_pos}
```

Note: `_play_sfx` is also reachable before `_ready` populated the pool in some unit contexts; `add_child_autofree(m)` in the test triggers `_ready`, so the pool exists. If `_sfx_pool` is empty it would error — guard is unnecessary because the autoload always runs `_ready`, but the test adds the node to the tree first, which runs `_ready`.

- [ ] **Step 5: Run the test to verify it passes**

Run: `godot --headless --path . --import` then
`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_sound_manager.gd -gexit`
Expected: PASS (6 tests).

- [ ] **Step 6: Run the full suite (autoload must not break existing tests)**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit`
Expected: all prior tests still PASS (the autoload's `_ready` is a no-op when the table file is absent).

- [ ] **Step 7: Commit**

```bash
git add scripts/audio/sound_manager.gd project.godot test/unit/test_sound_manager.gd
git commit -m "feat(audio): SoundManager autoload — pool, voice channels, table playback"
```

---

## Task 6: Import the WAV subset

**Files:**
- Create: `tools/import_sounds.gd`
- Creates assets under: `assets/audio/sfx/`, `assets/audio/voice/doink/`

This task copies+renames the WAVs this slice needs from the external `WWF Sources/Sounds` folder
into the project, then imports them. No unit test (it's an asset-prep tool); verification is the
file listing in Step 3.

- [ ] **Step 1: Write the import tool**

Create `tools/import_sounds.gd`:

```gdscript
extends SceneTree
## One-shot asset import: copy + rename the WAVs this slice needs from the external WWF Sources
## rip into res://assets/audio. Run headless:
##   godot --headless --path . --script res://tools/import_sounds.gd
## then re-import so Godot generates the .import files:
##   godot --headless --path . --import

const SRC := "/media/pablin/DATOS/JUEGOS/Wrestlemania/WWF Sources/Sounds"

# dest_dir -> { dest_filename : source_relative_path }
const MANIFEST := {
	"res://assets/audio/sfx": {
		"impact_01.wav": "Punches_impacts_etc/Punches_impacts_etc/Impact.wav",
		"impact_02.wav": "Punches_impacts_etc/Punches_impacts_etc/Impact 2.wav",
		"impact_03.wav": "Punches_impacts_etc/Punches_impacts_etc/Impact 3.wav",
		"impact_04.wav": "Punches_impacts_etc/Punches_impacts_etc/Impact 4.wav",
		"impact_05.wav": "Punches_impacts_etc/Punches_impacts_etc/Impact 5.wav",
		"impact_06.wav": "Punches_impacts_etc/Punches_impacts_etc/Impact 6.wav",
		"body_drop_01.wav": "Punches_impacts_etc/Punches_impacts_etc/Ring body drop.wav",
		"body_drop_02.wav": "Punches_impacts_etc/Punches_impacts_etc/Ring body drop 2.wav",
	},
	"res://assets/audio/voice/doink": {
		"doink_pain_01.wav": "Doink_sound/Doink/Doink pain.wav",
		"doink_pain_02.wav": "Doink_sound/Doink/Doink pain 2.wav",
		"doink_pain_03.wav": "Doink_sound/Doink/Doink pain 3.wav",
		"doink_pain_04.wav": "Doink_sound/Doink/Doink pain 4.wav",
		"doink_pain_05.wav": "Doink_sound/Doink/Doink pain 5.wav",
		"doink_pain_06.wav": "Doink_sound/Doink/Doink pain 6.wav",
		"doink_taunt_01.wav": "Doink_sound/Doink/Doink laugh.wav",
		"doink_taunt_02.wav": "Doink_sound/Doink/Doink laugh 2.wav",
		"doink_taunt_03.wav": "Doink_sound/Doink/Doink laugh 3.wav",
		"doink_buzzer.wav": "Doink_sound/Doink/Doink You made a good choise.wav",
		"doink_hammer.wav": "Doink_sound/Doink/Doink Hammer blow.wav",
	},
}

func _init() -> void:
	var copied := 0
	var missing: Array[String] = []
	for dest_dir in MANIFEST:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest_dir))
		var files: Dictionary = MANIFEST[dest_dir]
		for dest_name in files:
			var src_abs := SRC + "/" + files[dest_name]
			var dst_abs := ProjectSettings.globalize_path(dest_dir + "/" + dest_name)
			if not FileAccess.file_exists(src_abs):
				missing.append(src_abs)
				continue
			var err := DirAccess.copy_absolute(src_abs, dst_abs)
			if err == OK:
				copied += 1
			else:
				push_error("copy failed (%d): %s" % [err, src_abs])
	print("import_sounds: copied %d file(s)" % copied)
	if not missing.is_empty():
		push_error("import_sounds: MISSING %d source file(s):\n%s" % [missing.size(), "\n".join(missing)])
	quit(1 if not missing.is_empty() else 0)
```

- [ ] **Step 2: Run the tool, then import**

Run:
```bash
godot --headless --path . --script res://tools/import_sounds.gd
godot --headless --path . --import
```
Expected: `import_sounds: copied 19 file(s)` and no MISSING errors.

- [ ] **Step 3: Verify the assets landed and imported**

Run:
```bash
ls assets/audio/sfx assets/audio/voice/doink
ls assets/audio/sfx/*.wav.import | wc -l
```
Expected: the 19 renamed `.wav` files present; each has a sibling `.wav.import` after `--import`.

- [ ] **Step 4: Commit**

```bash
git add tools/import_sounds.gd assets/audio
git commit -m "chore(audio): import universal SFX + Doink voice WAV subset"
```

---

## Task 7: Build the Doink SoundTable resource

**Files:**
- Create: `tools/build_doink_sound_table.gd`
- Creates: `assets/audio/doink_sound_table.tres`

Built by a tool (not hand-authored) so the many stream references stay reproducible.

- [ ] **Step 1: Write the builder tool**

Create `tools/build_doink_sound_table.gd`:

```gdscript
extends SceneTree
## Build assets/audio/doink_sound_table.tres from the imported WAVs. Run headless:
##   godot --headless --path . --script res://tools/build_doink_sound_table.gd

const OUT := "res://assets/audio/doink_sound_table.tres"

func _load_all(dir: String, names: Array) -> Array[AudioStream]:
	var out: Array[AudioStream] = []
	for n in names:
		var path := dir + "/" + n
		assert(ResourceLoader.exists(path), "missing imported stream: " + path)
		out.append(load(path))
	return out

func _entry(streams: Array[AudioStream], bus: StringName, priority: int, jitter: float) -> SoundEntry:
	var e := SoundEntry.new()
	e.streams = streams
	e.bus = bus
	e.priority = priority
	e.pitch_jitter = jitter
	return e

func _init() -> void:
	var impacts := _load_all("res://assets/audio/sfx",
		["impact_01.wav","impact_02.wav","impact_03.wav","impact_04.wav","impact_05.wav","impact_06.wav"])
	var body := _load_all("res://assets/audio/sfx", ["body_drop_01.wav","body_drop_02.wav"])
	var pain := _load_all("res://assets/audio/voice/doink",
		["doink_pain_01.wav","doink_pain_02.wav","doink_pain_03.wav","doink_pain_04.wav","doink_pain_05.wav","doink_pain_06.wav"])
	var taunt := _load_all("res://assets/audio/voice/doink",
		["doink_taunt_01.wav","doink_taunt_02.wav","doink_taunt_03.wav"])

	var impact_entry := _entry(impacts, &"SFX", 0, 0.06)
	var body_entry := _entry(body, &"SFX", 0, 0.04)

	var t := SoundTable.new()
	# Default: every impact move category routes to the shared impact pool; body-drop is its own.
	var def := {}
	for cat in [AMode.PUNCH, AMode.HDBUTT, AMode.KICK, AMode.KNEE, AMode.UPRCUT, AMode.BIGBOOT,
			AMode.STOMP, AMode.LBDROP, AMode.SLAP, AMode.SPINKICK, AMode.EARSLAP, AMode.HAMMER, AMode.BOXGLOVE]:
		def[cat] = impact_entry
	def[SoundCategory.BODY_DROP] = body_entry
	t.default = def
	# Doink voice overrides.
	t.per_wrestler = {
		&"doink": {
			SoundCategory.PAIN: _entry(pain, &"Voice", 2, 0.05),
			SoundCategory.TAUNT: _entry(taunt, &"Voice", 1, 0.0),
		}
	}

	var err := ResourceSaver.save(t, OUT)
	print("build_doink_sound_table: saved %s (err=%d)" % [OUT, err])
	quit(0 if err == OK else 1)
```

- [ ] **Step 2: Run the builder**

Run:
```bash
godot --headless --path . --script res://tools/build_doink_sound_table.gd
godot --headless --path . --import
```
Expected: `build_doink_sound_table: saved res://assets/audio/doink_sound_table.tres (err=0)`.

- [ ] **Step 3: Verify the table loads and resolves**

Run:
```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_sound_manager.gd -gexit
```
Add this test to `test/unit/test_sound_manager.gd` first (it exercises the real saved table through the autoload's `_ready` loader):

```gdscript
func test_real_table_loads_and_resolves_doink_pain_and_default_impact():
	var m = _mgr()   # _ready loads res://assets/audio/doink_sound_table.tres
	assert_not_null(m.table, "doink_sound_table.tres loaded")
	var pain := m.table.resolve(&"doink", SoundCategory.PAIN)
	assert_not_null(pain)
	assert_eq(pain.bus, &"Voice")
	var punch := m.table.resolve(&"doink", AMode.PUNCH)   # no override -> default impact pool
	assert_not_null(punch)
	assert_eq(punch.bus, &"SFX")
	assert_gt(punch.streams.size(), 1, "impact pool has variants")
```

Expected: PASS (now 7 tests in the file).

- [ ] **Step 4: Commit**

```bash
git add tools/build_doink_sound_table.gd assets/audio/doink_sound_table.tres test/unit/test_sound_manager.gd
git commit -m "feat(audio): Doink SoundTable — default impacts + doink pain/taunt"
```

---

## Task 8: Fire impacts + reaction voice from the Fighter

**Files:**
- Modify: `scripts/fighter.gd` (add `wrestler_id`; calls in `receive_hit`, `_enter_reaction`, `_detach_victim`, `_drive_victim` DAMAGE_OPP)
- Test: `test/unit/test_fighter_sound.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends "res://addons/gut/test.gd"
## A landed hit fires an impact SFX at the victim; the victim grunts (PAIN). A knockdown adds a
## body-drop. We assert via the Sound autoload's test seams.

func _move(amode: int, grapple := false) -> MoveSequence:
	var m := MoveSequence.new()
	m.id = "t"
	m.attack_mode = amode
	m.is_grapple = grapple
	return m

func before_each():
	Sound.last_sfx = {}
	Sound.last_voice = {}

func test_landed_hit_plays_impact_at_victim_position():
	var atk := Fighter.new(); add_child_autofree(atk)
	var vic := Fighter.new(); add_child_autofree(vic)
	atk.wrestler_id = &"doink"
	vic.global_position = Vector2(500, 420)
	vic.receive_hit(atk, _move(AMode.PUNCH))
	assert_eq(Sound.last_sfx.get("position"), Vector2(500, 420), "impact at the victim")
	assert_eq(Sound.last_sfx.get("bus"), &"SFX")

func test_landed_hit_makes_victim_grunt():
	var atk := Fighter.new(); add_child_autofree(atk)
	var vic := Fighter.new(); add_child_autofree(vic)
	atk.wrestler_id = &"doink"; vic.wrestler_id = &"doink"
	vic.receive_hit(atk, _move(AMode.PUNCH))
	assert_eq(Sound.last_voice.get("fighter"), vic, "victim voice channel grunted")

func test_blocked_hit_plays_no_impact_or_grunt():
	var atk := Fighter.new(); add_child_autofree(atk)
	var vic := Fighter.new(); add_child_autofree(vic)
	atk.wrestler_id = &"doink"; vic.wrestler_id = &"doink"
	vic.mode = Fighter.Mode.BLOCK
	vic.receive_hit(atk, _move(AMode.PUNCH))
	assert_eq(Sound.last_sfx, {}, "blocked -> no impact")
	assert_eq(Sound.last_voice, {}, "blocked -> no pain grunt")

func test_knockdown_throw_detach_plays_body_drop():
	var atk := Fighter.new(); add_child_autofree(atk)
	var vic := Fighter.new(); add_child_autofree(vic)
	atk.wrestler_id = &"doink"
	atk._grappling = vic
	vic._grappled_by = atk
	vic.global_position = Vector2(640, 500)
	atk._player.play(_move(AMode.HAMMER, true))   # any grapple move id
	atk._detach_victim()
	assert_eq(Sound.last_sfx.get("position"), Vector2(640, 500), "body-drop at the landing spot")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `godot --headless --path . --import` then
`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_fighter_sound.gd -gexit`
Expected: FAIL — `wrestler_id` not defined / no sound fired.

- [ ] **Step 3: Add `wrestler_id` to the Fighter**

In `scripts/fighter.gd`, after the `side` export (around line 18), add:

```gdscript
## Which wrestler this fighter is (selects the per-wrestler SoundTable overrides; arcade
## WRESTLERNUM). Empty falls back to the universal default sounds.
@export var wrestler_id: StringName = &"doink"
```

- [ ] **Step 4: Fire the impact + pain grunt in `receive_hit`**

In `scripts/fighter.gd`, in `receive_hit`, the blocked branch returns early (keep it silent for
this slice). Replace the post-block tail (currently starting at `var family := AMode.reaction_for(...)`)
so the impact + grunt fire on a connecting hit:

```gdscript
	var family := AMode.reaction_for(move.attack_mode)
	# Arcade WRSND: impact SFX for the attacker's move category, at the victim. Plus the victim's
	# pain grunt on its own voice channel (one-voice-per-fighter).
	Sound.play_impact(attacker.wrestler_id, move.attack_mode, global_position)
	Sound.play_category(self, SoundCategory.PAIN)
	if family == AMode.Family.KNOCKDOWN:
		Sound.play_category(self, SoundCategory.BODY_DROP)
	_fall_orientation = Reaction.fall_orientation(family, move.id)
	var r := Reaction.resolve(family, hit_dir, move.causes_dizzy)
	_enter_reaction(r, hit_dir)
```

- [ ] **Step 5: Body-drop on throw release + grapple slam**

In `scripts/fighter.gd`, in `_detach_victim`, after `vic.mode = Mode.ONGROUND` is set and before
playing `damage_lying`, add the landing thud + grunt at the victim:

```gdscript
			Sound.play_impact(vic.wrestler_id, SoundCategory.BODY_DROP, vic.global_position)
			Sound.play_category(vic, SoundCategory.PAIN)
```

(Place these two lines inside the `if vic != null and is_instance_valid(vic):` block, right after
`vic._fall_orientation = ...` and before the `if vic.sprite != null ...` block. `play_impact` with
`BODY_DROP` resolves the default body-drop entry — `wrestler_id` has no body-drop override.)

In `_drive_victim`, in the `DAMAGE_OPP` branch (after `vic.health = ...`), add the slam impact:

```gdscript
		Sound.play_impact(vic.wrestler_id, SoundCategory.BODY_DROP, vic.global_position)
		Sound.play_category(vic, SoundCategory.PAIN)
```

- [ ] **Step 6: Run the new test + full suite**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_fighter_sound.gd -gexit`
Expected: PASS (4 tests).
Then the full suite:
`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit`
Expected: all PASS (existing fighter/combat tests unaffected — sound calls are side-effect-only).

- [ ] **Step 7: Commit**

```bash
git add scripts/fighter.gd test/unit/test_fighter_sound.gd
git commit -m "feat(audio): fire impact SFX + pain/body-drop voice from the Fighter"
```

---

## Task 9: Per-frame sounds (ANI_SOUND) — SequenceFrame + Doink specials

**Files:**
- Modify: `scripts/combat/sequence_frame.gd` (add `sound` field)
- Modify: `scripts/combat/sequence_player.gd` (surface `consume_sounds()`)
- Modify: `scripts/fighter.gd` (consume + play after `advance`)
- Create: `assets/audio/entries/doink_buzzer.tres`, `assets/audio/entries/doink_hammer.tres`
- Modify: `assets/sequences/doink/joy_buzzer.tres`, `assets/sequences/doink/hammer.tres`
- Test: `test/unit/test_sequence_player_sound.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends "res://addons/gut/test.gd"
## ANI_SOUND: a SequenceFrame can carry a SoundEntry that the player surfaces as a one-shot
## intent when the frame begins (read-and-clear, like the other consume_* intents).

func _frame(ticks: int, snd: SoundEntry = null) -> SequenceFrame:
	var f := SequenceFrame.new()
	f.duration_ticks = ticks
	f.sound = snd
	return f

func _seq(frames: Array) -> MoveSequence:
	var m := MoveSequence.new()
	var typed: Array[SequenceFrame] = []
	for f in frames:
		typed.append(f)
	m.frames = typed
	return m

func test_frame_sound_is_surfaced_then_cleared():
	var e := SoundEntry.new()
	var sp := SequencePlayer.new()
	sp.play(_seq([_frame(2, e), _frame(2, null)]))
	sp.advance(0.001)                       # begins frame 0 (has sound)
	var got := sp.consume_sounds()
	assert_eq(got, [e], "frame 0 sound surfaced")
	assert_eq(sp.consume_sounds(), [], "read-and-clear")

func test_frames_without_sound_surface_nothing():
	var sp := SequencePlayer.new()
	sp.play(_seq([_frame(2, null)]))
	sp.advance(0.001)
	assert_eq(sp.consume_sounds(), [])
```

- [ ] **Step 2: Run it to verify it fails**

Run: `godot --headless --path . --import` then
`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_sequence_player_sound.gd -gexit`
Expected: FAIL — `SequenceFrame.sound` / `consume_sounds` not defined.

- [ ] **Step 3: Add the `sound` field to SequenceFrame**

In `scripts/combat/sequence_frame.gd`, after the `wait_hit_max_ticks` export (the last `@export`),
add:

```gdscript
## ANI_SOUND: a sound to play when this frame BEGINS (effort grunt, taunt, special). Null = silent.
@export var sound: SoundEntry = null
```

- [ ] **Step 4: Surface the intent in SequencePlayer**

In `scripts/combat/sequence_player.gd`:

Add the field near the other `_pending_*` vars (after line 24, `var _opp_mode: int = 0`):

```gdscript
var _pending_sounds: Array[SoundEntry] = []   # ANI_SOUND payloads queued this advance()
```

Reset it in `play()` (alongside the other resets, after `_pending_clr_opp_mode = false`):

```gdscript
	_pending_sounds.clear()
```

Add the consume method near the other `consume_*` methods (after `consume_clr_opp_mode`):

```gdscript
## Read-and-clear the ANI_SOUND payloads that fired since the last call (may be empty).
func consume_sounds() -> Array[SoundEntry]:
	var out := _pending_sounds.duplicate()
	_pending_sounds.clear()
	return out
```

Queue the frame's sound at the TOP of `_apply_command` (which runs once per frame as it begins),
before the `match`:

```gdscript
func _apply_command(f: SequenceFrame) -> void:
	if f.sound != null:
		_pending_sounds.append(f.sound)
	match f.command:
```

- [ ] **Step 5: Run the player test to verify it passes**

Run: `godot --headless --path . --import` then
`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_sequence_player_sound.gd -gexit`
Expected: PASS (2 tests).

- [ ] **Step 6: Consume + play frame sounds in the Fighter**

In `scripts/fighter.gd`, in `_physics_process`, in the attacking branch, right after
`_player.advance(delta)` (line ~185) and before the `_grappling` drive block, add:

```gdscript
			for snd in _player.consume_sounds():
				Sound.play_entry(snd, self)
```

(Indented to match the code inside the `if _player.is_playing():` block.)

- [ ] **Step 7: Create the special SoundEntry resources**

Create `assets/audio/entries/doink_buzzer.tres` (Doink's joy-buzzer taunt voice — arcade
`ANI_SOUND,020Fh`):

```
[gd_resource type="Resource" script_class="SoundEntry" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/audio/sound_entry.gd" id="1"]
[ext_resource type="AudioStream" path="res://assets/audio/voice/doink/doink_buzzer.wav" id="2"]

[resource]
script = ExtResource("1")
streams = Array[AudioStream]([ExtResource("2")])
priority = 3
bus = &"Voice"
volume_db = 0.0
pitch_jitter = 0.0
```

Create `assets/audio/entries/doink_hammer.tres` (Doink's hammer-blow — arcade `ANI_SOUND,43h`,
an impact, so SFX bus):

```
[gd_resource type="Resource" script_class="SoundEntry" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/audio/sound_entry.gd" id="1"]
[ext_resource type="AudioStream" path="res://assets/audio/voice/doink/doink_hammer.wav" id="2"]

[resource]
script = ExtResource("1")
streams = Array[AudioStream]([ExtResource("2")])
priority = 0
bus = &"SFX"
volume_db = 0.0
pitch_jitter = 0.0
```

- [ ] **Step 8: Attach the specials to the Doink sequences**

These edits add a `sound` reference to one frame of each move. Open
`assets/sequences/doink/joy_buzzer.tres`:

1. Add an `ext_resource` for the entry near the top (after the existing `ext_resource` lines):
```
[ext_resource type="Resource" path="res://assets/audio/entries/doink_buzzer.tres" id="snd_buzzer"]
```
2. On the **first** frame `sub_resource` of type `Resource` that uses the `SequenceFrame` script
(the first `[sub_resource ...]` block), add a `sound` line, e.g.:
```
sound = ExtResource("snd_buzzer")
```

Do the same in `assets/sequences/doink/hammer.tres` with:
```
[ext_resource type="Resource" path="res://assets/audio/entries/doink_hammer.tres" id="snd_hammer"]
```
and on the frame where the hammer connects (the frame whose `command = 2` opens the attack box —
find the sub_resource with `command = 2`), add:
```
sound = ExtResource("snd_hammer")
```

Re-import so the references resolve:
```bash
godot --headless --path . --import
```

- [ ] **Step 9: Verify it loads and the full suite passes**

Run the full suite:
`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit`
Expected: all PASS, no resource-load errors for `joy_buzzer.tres` / `hammer.tres`.

- [ ] **Step 10: Commit**

```bash
git add scripts/combat/sequence_frame.gd scripts/combat/sequence_player.gd scripts/fighter.gd \
	assets/audio/entries assets/sequences/doink/joy_buzzer.tres assets/sequences/doink/hammer.tres \
	test/unit/test_sequence_player_sound.gd
git commit -m "feat(audio): ANI_SOUND per-frame sounds + Doink buzzer/hammer specials"
```

---

## Task 10: Manual verification + docs

**Files:**
- Modify: `scenes/Sandbox.tscn` (ensure Doink fighters carry `wrestler_id = &"doink"`)
- Modify: `CLAUDE.md` (note the audio system) — optional, keep brief

- [ ] **Step 1: Confirm `wrestler_id` on the Sandbox fighters**

`wrestler_id` defaults to `&"doink"` on `Fighter`, so the existing `Player1`/`Enemy`/`Enemy2`
instances already resolve Doink sounds. No scene edit is required unless you want a non-Doink id;
verify by opening `scenes/Sandbox.tscn` and confirming nothing overrides `wrestler_id`.

- [ ] **Step 2: Play the Sandbox and listen**

Run the game:
```bash
godot --path .
```
Verify by ear:
- Punching/kicking the enemy plays an **impact** thud at the enemy, with slight pitch variation.
- The struck fighter **grunts** (Doink pain), and rapid hits do not stack grunts (one voice).
- A throw/knockdown plays a **body-drop** thud where they land.
- The joy-buzzer move plays Doink's taunt; the hammer plays its blow.
- Impacts on the left/right side of the screen **pan** accordingly.

- [ ] **Step 3: Final full-suite run**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit`
Expected: all green.

- [ ] **Step 4: Commit any scene/doc tweaks**

```bash
git add -A
git commit -m "chore(audio): Sandbox wrestler_id confirm + audio system notes"
```

---

## Self-review notes (addressed)

- **Spec coverage:** buses (T1), data model `SoundEntry`/`SoundTable`/categories (T2,T4), variant pick + voice priority (T3,T5), `SoundManager` + positional + one-voice-per-fighter (T5), asset pipeline (T6,T7), three trigger paths — impact `WRSND` (T8), `ANI_SOUND` per-frame (T9), reactions/body-drop (T8) — and GUT coverage throughout. Manual audible check (T10).
- **`SoundCategory` refinement vs. spec:** the spec listed a standalone impact enum; the plan keys impacts off `move.attack_mode` directly because `AMode` already mirrors the arcade categories (DRY, and *more* faithful — the arcade indexes by move type). `SoundCategory` holds only the voice/event constants. Noted in `sound_category.gd`.
- **T1/T2 layering:** modeled as a single impact `SoundEntry` (variant pool); the effort layer rides `ANI_SOUND` (T9), per the spec's reconciliation note.
- **Type consistency:** `resolve(wrestler_id: StringName, category: int)`, `pick_stream(entry) -> AudioStream`, `play_impact/play_category/play_entry/play_voice`, `consume_sounds() -> Array[SoundEntry]`, `VoicePolicy.should_interrupt(current, new, busy)` — names used identically across tasks.
- **No real-audio dependency in tests:** all logic tests use synthetic `SoundEntry`/`AudioStreamWAV.new()`; only T7's loader test and T10 touch real assets.
