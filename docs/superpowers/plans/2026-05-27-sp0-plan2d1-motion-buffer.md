# Plan 2d-1 — Motion Buffer Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the faithful arcade input motion buffer (`wrest_joystat` + `check_secret_moves`) as standalone, unit-tested combat units, and feed it from `Player` each frame — so Plan 2d-2's grab moves can be triggered by motions (away,away+PUNCH, etc.).

**Architecture:** A per-fighter ring buffer of input *edges* (`MotionBuffer`), each entry a facing-relative bitfield + a logic-frame tick. A pure pattern matcher (`MotionMatcher`) scans newest→oldest against `{value,mask}` step lists (`MotionMove`) within a time window, tolerating bounded noise — a direct port of `check_secret_moves`. A `ChargeTracker` handles hold-then-release moves (joybuzzer). `Player` feeds the buffer from live input each `_physics_process`. The matcher/buffer/charge are scene-agnostic and tested without the `Input` singleton. **Dispatch wiring (specials-before-normals) is deliberately out of scope — it ships in 2d-2 with the grab moves it triggers.**

**Tech Stack:** Godot 4.6.3, GDScript, GUT (headless unit tests).

**Source of truth:** arcade research `docs/superpowers/research/2026-05-27-arcade-grapple-motion-buffer-deep-dive.md` §A (referred to as RESEARCH §A). Spec: `docs/superpowers/specs/2026-05-27-plan2d-grapples-design.md` §2.A.

**Conventions:**
- Tests live in `test/unit/`, file prefix `test_`, `extends "res://addons/gut/test.gd"`.
- After adding any new `class_name` script, run `godot --headless --path . --import` once before tests resolve the new global class.
- Full suite: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -gprefix=test_ -gsuffix=.gd -ginclude_subdirs -gexit`
- Single file: append `-gtest=res://test/unit/<file>.gd` to the suite command.
- Commits: conventional prefixes (`feat`/`test`/`tool`); **do not** add any Co-Authored-By trailer.

---

## File structure

**New:**
- `scripts/combat/motion_buffer.gd` — `MotionBuffer` (RefCounted): input-bit constants, the 16-entry ring, `push`, accessors, static `encode_stick`.
- `scripts/combat/motion_move.gd` — `MotionMove` (Resource): one special's `{values,masks}` step list (newest-first) + `max_ticks`.
- `scripts/combat/motion_matcher.gd` — `MotionMatcher`: pure static `matches(move, buffer, current_tick)`.
- `scripts/combat/charge_tracker.gd` — `ChargeTracker` (RefCounted): per-button held-frame counters + release detection.
- `tools/build_doink_motions.gd` — authors the grab/special `MotionMove` `.tres` from RESEARCH §A.4.
- `test/unit/test_motion_buffer.gd`, `test/unit/test_motion_matcher.gd`, `test/unit/test_charge_tracker.gd`, `test/unit/test_motion_patterns.gd`.

**Modified:**
- `scripts/arcade_units.gd` — add `LOGIC_FPS` + `ticks_to_frames`.
- `scripts/player.gd` — add `motion_buffer`, `charge`, `_input_tick`, `feed_input()`, button-mask helper; call `feed_input()` from `_physics_process`.

---

## Task 1: ArcadeUnits — arcade-ticks → logic-frames

The buffer counts in logic frames (60 Hz); motion windows (`max_ticks`) are authored in arcade ticks (53 Hz, RESEARCH §A.3). Convert once, here.

**Files:**
- Modify: `scripts/arcade_units.gd`
- Test: covered by `test/unit/test_motion_matcher.gd` Step 1 (`test_ticks_to_frames_rounds_up`), created and committed in Task 4.

- [ ] **Step 1: Add the constant + helper**

In `scripts/arcade_units.gd`, after `const TICKS_PER_SECOND: float = 53.0`:

```gdscript
## Our logic runs at Godot's fixed 60 Hz; the arcade ran at 53 ticks/s.
const LOGIC_FPS: float = 60.0

## Arcade-tick duration -> whole logic frames (round up so a window never truncates).
static func ticks_to_frames(ticks: float) -> int:
	return int(ceil(ticks * (LOGIC_FPS / TICKS_PER_SECOND)))
```

- [ ] **Step 2: No standalone test/commit**

This helper is exercised by `test_ticks_to_frames_rounds_up` (32 ticks → 37 frames: `ceil(32*60/53)=ceil(36.2)=37`) and committed together with the matcher in Task 4 Step 5.

