# Announcer / Play-by-Play Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an announcer that reacts to notable moments (big move / KO / near-KO) with random play-by-play lines on a dedicated high-priority channel, gated by cooldown+priority and a default-on config flag.

**Architecture:** A focused `Announcer` Node (child of the existing `Sound` autoload) owns a single non-positional `AudioStreamPlayer` on a new `Announcer` bus, a category→`SoundEntry` table (reusing `SoundTable`/`SoundEntry`), a cooldown timer, and an `enabled` flag from `ProjectSettings`. A pure `AnnouncerPolicy` decides whether a line plays. `Sound.announce(category, priority)` is the front door; `Fighter` calls it at big-hit / lethal / low-health-knockdown sites. Everything reuses the shipped headless self-mute so tests don't play real audio.

**Tech Stack:** Godot 4.6 · GDScript · GUT (headless) · `AudioStreamWAV` assets · `ProjectSettings`.

**Spec:** `docs/superpowers/specs/2026-06-01-announcer-system-design.md`

**Conventions (verified against the live codebase):**
- Pure helpers live in `scripts/audio/` with a `class_name`; the stateful `Sound` autoload is the audio hub.
- `Sound` already self-mutes when `name == &"Sound" and DisplayServer.get_name() == "headless"` (no audio device under the test runner). New playback paths MUST honor a `muted` flag the same way, recording test seams without touching the audio engine.
- Tests: `test/unit/test_<thing>.gd`, `extends "res://addons/gut/test.gd"`. The `Sound` autoload is live during tests (muted).
- After creating a new `class_name`, rebuild the class cache before running the headless runner: `godot --headless --path . --import`.
- Full suite: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit` (currently 354 passing, zero leaks — keep it that way).
- GDScript 4.6 cannot infer `:=` on some expressions (string concat, untyped-Variant returns, dynamic calls). If `--import`/run errors with "Cannot infer the type", use an explicit annotation (`var x: T = ...`). Note any such change in the report.
- The repo TRACKS `.gd.uid`, `tools/*.gd.uid`, `test/unit/*.gd.uid`, and asset `.wav.import` sidecars; it gitignores `.godot/`. After creating `.gd`/assets, `git add` the generated `.uid`/`.import` siblings too (e.g. `git add scripts/audio` stages both). `.tres` files embed their uid (no `.tres.uid`).
- Commit messages must NOT include any "Co-Authored-By: Claude" or "Generated with Claude Code" trailer.

---

## File structure

**Create:**
- `scripts/audio/announcer_policy.gd` — `class_name AnnouncerPolicy`: pure cooldown+priority decision.
- `scripts/audio/announcer.gd` — `class_name Announcer` (Node): the commentary channel, table, cooldown, enabled flag, `play()`.
- `tools/import_announcer_sounds.gd` — copy+rename the announcer WAV subset into `assets/audio/announcer/`.
- `tools/build_announcer_table.gd` — build `assets/audio/announcer_table.tres` from the imported WAVs.
- Tests: `test/unit/test_announcer_policy.gd`, `test_announcer.gd`, `test_announcer_config.gd`, `test_fighter_announcer.gd`.

**Modify:**
- `default_bus_layout.tres` — add the `Announcer` bus.
- `scripts/audio/sound_category.gd` — add `ANNC_IMPRESSIVE`/`ANNC_KO`/`ANNC_NEAR_KO`.
- `scripts/audio/sound_manager.gd` — register the ProjectSettings flag; build the `Announcer` child; `announce()` forwarder; `last_announced` seam; `is_announcer_enabled()`/`set_announcer_enabled()`.
- `scripts/fighter.gd` — `_LOW_HEALTH_THRESHOLD` const; `Sound.announce(...)` at the big-hit / lethal / low-health-knockdown sites.

---

## Task 1: Announcer bus

**Files:**
- Modify: `default_bus_layout.tres`
- Test: `test/unit/test_announcer_bus.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends "res://addons/gut/test.gd"
## The announcer routes through its own bus so its mix is independent of SFX/Voice.

func test_announcer_bus_exists_and_routes_to_master():
	var idx := AudioServer.get_bus_index("Announcer")
	assert_true(idx >= 0, "Announcer bus present")
	assert_eq(AudioServer.get_bus_send(idx), &"Master", "Announcer routes to Master")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_announcer_bus.gd -gexit`
Expected: FAIL — `get_bus_index("Announcer")` is `-1`.

- [ ] **Step 3: Add the bus**

Append to `default_bus_layout.tres` (after the `Music` bus block, lines for `bus/3/...`):

```
bus/4/name = &"Announcer"
bus/4/solo = false
bus/4/mute = false
bus/4/bypass_fx = false
bus/4/volume_db = 0.0
bus/4/send = &"Master"
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_announcer_bus.gd -gexit`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add default_bus_layout.tres test/unit/test_announcer_bus.gd test/unit/test_announcer_bus.gd.uid
git commit -m "feat(audio): Announcer bus (Master->Announcer)"
```

---

## Task 2: Announcer categories

**Files:**
- Modify: `scripts/audio/sound_category.gd`
- Test: `test/unit/test_announcer_categories.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends "res://addons/gut/test.gd"

func test_announcer_categories_above_voice_range_and_distinct():
	# voice/event cats are 100-103; announcer cats live at 200+ (no collision).
	assert_gt(SoundCategory.ANNC_IMPRESSIVE, SoundCategory.BODY_DROP)
	assert_gt(SoundCategory.ANNC_KO, SoundCategory.BODY_DROP)
	assert_gt(SoundCategory.ANNC_NEAR_KO, SoundCategory.BODY_DROP)
	var ids := [SoundCategory.ANNC_IMPRESSIVE, SoundCategory.ANNC_KO, SoundCategory.ANNC_NEAR_KO]
	var unique := {}
	for id in ids:
		unique[id] = true
	assert_eq(unique.size(), 3, "announcer categories must be distinct")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `godot --headless --path . --import` then
`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_announcer_categories.gd -gexit`
Expected: FAIL — `ANNC_IMPRESSIVE` not defined.

- [ ] **Step 3: Add the constants**

In `scripts/audio/sound_category.gd`, after the `BODY_DROP := 103` line, add:

```gdscript
# Announcer / play-by-play commentary categories (resolved against the announcer_table).
const ANNC_IMPRESSIVE := 200   # a big move landed (knockdown-family hit / throw)
const ANNC_KO := 201           # a fighter was knocked out (reached 0 health)
const ANNC_NEAR_KO := 202      # knocked down, still alive, low health ("can he get up in time")
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot --headless --path . --import` then
`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_announcer_categories.gd -gexit`
Expected: PASS (1 test).

- [ ] **Step 5: Commit**

```bash
git add scripts/audio/sound_category.gd test/unit/test_announcer_categories.gd test/unit/test_announcer_categories.gd.uid
git commit -m "feat(audio): announcer commentary categories"
```

---

## Task 3: AnnouncerPolicy (pure cooldown + priority)

**Files:**
- Create: `scripts/audio/announcer_policy.gd`
- Test: `test/unit/test_announcer_policy.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends "res://addons/gut/test.gd"
## The announcer plays a new line only when idle AND off cooldown, OR when a strictly
## higher-priority event preempts an in-progress line (preempt ignores cooldown).

func test_idle_and_off_cooldown_plays():
	assert_true(AnnouncerPolicy.should_play(0.0, false, -1, 1))

func test_idle_but_on_cooldown_drops():
	assert_false(AnnouncerPolicy.should_play(1.5, false, -1, 1))

func test_busy_equal_or_lower_drops():
	assert_false(AnnouncerPolicy.should_play(0.0, true, 2, 2), "equal while busy -> drop")
	assert_false(AnnouncerPolicy.should_play(0.0, true, 2, 1), "lower while busy -> drop")

func test_busy_higher_preempts_even_on_cooldown():
	assert_true(AnnouncerPolicy.should_play(3.0, true, 2, 3), "higher preempts despite cooldown")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_announcer_policy.gd -gexit`
Expected: FAIL — `AnnouncerPolicy` not defined.

- [ ] **Step 3: Implement**

Create `scripts/audio/announcer_policy.gd`:

```gdscript
class_name AnnouncerPolicy
## Pure decision for the single announcer channel (arcade sp_anncer priority + a talk cadence).

## Play a new line when the channel is idle AND off cooldown, OR when it strictly outranks the
## line currently playing (a higher-priority event preempts mid-sentence, ignoring cooldown).
## Equal/lower priority while busy, or any line still on cooldown while idle, is dropped.
static func should_play(cooldown_remaining: float, busy: bool, current_priority: int, new_priority: int) -> bool:
	if busy:
		return new_priority > current_priority
	return cooldown_remaining <= 0.0
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_announcer_policy.gd -gexit`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add scripts/audio/announcer_policy.gd test/unit/test_announcer_policy.gd test/unit/test_announcer_policy.gd.uid
git commit -m "feat(audio): AnnouncerPolicy cooldown+priority decision"
```

---

## Task 4: Announcer node

**Files:**
- Create: `scripts/audio/announcer.gd`
- Test: `test/unit/test_announcer.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends "res://addons/gut/test.gd"
## The Announcer resolves a category to a line, gates on enabled/cooldown/priority, and records
## the `last_announced` seam. We construct it directly (muted) — no real audio device needed.

func _entry(streams_n: int) -> SoundEntry:
	var e := SoundEntry.new()
	e.bus = &"Announcer"
	for _i in range(streams_n):
		e.streams.append(AudioStreamWAV.new())
	return e

func _table() -> SoundTable:
	var t := SoundTable.new()
	t.default = {
		SoundCategory.ANNC_IMPRESSIVE: _entry(3),
		SoundCategory.ANNC_KO: _entry(1),
	}
	return t

func _announcer() -> Announcer:
	var a := Announcer.new()
	a.muted = true                # record the seam, never touch the audio engine
	a.table = _table()
	add_child_autofree(a)         # runs _ready (builds the player), harmless while muted
	return a

func test_play_records_seam_when_enabled():
	var a := _announcer()
	assert_true(a.play(SoundCategory.ANNC_IMPRESSIVE, 2))
	assert_eq(a.last_announced.get("category"), SoundCategory.ANNC_IMPRESSIVE)
	assert_eq(a.last_announced.get("priority"), 2)
	assert_not_null(a.last_announced.get("stream"))

func test_disabled_is_noop():
	var a := _announcer()
	a.enabled = false
	a.last_announced = {}
	assert_false(a.play(SoundCategory.ANNC_KO, 3))
	assert_eq(a.last_announced, {}, "disabled -> nothing recorded")

func test_cooldown_blocks_second_equal_line():
	var a := _announcer()
	a.cooldown_seconds = 3.5
	assert_true(a.play(SoundCategory.ANNC_IMPRESSIVE, 2))
	a.last_announced = {}
	assert_false(a.play(SoundCategory.ANNC_IMPRESSIVE, 2), "still on cooldown -> drop")
	assert_eq(a.last_announced, {})

func test_cooldown_decrements_then_allows():
	var a := _announcer()
	a.cooldown_seconds = 3.5
	assert_true(a.play(SoundCategory.ANNC_KO, 3))
	a._process(4.0)               # advance past the cooldown
	assert_true(a.play(SoundCategory.ANNC_KO, 3), "off cooldown -> plays again")

func test_missing_category_returns_false():
	var a := _announcer()
	assert_false(a.play(SoundCategory.ANNC_NEAR_KO, 1), "no table entry -> nothing")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `godot --headless --path . --import` then
`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_announcer.gd -gexit`
Expected: FAIL — `Announcer` not defined.

- [ ] **Step 3: Implement**

Create `scripts/audio/announcer.gd`:

```gdscript
class_name Announcer
extends Node
## The play-by-play commentator: a single non-positional channel on the Announcer bus, highest
## priority (arcade sp_anncer). Resolves a category to a random line from the announcer table,
## gated by AnnouncerPolicy (cooldown + priority). Owned by the `Sound` autoload.

var table: SoundTable = null
var enabled := true
var muted := false                 # mirrors Sound.muted (no real playback under the headless test runner)
var cooldown_seconds := 3.5
var rng := RandomNumberGenerator.new()

var _player: AudioStreamPlayer = null
var _cooldown_left := 0.0
var _current_priority := -1

## Test seam: the last line that played/recorded ({category, priority, stream}).
var last_announced: Dictionary = {}

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = &"Announcer"
	add_child(_player)

func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)

## Try to play a commentary line for `category` at `priority`. Returns true if it played/recorded.
func play(category: int, priority: int) -> bool:
	if not enabled or table == null:
		return false
	var busy: bool = _player != null and _player.playing
	if not AnnouncerPolicy.should_play(_cooldown_left, busy, _current_priority, priority):
		return false
	var entry: SoundEntry = table.resolve(&"", category)
	var s: AudioStream = _pick(entry)
	if s == null:
		return false
	last_announced = {"category": category, "priority": priority, "stream": s}
	_cooldown_left = cooldown_seconds
	_current_priority = priority
	if muted:
		return true
	_player.stream = s
	_player.play()
	return true

## Random variant from an entry (mirrors Sound.pick_stream; the announcer owns its own rng so it
## stays unit-testable in isolation). Null-safe.
func _pick(entry: SoundEntry) -> AudioStream:
	if entry == null or entry.streams.is_empty():
		return null
	if entry.streams.size() == 1:
		return entry.streams[0]
	return entry.streams[rng.randi_range(0, entry.streams.size() - 1)]
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot --headless --path . --import` then
`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_announcer.gd -gexit`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add scripts/audio/announcer.gd scripts/audio/announcer.gd.uid test/unit/test_announcer.gd test/unit/test_announcer.gd.uid
git commit -m "feat(audio): Announcer node — channel, table, cooldown gate"
```

---

## Task 5: Wire the Announcer into the Sound autoload + config flag

**Files:**
- Modify: `scripts/audio/sound_manager.gd`
- Test: `test/unit/test_announcer_config.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends "res://addons/gut/test.gd"
## The Sound autoload registers the default-on config flag, owns an Announcer child, and forwards
## announce() to it, recording the seam. The autoload self-mutes headless, so no real playback.

func before_each():
	Sound.last_announced = {}
	Sound.set_announcer_enabled(true)

func after_all():
	Sound.set_announcer_enabled(true)

func test_config_flag_exists_and_defaults_true():
	assert_true(ProjectSettings.has_setting("wwfmania/audio/announcer_enabled"))
	assert_true(bool(ProjectSettings.get_setting("wwfmania/audio/announcer_enabled", true)))
	assert_true(Sound.is_announcer_enabled(), "announcer enabled by default")

func test_announce_records_seam():
	# Inject a tiny table so the category resolves (the real table is built in a later task).
	var e := SoundEntry.new(); e.bus = &"Announcer"; e.streams.append(AudioStreamWAV.new())
	var t := SoundTable.new(); t.default = {SoundCategory.ANNC_KO: e}
	Sound._announcer.table = t
	Sound._announcer._cooldown_left = 0.0
	Sound.announce(SoundCategory.ANNC_KO, 3)
	assert_eq(Sound.last_announced.get("category"), SoundCategory.ANNC_KO)
	assert_eq(Sound.last_announced.get("priority"), 3)

func test_disabled_announce_is_noop():
	var e := SoundEntry.new(); e.bus = &"Announcer"; e.streams.append(AudioStreamWAV.new())
	var t := SoundTable.new(); t.default = {SoundCategory.ANNC_KO: e}
	Sound._announcer.table = t
	Sound.set_announcer_enabled(false)
	Sound.last_announced = {}
	Sound.announce(SoundCategory.ANNC_KO, 3)
	assert_eq(Sound.last_announced, {}, "disabled -> no announcement")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_announcer_config.gd -gexit`
Expected: FAIL — `Sound.is_announcer_enabled` / `_announcer` / `announce` not defined.

- [ ] **Step 3: Implement the wiring**

In `scripts/audio/sound_manager.gd`:

Add constants after `const POOL_SIZE := 8`:

```gdscript
const ANNOUNCER_TABLE_PATH := "res://assets/audio/announcer_table.tres"
const ANNOUNCER_SETTING := "wwfmania/audio/announcer_enabled"
```

Add fields after `var last_voice: Dictionary = {}`:

```gdscript
var last_announced: Dictionary = {}
var _announcer: Announcer = null
```

At the END of `_ready()` (after the SFX pool loop), add the announcer setup:

```gdscript
	_register_announcer_setting()
	_announcer = Announcer.new()
	_announcer.name = "Announcer"
	_announcer.muted = muted
	_announcer.enabled = bool(ProjectSettings.get_setting(ANNOUNCER_SETTING, true))
	if ResourceLoader.exists(ANNOUNCER_TABLE_PATH):
		_announcer.table = load(ANNOUNCER_TABLE_PATH)
	add_child(_announcer)
```

Add these methods (anywhere after `_ready`, e.g. just before `pick_stream`):

```gdscript
## Ensure the default-on config flag exists and is editor-visible (BOOL). No project-file save
## at runtime — get_setting's default covers a project that never persisted it.
func _register_announcer_setting() -> void:
	if not ProjectSettings.has_setting(ANNOUNCER_SETTING):
		ProjectSettings.set_setting(ANNOUNCER_SETTING, true)
	ProjectSettings.set_initial_value(ANNOUNCER_SETTING, true)
	ProjectSettings.add_property_info({"name": ANNOUNCER_SETTING, "type": TYPE_BOOL})

## Fire a play-by-play line (front door for Fighter). No-op if the announcer is absent/disabled.
func announce(category: int, priority: int) -> void:
	if _announcer == null:
		return
	if _announcer.play(category, priority):
		last_announced = _announcer.last_announced

func is_announcer_enabled() -> bool:
	return _announcer != null and _announcer.enabled

func set_announcer_enabled(value: bool) -> void:
	if _announcer != null:
		_announcer.enabled = value
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `godot --headless --path . --import` then
`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_announcer_config.gd -gexit`
Expected: PASS (3 tests).

- [ ] **Step 5: Run the full suite (autoload change must not break anything / leak)**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit`
Expected: all prior tests still PASS; grep the output for `leaked at exit`/`still in use at exit` → 0.

- [ ] **Step 6: Commit**

```bash
git add scripts/audio/sound_manager.gd test/unit/test_announcer_config.gd test/unit/test_announcer_config.gd.uid
git commit -m "feat(audio): wire Announcer into Sound + announcer_enabled config flag"
```

---

## Task 6: Import the announcer WAV subset

**Files:**
- Create: `tools/import_announcer_sounds.gd`
- Creates assets under: `assets/audio/announcer/`

- [ ] **Step 1: Write the import tool**

Create `tools/import_announcer_sounds.gd`:

```gdscript
extends SceneTree
## One-shot asset import: copy + rename the announcer WAVs this slice needs into
## res://assets/audio/announcer. Run headless:
##   godot --headless --path . --script res://tools/import_announcer_sounds.gd
##   godot --headless --path . --import

const SRC := "/media/pablin/DATOS/JUEGOS/Wrestlemania/WWF Sources/Sounds/Comment_sound/Comment"
const DEST := "res://assets/audio/announcer"

# dest_filename : source_filename (under SRC)
const MANIFEST := {
	"impressive_01.wav": "Comment Awersome.wav",
	"impressive_02.wav": "Comment Awersome 2.wav",
	"impressive_03.wav": "Comment Boom shakalaka.wav",
	"impressive_04.wav": "Comment Did you see that.wav",
	"impressive_05.wav": "Comment Did you see that 2.wav",
	"impressive_06.wav": "Comment Unbelievable.wav",
	"impressive_07.wav": "Comment Unbelievable 2.wav",
	"impressive_08.wav": "Comment Wow.wav",
	"impressive_09.wav": "Comment Wow 2.wav",
	"impressive_10.wav": "Comment Most impressive.wav",
	"impressive_11.wav": "Comment Ka-boom.wav",
	"impressive_12.wav": "Comment Look at this.wav",
	"impressive_13.wav": "Comment I can't believe.wav",
	"impressive_14.wav": "Comment Nice execution.wav",
	"ko_01.wav": "Comment And stay down.wav",
	"ko_02.wav": "Comment Game over.wav",
	"ko_03.wav": "Comment We have a winner.wav",
	"ko_04.wav": "Comment And all.wav",
	"near_ko_01.wav": "Comment Can he get up in time.wav",
	"near_ko_02.wav": "Comment Get up!.wav",
	"near_ko_03.wav": "Comment Doink It don't look good.wav",
}

func _init() -> void:
	var copied := 0
	var missing: Array[String] = []
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST))
	for dest_name in MANIFEST:
		var src_abs: String = SRC + "/" + MANIFEST[dest_name]
		var dst_abs: String = ProjectSettings.globalize_path(DEST + "/" + dest_name)
		if not FileAccess.file_exists(src_abs):
			missing.append(src_abs)
			continue
		var err := DirAccess.copy_absolute(src_abs, dst_abs)
		if err == OK:
			copied += 1
		else:
			push_error("copy failed (%d): %s" % [err, src_abs])
	print("import_announcer_sounds: copied %d file(s)" % copied)
	if not missing.is_empty():
		push_error("import_announcer_sounds: MISSING %d:\n%s" % [missing.size(), "\n".join(missing)])
	quit(1 if not missing.is_empty() else 0)
```

- [ ] **Step 2: Run the tool, then import**

Run:
```bash
godot --headless --path . --script res://tools/import_announcer_sounds.gd
godot --headless --path . --import
```
Expected: `import_announcer_sounds: copied 21 file(s)` with no MISSING. If MISSING is reported, STOP and report (do not invent filenames).

- [ ] **Step 3: Verify the assets landed and imported**

Run:
```bash
ls assets/audio/announcer/*.wav | wc -l
ls assets/audio/announcer/*.wav.import | wc -l
```
Expected: 21 and 21.

- [ ] **Step 4: Commit**

```bash
git add tools/import_announcer_sounds.gd tools/import_announcer_sounds.gd.uid assets/audio/announcer
git commit -m "chore(audio): import announcer commentary WAV subset"
```

---

## Task 7: Build the announcer table

**Files:**
- Create: `tools/build_announcer_table.gd`
- Creates: `assets/audio/announcer_table.tres`

- [ ] **Step 1: Write the builder tool**

Create `tools/build_announcer_table.gd`:

```gdscript
extends SceneTree
## Build assets/audio/announcer_table.tres from the imported announcer WAVs. Run headless:
##   godot --headless --path . --script res://tools/build_announcer_table.gd

const OUT := "res://assets/audio/announcer_table.tres"
const DIR := "res://assets/audio/announcer"

func _load_all(names: Array) -> Array[AudioStream]:
	var out: Array[AudioStream] = []
	for n in names:
		var path: String = DIR + "/" + n
		assert(ResourceLoader.exists(path), "missing imported stream: " + path)
		out.append(load(path))
	return out

func _entry(streams: Array[AudioStream], priority: int) -> SoundEntry:
	var e := SoundEntry.new()
	e.streams = streams
	e.bus = &"Announcer"
	e.priority = priority
	e.pitch_jitter = 0.0   # speech: no pitch variation
	return e

func _init() -> void:
	var impressive := _load_all([
		"impressive_01.wav","impressive_02.wav","impressive_03.wav","impressive_04.wav",
		"impressive_05.wav","impressive_06.wav","impressive_07.wav","impressive_08.wav",
		"impressive_09.wav","impressive_10.wav","impressive_11.wav","impressive_12.wav",
		"impressive_13.wav","impressive_14.wav"])
	var ko := _load_all(["ko_01.wav","ko_02.wav","ko_03.wav","ko_04.wav"])
	var near_ko := _load_all(["near_ko_01.wav","near_ko_02.wav","near_ko_03.wav"])

	var t := SoundTable.new()
	t.default = {
		SoundCategory.ANNC_IMPRESSIVE: _entry(impressive, 2),
		SoundCategory.ANNC_KO: _entry(ko, 3),
		SoundCategory.ANNC_NEAR_KO: _entry(near_ko, 1),
	}
	var err := ResourceSaver.save(t, OUT)
	print("build_announcer_table: saved %s (err=%d)" % [OUT, err])
	quit(0 if err == OK else 1)
```

- [ ] **Step 2: Run the builder**

Run:
```bash
godot --headless --path . --script res://tools/build_announcer_table.gd
godot --headless --path . --import
```
Expected: `build_announcer_table: saved res://assets/audio/announcer_table.tres (err=0)`.

- [ ] **Step 3: Add a loader test to `test/unit/test_announcer_config.gd`, then run it**

Add this test to the END of `test/unit/test_announcer_config.gd`:

```gdscript
func test_real_announcer_table_loaded_and_resolves():
	# The autoload's _ready loaded res://assets/audio/announcer_table.tres into the Announcer.
	assert_not_null(Sound._announcer.table, "announcer_table.tres loaded")
	var ko := Sound._announcer.table.resolve(&"", SoundCategory.ANNC_KO)
	assert_not_null(ko)
	assert_eq(ko.bus, &"Announcer")
	var imp := Sound._announcer.table.resolve(&"", SoundCategory.ANNC_IMPRESSIVE)
	assert_gt(imp.streams.size(), 1, "impressive pool has variants")
```

Run:
```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_announcer_config.gd -gexit
```
Expected: PASS (4 tests now).

- [ ] **Step 4: Commit**

```bash
git add tools/build_announcer_table.gd tools/build_announcer_table.gd.uid assets/audio/announcer_table.tres test/unit/test_announcer_config.gd
git commit -m "feat(audio): build announcer_table (impressive/ko/near-ko pools)"
```

---

## Task 8: Fire announcer lines from the Fighter

**Files:**
- Modify: `scripts/fighter.gd`
- Test: `test/unit/test_fighter_announcer.gd`

- [ ] **Step 1: Write the failing test**

```gdscript
extends "res://addons/gut/test.gd"
## Big hits / KOs / low-health knockdowns fire the right announcer category (asserted via the
## Sound.last_announced seam; the autoload is muted headless).

func _move(amode: int) -> MoveSequence:
	var m := MoveSequence.new()
	m.id = "t"
	m.attack_mode = amode
	return m

func before_each():
	Sound.last_announced = {}
	Sound.set_announcer_enabled(true)
	Sound._announcer._cooldown_left = 0.0
	Sound._announcer._current_priority = -1

func test_knockdown_hit_announces_impressive():
	var atk := Fighter.new(); add_child_autofree(atk)
	var vic := Fighter.new(); add_child_autofree(vic)
	vic.health = Damage.LIFE_MAX            # healthy -> impressive, not near-ko
	vic.receive_hit(atk, _move(AMode.BIGBOOT))   # BIGBOOT -> KNOCKDOWN family
	assert_eq(Sound.last_announced.get("category"), SoundCategory.ANNC_IMPRESSIVE)

func test_lethal_hit_announces_ko():
	var atk := Fighter.new(); add_child_autofree(atk)
	var vic := Fighter.new(); add_child_autofree(vic)
	vic.health = 1                          # this blow kills
	vic.receive_hit(atk, _move(AMode.PUNCH))
	assert_eq(Sound.last_announced.get("category"), SoundCategory.ANNC_KO)

func test_low_health_knockdown_announces_near_ko():
	var atk := Fighter.new(); add_child_autofree(atk)
	var vic := Fighter.new(); add_child_autofree(vic)
	vic.health = Fighter._LOW_HEALTH_THRESHOLD    # = 48 (163*3/10); BIGBOOT deals 24 -> survives at 24
	vic.receive_hit(atk, _move(AMode.BIGBOOT))    # 24 <= 48 and alive -> near-ko
	assert_eq(Sound.last_announced.get("category"), SoundCategory.ANNC_NEAR_KO)

func test_plain_punch_does_not_announce():
	var atk := Fighter.new(); add_child_autofree(atk)
	var vic := Fighter.new(); add_child_autofree(vic)
	vic.health = Damage.LIFE_MAX
	vic.receive_hit(atk, _move(AMode.PUNCH))   # HEAD_HIT, not knockdown, not lethal
	assert_eq(Sound.last_announced, {}, "a plain punch is not commentary-worthy")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `godot --headless --path . --import` then
`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_fighter_announcer.gd -gexit`
Expected: FAIL — `Fighter._LOW_HEALTH_THRESHOLD` undefined / no announcement fired.

- [ ] **Step 3: Add the threshold constant**

In `scripts/fighter.gd`, find the combat-state constants near `health` (search for `var health: int = Damage.LIFE_MAX`). Immediately after that line add:

```gdscript
## Below this (after a knockdown) the announcer calls the near-KO suspense line. 30% of full HP.
const _LOW_HEALTH_THRESHOLD := Damage.LIFE_MAX * 3 / 10
```

- [ ] **Step 4: Add the announcer calls in `receive_hit`**

In `scripts/fighter.gd`, in `receive_hit`, the connecting-hit tail currently reads:

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

Insert the announcer block right after the `BODY_DROP` `if` block and before `_fall_orientation = ...`:

```gdscript
	# Play-by-play: KO on a lethal blow; otherwise a big (knockdown) move is impressive — unless the
	# victim is on the ropes, where the near-KO suspense line fits better. Cooldown+priority collapse
	# rapid events (the announcer self-gates).
	if is_dead():
		Sound.announce(SoundCategory.ANNC_KO, 3)
	elif family == AMode.Family.KNOCKDOWN:
		if health <= _LOW_HEALTH_THRESHOLD:
			Sound.announce(SoundCategory.ANNC_NEAR_KO, 1)
		else:
			Sound.announce(SoundCategory.ANNC_IMPRESSIVE, 2)
```

- [ ] **Step 5: Add the announcer calls on the grapple throw slam**

In `scripts/fighter.gd`, in `_drive_victim`, the `DAMAGE_OPP` branch currently reads:

```gdscript
	if _player.consume_damage_opp():
		var key: String = _player.sequence.id
		var dmg: int = Damage.GRAPPLE_DAMAGE.get(key, 20)
		vic.health = Damage.apply_health(vic.health, dmg)
		vic._last_damage_time = vic._sim_time
		Sound.play_impact(vic.wrestler_id, SoundCategory.BODY_DROP, vic.global_position)
		Sound.play_category(vic, SoundCategory.PAIN)
```

Add the announcer calls at the end of that `if` block (after the `play_category` line):

```gdscript
		if vic.is_dead():
			Sound.announce(SoundCategory.ANNC_KO, 3)
		else:
			Sound.announce(SoundCategory.ANNC_IMPRESSIVE, 2)
```

- [ ] **Step 6: Run the new test + full suite**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_fighter_announcer.gd -gexit`
Expected: PASS (4 tests).
Then the full suite:
`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit`
Expected: all PASS; grep output for `leaked at exit`/`still in use at exit` → 0.

- [ ] **Step 7: Commit**

```bash
git add scripts/fighter.gd test/unit/test_fighter_announcer.gd test/unit/test_fighter_announcer.gd.uid
git commit -m "feat(audio): fire announcer lines on big-hit / KO / near-KO"
```

---

## Task 9: Manual verification + docs

**Files:**
- Modify: `CLAUDE.md` (extend the audio architecture note)

- [ ] **Step 1: Confirm the config flag round-trips**

Run:
```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit
```
Expected: full suite green, zero leak warnings. (The `test_announcer_config.gd` tests cover the flag default + toggle.)

- [ ] **Step 2: Play the Sandbox and listen**

Run `godot --path .` and verify by ear:
- A knockdown move or throw on a healthy enemy draws an impressed call ("unbelievable!", "did you see that!").
- Finishing an enemy draws a KO line ("and stay down", "game over").
- A knockdown on a nearly-dead enemy draws the near-KO line ("can he get up in time").
- The announcer does NOT talk over every punch (cooldown), and a KO interrupts mid-chatter.
- Toggling the flag off (`Sound.set_announcer_enabled(false)` from a debug key, or flip
  `wwfmania/audio/announcer_enabled` in Project Settings) silences commentary.

- [ ] **Step 3: Extend the audio note in `CLAUDE.md`**

In `CLAUDE.md`, in the audio architecture bullet, append:

```
The announcer (`scripts/audio/announcer.gd`, a child of `Sound` on the `Announcer` bus) reacts to
big-hit / KO / near-KO events via `Sound.announce(category, priority)`, picking a random line from
`announcer_table.tres`, gated by `AnnouncerPolicy` (cooldown + priority). Gated by the
`wwfmania/audio/announcer_enabled` ProjectSettings flag (default true). Built by
`tools/build_announcer_table.gd` from `tools/import_announcer_sounds.gd`'s WAV subset.
```

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(audio): note the announcer system in CLAUDE.md"
```

---

## Self-review notes (addressed)

- **Spec coverage:** Announcer bus (T1), categories (T2), `AnnouncerPolicy` cooldown+priority (T3), `Announcer` node channel/table/gate (T4), Sound wiring + ProjectSettings flag default-on + enable/disable (T5), import (T6), generated `announcer_table.tres` (T7), Fighter hooks for IMPRESSIVE/KO/NEAR_KO (T8), manual audible check + docs (T9). Headless-mute reuse + leak checks throughout.
- **NEAR_KO vs IMPRESSIVE reachability:** made mutually exclusive by health (low-health knockdown → NEAR_KO; healthy knockdown → IMPRESSIVE) so NEAR_KO isn't permanently masked by the higher-priority IMPRESSIVE line. Documented in the spec intent (§5) and the T8 comment.
- **Priorities:** KO 3 > IMPRESSIVE 2 > NEAR_KO 1, identical in `announcer_table` entries (T7), the Fighter calls (T8), and the policy tests (T3).
- **Type consistency:** `should_play(cooldown_remaining, busy, current_priority, new_priority)`, `Announcer.play(category, priority) -> bool`, `Sound.announce(category, priority)`, `is_announcer_enabled()`/`set_announcer_enabled()`, `last_announced {category, priority, stream}`, `_LOW_HEALTH_THRESHOLD` — used identically across tasks.
- **Headless safety:** the `Announcer` honors `muted` (set from `Sound.muted` in T5), recording seams without playback — no new leaked-resource warnings (T5/T8 verify).
- **No real-audio dependency in logic tests:** T3/T4/T5/T8 use synthetic `AudioStreamWAV.new()`/injected tables; only T7's loader test and T9 touch the real assets.