---

## Task 2: MotionBuffer — the ring + edge encoding

**Files:**
- Create: `scripts/combat/motion_buffer.gd`
- Test: `test/unit/test_motion_buffer.gd`

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_motion_buffer.gd`:

```gdscript
extends "res://addons/gut/test.gd"

func test_encode_stick_is_facing_relative():
	# Facing right (+1): holding right = TOWARD + real RIGHT; holding left = AWAY + real LEFT.
	var right := MotionBuffer.encode_stick(Vector2.RIGHT, 1.0)
	assert_eq(right & MotionBuffer.J_TOWARD, MotionBuffer.J_TOWARD, "right while facing right = toward")
	assert_eq(right & MotionBuffer.J_RIGHT, MotionBuffer.J_RIGHT, "real screen-right bit set")
	assert_eq(right & MotionBuffer.J_AWAY, 0)
	var left := MotionBuffer.encode_stick(Vector2.LEFT, 1.0)
	assert_eq(left & MotionBuffer.J_AWAY, MotionBuffer.J_AWAY, "left while facing right = away")
	assert_eq(left & MotionBuffer.J_LEFT, MotionBuffer.J_LEFT, "real screen-left bit set")
	# Facing left (-1): holding left is now TOWARD.
	var left_facing_left := MotionBuffer.encode_stick(Vector2.LEFT, -1.0)
	assert_eq(left_facing_left & MotionBuffer.J_TOWARD, MotionBuffer.J_TOWARD, "left while facing left = toward")

func test_encode_stick_vertical():
	var down := MotionBuffer.encode_stick(Vector2.DOWN, 1.0)
	assert_eq(down & MotionBuffer.J_DOWN, MotionBuffer.J_DOWN)
	var up := MotionBuffer.encode_stick(Vector2.UP, 1.0)
	assert_eq(up & MotionBuffer.J_UP, MotionBuffer.J_UP)

func test_push_keeps_newest_at_front():
	var b := MotionBuffer.new()
	b.push(MotionBuffer.B_PUNCH, 10)
	b.push(MotionBuffer.B_KICK, 11)
	assert_eq(b.size(), 2)
	assert_eq(b.code_at(0), MotionBuffer.B_KICK, "newest at index 0")
	assert_eq(b.tick_at(0), 11)
	assert_eq(b.code_at(1), MotionBuffer.B_PUNCH)
	assert_eq(b.newest_tick(), 11)

func test_push_evicts_oldest_past_capacity():
	var b := MotionBuffer.new()
	for i in range(MotionBuffer.CAPACITY + 5):
		b.push(i, i)
	assert_eq(b.size(), MotionBuffer.CAPACITY, "ring capped at CAPACITY")
	assert_eq(b.code_at(0), MotionBuffer.CAPACITY + 4, "newest retained")
	assert_eq(b.tick_at(MotionBuffer.CAPACITY - 1), 5, "oldest retained = first not evicted")

func test_newest_tick_empty_is_negative():
	assert_eq(MotionBuffer.new().newest_tick(), -1)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -gprefix=test_ -gsuffix=.gd -ginclude_subdirs -gexit -gtest=res://test/unit/test_motion_buffer.gd`
Expected: FAIL — `MotionBuffer` is not a known class.

- [ ] **Step 3: Write the implementation**

Create `scripts/combat/motion_buffer.gd`:

```gdscript
class_name MotionBuffer
extends RefCounted
## Per-fighter rolling input-history buffer (arcade wrest_joystat, RESEARCH §A.1-A.2).
## Stores INPUT EDGES (stick changes + button-downs), newest at index 0. Joystick bits
## are facing-relative (toward/away), exactly like the arcade's #xflip_table.

const CAPACITY := 16
## Per match step, intervening unrelated entries tolerated (arcade 8-entry skip budget).
const SKIP_BUDGET := 8

# --- Input bit layout (RESEARCH §A.1). Joystick b0-3, buttons b4-8, real L/R b10-11. ---
const J_UP := 1 << 0
const J_DOWN := 1 << 1
const J_AWAY := 1 << 2
const J_TOWARD := 1 << 3
const B_PUNCH := 1 << 4
const B_BLOCK := 1 << 5
const B_SPUNCH := 1 << 6
const B_KICK := 1 << 7
const B_SKICK := 1 << 8
const J_LEFT := 1 << 10
const J_RIGHT := 1 << 11
const J_REAL_LR := J_LEFT | J_RIGHT

var _codes: Array[int] = []   # newest at index 0
var _ticks: Array[int] = []

## Build a facing-relative joystick code from an 8-way direction (no buttons).
static func encode_stick(dir: Vector2, facing: float) -> int:
	var rel := RelativeInput.resolve(dir, facing)
	var code := 0
	if rel.up: code |= J_UP
	if rel.down: code |= J_DOWN
	if rel.toward: code |= J_TOWARD
	if rel.away: code |= J_AWAY
	if dir.x < 0.0: code |= J_LEFT
	elif dir.x > 0.0: code |= J_RIGHT
	return code

## Push one input edge (newest). Evicts the oldest beyond CAPACITY.
func push(code: int, tick: int) -> void:
	_codes.push_front(code)
	_ticks.push_front(tick)
	if _codes.size() > CAPACITY:
		_codes.resize(CAPACITY)
		_ticks.resize(CAPACITY)

func size() -> int:
	return _codes.size()

func code_at(i: int) -> int:
	return _codes[i]

func tick_at(i: int) -> int:
	return _ticks[i]

func newest_tick() -> int:
	return _ticks[0] if _ticks.size() > 0 else -1

func clear() -> void:
	_codes.clear()
	_ticks.clear()
```

- [ ] **Step 4: Import + run test to verify it passes**

Run: `godot --headless --path . --import`
Then: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -gprefix=test_ -gsuffix=.gd -ginclude_subdirs -gexit -gtest=res://test/unit/test_motion_buffer.gd`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add scripts/combat/motion_buffer.gd scripts/combat/motion_buffer.gd.uid test/unit/test_motion_buffer.gd
git commit -m "feat(combat): MotionBuffer ring + facing-relative input encoding (arcade wrest_joystat)"
```

---

## Task 3: MotionMove — special pattern resource

**Files:**
- Create: `scripts/combat/motion_move.gd`
- Test: covered by Task 4 (the matcher tests construct `MotionMove` instances).

- [ ] **Step 1: Write the implementation**

Create `scripts/combat/motion_move.gd`:

```gdscript
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
```

- [ ] **Step 2: Import**

Run: `godot --headless --path . --import`
Expected: no errors (new class registers).

- [ ] **Step 3: Commit**

```bash
git add scripts/combat/motion_move.gd scripts/combat/motion_move.gd.uid
git commit -m "feat(combat): MotionMove resource ({value,mask} step list + window)"
```

---

## Task 4: MotionMatcher — the faithful scan

Direct port of `check_secret_moves` (RESEARCH §A.3): freshness gate, trigger head-noise check, newest→oldest scan with an 8-entry per-step skip budget, and the `max_ticks` window measured to the last matched entry.

**Files:**
- Create: `scripts/combat/motion_matcher.gd`
- Test: `test/unit/test_motion_matcher.gd`

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_motion_matcher.gd`:

```gdscript
extends "res://addons/gut/test.gd"

# Hip toss = PUNCH (trigger) ; AWAY ; AWAY  (newest-first), within 32 arcade ticks.
# RESEARCH §A.4: trigger masks the button cleanly (J_ALL); direction steps mask real-LR.
func _hip_toss() -> MotionMove:
	var m := MotionMove.new()
	m.move_id = "hip_toss"
	m.values = PackedInt32Array([MotionBuffer.B_PUNCH, MotionBuffer.J_AWAY, MotionBuffer.J_AWAY])
	# Trigger: require exactly PUNCH with no other joy/button noise -> mask all input bits.
	var all := MotionBuffer.J_UP | MotionBuffer.J_DOWN | MotionBuffer.J_AWAY | MotionBuffer.J_TOWARD \
		| MotionBuffer.B_PUNCH | MotionBuffer.B_BLOCK | MotionBuffer.B_SPUNCH | MotionBuffer.B_KICK | MotionBuffer.B_SKICK
	# Direction steps: match the relative direction, ignore real screen L/R bits.
	var dir_mask := MotionBuffer.J_AWAY | MotionBuffer.J_TOWARD | MotionBuffer.J_UP | MotionBuffer.J_DOWN
	m.masks = PackedInt32Array([all, dir_mask, dir_mask])
	m.max_ticks = 32
	return m

func test_ticks_to_frames_rounds_up():
	assert_eq(ArcadeUnits.ticks_to_frames(32), 37, "ceil(32*60/53)")

func test_matches_a_clean_motion_within_window():
	var b := MotionBuffer.new()
	b.push(MotionBuffer.J_AWAY | MotionBuffer.J_LEFT, 0)            # away (older)
	b.push(MotionBuffer.J_AWAY | MotionBuffer.J_LEFT, 2)            # away
	b.push(MotionBuffer.B_PUNCH, 4)                                 # PUNCH trigger (newest)
	assert_true(MotionMatcher.matches(_hip_toss(), b, 4))

func test_rejects_when_not_fresh():
	var b := MotionBuffer.new()
	b.push(MotionBuffer.J_AWAY, 0)
	b.push(MotionBuffer.J_AWAY, 2)
	b.push(MotionBuffer.B_PUNCH, 4)
	# Current tick has advanced past the trigger -> player let go a frame, no fire.
	assert_false(MotionMatcher.matches(_hip_toss(), b, 6))

func test_rejects_when_too_slow():
	var b := MotionBuffer.new()
	b.push(MotionBuffer.J_AWAY, 0)
	b.push(MotionBuffer.J_AWAY, 1)
	b.push(MotionBuffer.B_PUNCH, 100)   # PUNCH long after the aways -> outside 37-frame window
	assert_false(MotionMatcher.matches(_hip_toss(), b, 100))

func test_rejects_trigger_with_noise():
	var b := MotionBuffer.new()
	b.push(MotionBuffer.J_AWAY, 0)
	b.push(MotionBuffer.J_AWAY, 2)
	b.push(MotionBuffer.B_PUNCH | MotionBuffer.J_TOWARD, 4)   # pressed PUNCH while holding toward
	assert_false(MotionMatcher.matches(_hip_toss(), b, 4), "trigger must be a clean PUNCH")

func test_tolerates_bounded_noise_between_steps():
	var b := MotionBuffer.new()
	b.push(MotionBuffer.J_AWAY, 0)
	b.push(MotionBuffer.J_UP, 1)                  # 1 noise entry between the two aways
	b.push(MotionBuffer.J_AWAY, 2)
	b.push(MotionBuffer.B_PUNCH, 4)
	assert_true(MotionMatcher.matches(_hip_toss(), b, 4))

func test_rejects_when_step_missing():
	var b := MotionBuffer.new()
	b.push(MotionBuffer.J_AWAY, 2)                # only one AWAY, need two
	b.push(MotionBuffer.B_PUNCH, 4)
	assert_false(MotionMatcher.matches(_hip_toss(), b, 4))

func test_empty_buffer_no_match():
	assert_false(MotionMatcher.matches(_hip_toss(), MotionBuffer.new(), 0))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -gprefix=test_ -gsuffix=.gd -ginclude_subdirs -gexit -gtest=res://test/unit/test_motion_matcher.gd`
Expected: FAIL — `MotionMatcher` not defined (and `ticks_to_frames` test fails if Task 1 skipped).

- [ ] **Step 3: Write the implementation**

Create `scripts/combat/motion_matcher.gd`:

```gdscript
class_name MotionMatcher
extends RefCounted
## Faithful port of check_secret_moves (RESEARCH §A.3). Pure: no scene/Input access.

const _INPUT_MASK := 0xFFFF   # entries are 16-bit input fields

## True if `move`'s pattern is satisfied by `buffer` as of `current_tick`.
static func matches(move: MotionMove, buffer: MotionBuffer, current_tick: int) -> bool:
	var n := buffer.size()
	if n == 0 or move.step_count() == 0:
		return false
	# Freshness: a motion only fires the frame its trigger edge was pushed.
	if buffer.newest_tick() != current_tick:
		return false
	# Trigger head-noise check: the newest entry must match step 0 with no extra bits set.
	var head := buffer.code_at(0)
	if (head & (~move.masks[0] & _INPUT_MASK)) != 0:
		return false
	# Scan newest -> oldest, matching each step; tolerate up to SKIP_BUDGET noise per step.
	var entry_i := 0
	var last_match_tick := current_tick
	for step in range(move.step_count()):
		var matched := false
		var skips := 0
		while entry_i < n and skips <= MotionBuffer.SKIP_BUDGET:
			var code := buffer.code_at(entry_i)
			if (code & move.masks[step]) == move.values[step]:
				last_match_tick = buffer.tick_at(entry_i)
				entry_i += 1
				matched = true
				break
			entry_i += 1
			skips += 1
		if not matched:
			return false
	# Whole motion must lie within the window (arcade ticks -> logic frames).
	return (current_tick - last_match_tick) <= ArcadeUnits.ticks_to_frames(move.max_ticks)
```

- [ ] **Step 4: Import + run test to verify it passes**

Run: `godot --headless --path . --import`
Then: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -gprefix=test_ -gsuffix=.gd -ginclude_subdirs -gexit -gtest=res://test/unit/test_motion_matcher.gd`
Expected: PASS (8 tests).

- [ ] **Step 5: Commit**

```bash
git add scripts/arcade_units.gd scripts/combat/motion_matcher.gd scripts/combat/motion_matcher.gd.uid test/unit/test_motion_matcher.gd
git commit -m "feat(combat): MotionMatcher (check_secret_moves port) + ArcadeUnits.ticks_to_frames"
```

---

## Task 5: ChargeTracker — hold-then-release (joybuzzer)

RESEARCH §A.5: per-button held-frame counter, reset on release; a release with held-duration ≥ threshold fires. (Joybuzzer = PUNCH held ≥100 *arcade ticks* then released.)

**Files:**
- Create: `scripts/combat/charge_tracker.gd`
- Test: `test/unit/test_charge_tracker.gd`

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_charge_tracker.gd`:

```gdscript
extends "res://addons/gut/test.gd"

func test_counts_held_frames_and_reports_on_release():
	var c := ChargeTracker.new()
	var bit := MotionBuffer.B_PUNCH
	for i in range(5):
		c.update(bit)                      # PUNCH held this frame
		assert_eq(c.just_released(bit), 0, "not released while held")
	assert_eq(c.held_frames(bit), 5)
	c.update(0)                            # released
	assert_eq(c.just_released(bit), 5, "release reports frames held")
	c.update(0)
	assert_eq(c.just_released(bit), 0, "release is a one-frame edge")
	assert_eq(c.held_frames(bit), 0, "counter reset after release")

func test_charge_threshold_helper():
	var c := ChargeTracker.new()
	var bit := MotionBuffer.B_PUNCH
	var frames := ArcadeUnits.ticks_to_frames(100)   # joybuzzer threshold
	for i in range(frames):
		c.update(bit)
	c.update(0)
	assert_true(c.released_after(bit, 100), "held >= 100 arcade ticks then released")

func test_short_press_does_not_charge():
	var c := ChargeTracker.new()
	var bit := MotionBuffer.B_PUNCH
	c.update(bit)
	c.update(0)
	assert_false(c.released_after(bit, 100))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -gprefix=test_ -gsuffix=.gd -ginclude_subdirs -gexit -gtest=res://test/unit/test_charge_tracker.gd`
Expected: FAIL — `ChargeTracker` not defined.

- [ ] **Step 3: Write the implementation**

Create `scripts/combat/charge_tracker.gd`:

```gdscript
class_name ChargeTracker
extends RefCounted
## Tracks how long each button has been held; on release exposes the held duration
## for charge moves (arcade dtime counters + #charge_buzz release edge, RESEARCH §A.5).

var _held: Dictionary = {}             # button bit -> frames currently held
var _released_frames: Dictionary = {}  # button bit -> frames held at the release THIS update

## Call once per logic frame with the mask of currently-held buttons.
func update(held_mask: int) -> void:
	for bit in [MotionBuffer.B_PUNCH, MotionBuffer.B_BLOCK, MotionBuffer.B_SPUNCH,
			MotionBuffer.B_KICK, MotionBuffer.B_SKICK]:
		var was := int(_held.get(bit, 0))
		if (held_mask & bit) != 0:
			_held[bit] = was + 1
			_released_frames[bit] = 0
		else:
			_released_frames[bit] = was   # >0 only on the frame of release
			_held[bit] = 0

func held_frames(bit: int) -> int:
	return int(_held.get(bit, 0))

## Frames the button had been held at the moment it was released this frame (0 otherwise).
func just_released(bit: int) -> int:
	return int(_released_frames.get(bit, 0))

## True the frame `bit` is released after being held >= `min_arcade_ticks`.
func released_after(bit: int, min_arcade_ticks: int) -> bool:
	return just_released(bit) >= ArcadeUnits.ticks_to_frames(min_arcade_ticks)
```

- [ ] **Step 4: Import + run test to verify it passes**

Run: `godot --headless --path . --import`
Then: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -gprefix=test_ -gsuffix=.gd -ginclude_subdirs -gexit -gtest=res://test/unit/test_charge_tracker.gd`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add scripts/combat/charge_tracker.gd scripts/combat/charge_tracker.gd.uid test/unit/test_charge_tracker.gd
git commit -m "feat(combat): ChargeTracker for hold-then-release moves (joybuzzer)"
```

---

## Task 6: Player feeds the buffer each frame

Add the buffer/charge to `Player` and fill them from input *edges* every `_physics_process` (arcade `update_joystat` runs per frame, RESEARCH §A.2). `feed_input` is the testable core; `_physics_process` just supplies live input. No dispatch yet (2d-2).

**Files:**
- Modify: `scripts/player.gd`
- Test: `test/unit/test_motion_buffer_feed.gd`

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_motion_buffer_feed.gd`:

```gdscript
extends "res://addons/gut/test.gd"

# Drives Player.feed_input directly (no Input singleton) to prove edge-based filling.
func test_feed_pushes_stick_change_then_button_down():
	var p := Player.new()
	add_child_autofree(p)
	# Frame 1: hold AWAY (facing right => left stick). Stick change -> one entry.
	p.feed_input(Vector2.LEFT, 0, 1.0)
	assert_eq(p.motion_buffer.size(), 1)
	assert_eq(p.motion_buffer.code_at(0) & MotionBuffer.J_AWAY, MotionBuffer.J_AWAY)
	# Frame 2: same stick, no new button -> NO new entry (edges only).
	p.feed_input(Vector2.LEFT, 0, 1.0)
	assert_eq(p.motion_buffer.size(), 1, "held stick with no change pushes nothing")
	# Frame 3: press PUNCH while still holding AWAY -> button-down entry carries the stick.
	p.feed_input(Vector2.LEFT, MotionBuffer.B_PUNCH, 1.0)
	assert_eq(p.motion_buffer.size(), 2)
	var top := p.motion_buffer.code_at(0)
	assert_eq(top & MotionBuffer.B_PUNCH, MotionBuffer.B_PUNCH)
	assert_eq(top & MotionBuffer.J_AWAY, MotionBuffer.J_AWAY, "button entry ORs current stick")

func test_feed_advances_tick_and_feeds_charge():
	var p := Player.new()
	add_child_autofree(p)
	for i in range(3):
		p.feed_input(Vector2.ZERO, MotionBuffer.B_PUNCH, 1.0)   # hold PUNCH 3 frames
	assert_eq(p.charge.held_frames(MotionBuffer.B_PUNCH), 3)
	assert_gt(p._input_tick, 0, "tick advances each feed")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -gprefix=test_ -gsuffix=.gd -ginclude_subdirs -gexit -gtest=res://test/unit/test_motion_buffer_feed.gd`
Expected: FAIL — `feed_input`/`motion_buffer` not defined.

- [ ] **Step 3: Add the fields + feed_input to Player**

In `scripts/player.gd`, after the `@export var player_index: int = 0` line, add:

```gdscript
## Motion-input state (arcade wrest_joystat). Filled each frame by feed_input().
var motion_buffer := MotionBuffer.new()
var charge := ChargeTracker.new()
var _input_tick := 0
var _prev_stick := 0
var _prev_buttons := 0
```

Add these methods to `scripts/player.gd`:

```gdscript
## Fill the motion buffer from this frame's input EDGES (arcade update_joystat).
## stick `dir` is the 8-way direction; `buttons_held` is an OR of MotionBuffer.B_* bits.
func feed_input(dir: Vector2, buttons_held: int, facing: float) -> void:
	_input_tick += 1
	var stick := MotionBuffer.encode_stick(dir, facing)
	if stick != _prev_stick:
		motion_buffer.push(stick, _input_tick)        # stick-change edge
	var downs := buttons_held & ~_prev_buttons
	for bit in [MotionBuffer.B_PUNCH, MotionBuffer.B_BLOCK, MotionBuffer.B_SPUNCH,
			MotionBuffer.B_KICK, MotionBuffer.B_SKICK]:
		if (downs & bit) != 0:
			motion_buffer.push(bit | stick, _input_tick)   # button-down edge carries stick
	charge.update(buttons_held)
	_prev_stick = stick
	_prev_buttons = buttons_held

## OR of the attack buttons currently held (live input).
func _buttons_held_mask() -> int:
	var p := _action_prefix()
	var m := 0
	if _held(p + "punch"): m |= MotionBuffer.B_PUNCH
	if _held(p + "block"): m |= MotionBuffer.B_BLOCK
	if _held(p + "high_punch"): m |= MotionBuffer.B_SPUNCH
	if _held(p + "kick"): m |= MotionBuffer.B_KICK
	if _held(p + "high_kick"): m |= MotionBuffer.B_SKICK
	return m

func _held(action: String) -> bool:
	return InputMap.has_action(action) and Input.is_action_pressed(action)
```

- [ ] **Step 4: Call feed_input from _physics_process**

In `scripts/player.gd`, add an override of `_physics_process` that feeds the buffer then defers to the base. Insert near the other overrides:

```gdscript
func _physics_process(delta: float) -> void:
	feed_input(get_input_direction(), _buttons_held_mask(), facing())
	super(delta)
```

(`facing()` is the `Fighter` accessor; `get_input_direction()` already exists on `Player`.)

- [ ] **Step 5: Import + run the focused test**

Run: `godot --headless --path . --import`
Then: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -gprefix=test_ -gsuffix=.gd -ginclude_subdirs -gexit -gtest=res://test/unit/test_motion_buffer_feed.gd`
Expected: PASS (2 tests).

- [ ] **Step 6: Run the FULL suite (no regressions)**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -gprefix=test_ -gsuffix=.gd -ginclude_subdirs -gexit`
Expected: PASS — all prior tests (~111) still green plus the new buffer/matcher/charge/feed tests.

- [ ] **Step 7: Commit**

```bash
git add scripts/player.gd test/unit/test_motion_buffer_feed.gd
git commit -m "feat(player): feed the motion buffer + charge tracker from input each frame"
```

---

## Task 7: Author the Doink grab/special motion patterns

Produce the `MotionMove` `.tres` for the grab inputs (RESEARCH §A.4) and prove they match real buffer sequences. The patterns are pure data — the grapple *moves* they will trigger arrive in 2d-2.

**Files:**
- Create: `tools/build_doink_motions.gd`
- Create (generated): `assets/motions/doink/hip_toss.tres`, `grab_fling.tres`, `neck_grab.tres`
- Test: `test/unit/test_motion_patterns.gd`

- [ ] **Step 1: Write the authoring tool**

Create `tools/build_doink_motions.gd`:

```gdscript
extends SceneTree
## Author Doink's special-move input patterns -> res://assets/motions/doink/*.tres
## Run: godot --headless --path . -s tools/build_doink_motions.gd
## Patterns from RESEARCH §A.4 (DOINK.ASM:426-583).

const OUT := "res://assets/motions/doink"

# All input bits -> the "clean trigger" mask (J_ALL equivalent): the trigger button
# must appear with no other joy/button noise.
const ALL := MotionBuffer.J_UP | MotionBuffer.J_DOWN | MotionBuffer.J_AWAY | MotionBuffer.J_TOWARD \
	| MotionBuffer.B_PUNCH | MotionBuffer.B_BLOCK | MotionBuffer.B_SPUNCH | MotionBuffer.B_KICK | MotionBuffer.B_SKICK
# Direction steps ignore real screen L/R (J_REAL_LR), matching only the relative dir.
const DIR := MotionBuffer.J_AWAY | MotionBuffer.J_TOWARD | MotionBuffer.J_UP | MotionBuffer.J_DOWN

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	# Hip toss: PUNCH ; away ; away  (32 ticks).  DOINK.ASM:572
	_save(_motion("hip_toss", MotionBuffer.B_PUNCH, MotionBuffer.J_AWAY, MotionBuffer.J_AWAY, 32))
	# Grab & fling: SPUNCH ; away ; away  (32 ticks).  DOINK.ASM:504
	_save(_motion("grab_fling", MotionBuffer.B_SPUNCH, MotionBuffer.J_AWAY, MotionBuffer.J_AWAY, 32))
	# Neck/head grab: SPUNCH ; toward ; toward  (32 ticks).  DOINK.ASM:426
	_save(_motion("neck_grab", MotionBuffer.B_SPUNCH, MotionBuffer.J_TOWARD, MotionBuffer.J_TOWARD, 32))
	quit()

func _motion(id: String, trigger_btn: int, dir2: int, dir3: int, max_ticks: int) -> MotionMove:
	var m := MotionMove.new()
	m.move_id = id
	m.values = PackedInt32Array([trigger_btn, dir2, dir3])
	m.masks = PackedInt32Array([ALL, DIR, DIR])
	m.max_ticks = max_ticks
	return m

func _save(m: MotionMove) -> void:
	var err := ResourceSaver.save(m, OUT + "/" + m.move_id + ".tres")
	print(m.move_id, " -> ", error_string(err))
	if err != OK:
		push_error("failed saving %s: %s" % [m.move_id, error_string(err)])
		quit(1)
```

- [ ] **Step 2: Run the tool**

Run: `godot --headless --path . --import` then `godot --headless --path . -s tools/build_doink_motions.gd`
Expected: prints `hip_toss -> OK`, `grab_fling -> OK`, `neck_grab -> OK`; three `.tres` files created under `assets/motions/doink/`.

- [ ] **Step 3: Write the integration test**

Create `test/unit/test_motion_patterns.gd`:

```gdscript
extends "res://addons/gut/test.gd"
## Proves the authored .tres patterns fire on realistic edge sequences.

func _buf_double_dir_then_button(dir_bit: int, real_lr: int, btn: int) -> MotionBuffer:
	var b := MotionBuffer.new()
	b.push(dir_bit | real_lr, 1)     # first tap
	b.push(0, 2)                     # released to neutral (stick change)
	b.push(dir_bit | real_lr, 3)     # second tap
	b.push(btn, 4)                   # button trigger (clean)
	return b

func test_hip_toss_pattern_fires():
	var m: MotionMove = load("res://assets/motions/doink/hip_toss.tres")
	var b := _buf_double_dir_then_button(MotionBuffer.J_AWAY, MotionBuffer.J_LEFT, MotionBuffer.B_PUNCH)
	assert_true(MotionMatcher.matches(m, b, 4))

func test_neck_grab_pattern_fires():
	var m: MotionMove = load("res://assets/motions/doink/neck_grab.tres")
	var b := _buf_double_dir_then_button(MotionBuffer.J_TOWARD, MotionBuffer.J_RIGHT, MotionBuffer.B_SPUNCH)
	assert_true(MotionMatcher.matches(m, b, 4))

func test_hip_toss_does_not_fire_on_toward():
	var m: MotionMove = load("res://assets/motions/doink/hip_toss.tres")
	var b := _buf_double_dir_then_button(MotionBuffer.J_TOWARD, MotionBuffer.J_RIGHT, MotionBuffer.B_PUNCH)
	assert_false(MotionMatcher.matches(m, b, 4), "hip toss needs AWAY, not TOWARD")

func test_grab_fling_needs_spunch_not_punch():
	var m: MotionMove = load("res://assets/motions/doink/grab_fling.tres")
	var b := _buf_double_dir_then_button(MotionBuffer.J_AWAY, MotionBuffer.J_LEFT, MotionBuffer.B_PUNCH)
	assert_false(MotionMatcher.matches(m, b, 4), "grab-fling trigger is SPUNCH")
```

- [ ] **Step 4: Run the integration test**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -gprefix=test_ -gsuffix=.gd -ginclude_subdirs -gexit -gtest=res://test/unit/test_motion_patterns.gd`
Expected: PASS (4 tests).

- [ ] **Step 5: Run the FULL suite**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -gprefix=test_ -gsuffix=.gd -ginclude_subdirs -gexit`
Expected: PASS — everything green.

- [ ] **Step 6: Commit**

```bash
git add tools/build_doink_motions.gd assets/motions/doink/ test/unit/test_motion_patterns.gd
git commit -m "tool(combat): author Doink grab motion patterns + matcher integration tests"
```

---

## Done criteria
- `MotionBuffer`, `MotionMove`, `MotionMatcher`, `ChargeTracker` exist, unit-tested.
- `Player` fills the buffer + charge from input edges each frame; full suite green.
- Doink grab patterns (`hip_toss`, `grab_fling`, `neck_grab`) authored as `.tres` and proven to match realistic edge sequences (and reject wrong button/direction).
- **Hand-off to Plan 2d-2:** the buffer API (`motion_buffer`, `charge`, `_input_tick`) and the pattern `.tres` are ready for specials-before-normals dispatch and the grab moves they trigger.
```
