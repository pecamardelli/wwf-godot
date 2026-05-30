# Headlock Reach / Grab / Reverse Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the standing neck grab reach out to a grab window at the reach apex, freeze-and-puppet the victim into the headlock on a connect, and **reverse** the reach on a whiff or block (block adds a backward recoil) — matching the arcade `dnk_3_head_hold_anim`.

**Architecture:** Add a reverse-playback phase to `SequencePlayer` (re-plays the already-authored reach frames from the grab-window index back to 0), gated by a new `MoveSequence.reverse_reach_on_whiff` flag so throws are untouched. Add block detection in `AttackResolver` (a guarding victim routes to `notify_grab_blocked`), a backward recoil nudge in `Fighter`, and re-author the `neck_grab` sequence in the builder with the grab window mid-clip and no dropped victim frames.

**Tech Stack:** Godot 4.6 (GDScript), GUT test framework. Logic runs at 60 Hz; arcade ticks → seconds via `ArcadeUnits.ticks_to_seconds`.

**Spec:** `docs/superpowers/specs/2026-05-29-headlock-reach-grab-reverse-design.md`

**Reference (read-only):** arcade source `/home/pablin/Games/wwf-wrestlemania/DNKSEQ3.ASM:1389-1474`.

---

## File Structure

- `scripts/combat/move_sequence.gd` — add the `reverse_reach_on_whiff` flag (Task 1).
- `scripts/combat/sequence_player.gd` — reverse phase + block outcome (Tasks 2, 3).
- `scripts/combat/attack_resolver.gd` — guarding victim → block (Task 4).
- `scripts/fighter.gd` — backward recoil nudge on block (Task 5).
- `tools/build_doink_sequences.gd` — re-author `neck_grab` (Task 6).
- Tests: `test/unit/test_sequence_player_grapple.gd`, `test/unit/test_attack_resolver_grab.gd`, `test/unit/test_grapple_sequences.gd`, `test/unit/test_fighter_headhold.gd`.

**Run a single test file:**
```
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/<file>.gd -gprefix=test_ -gsuffix=.gd -gexit
```
**Run the whole suite:**
```
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -gprefix=test_ -gsuffix=.gd -ginclude_subdirs -gexit
```

---

## Task 1: `MoveSequence.reverse_reach_on_whiff` flag

**Files:**
- Modify: `scripts/combat/move_sequence.gd`
- Test: `test/unit/test_grapple_sequences.gd`

- [ ] **Step 1: Write the failing test**

Add to `test/unit/test_grapple_sequences.gd`:

```gdscript
func test_neck_grab_reverses_reach_on_whiff_flag():
	# Only the neck grab retracts the reach on a whiff/block; throws end immediately.
	var neck: MoveSequence = load("res://assets/sequences/doink/neck_grab.tres")
	assert_true(neck.reverse_reach_on_whiff, "neck grab reverses its reach on a whiff/block")
	for id in ["hip_toss", "grab_fling", "piledriver", "head_slam", "joy_buzzer"]:
		var m: MoveSequence = load("res://assets/sequences/doink/%s.tres" % id)
		assert_false(m.reverse_reach_on_whiff, "%s does NOT reverse (throws/follow-ups end on whiff)" % id)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_grapple_sequences.gd -gprefix=test_ -gsuffix=.gd -gexit`
Expected: FAIL — `Invalid get index 'reverse_reach_on_whiff'` (property does not exist yet).

- [ ] **Step 3: Add the flag**

In `scripts/combat/move_sequence.gd`, after the `is_grapple` export (around line 15):

```gdscript
## Grapple moves route their connect to attach (victim channel) rather than damage.
@export var is_grapple: bool = false
## A whiffed/blocked grab retracts the reach (plays the reach frames in reverse) instead of
## ending instantly. True only for the standing neck grab (arcade #missed/#missedb).
@export var reverse_reach_on_whiff: bool = false
```

- [ ] **Step 4: Run test to verify it (still) fails on the data, not the property**

Run the same command.
Expected: the `reverse_reach_on_whiff` accesses no longer error, but the test FAILS on `assert_true(neck.reverse_reach_on_whiff)` because the regenerated `.tres` (Task 6) hasn't set it yet. This is expected — leave it failing; Task 6 regenerates the data and turns it green. (The `assert_false` lines for throws already pass.)

- [ ] **Step 5: Commit**

```bash
git add scripts/combat/move_sequence.gd test/unit/test_grapple_sequences.gd
git commit -m "feat(combat): MoveSequence.reverse_reach_on_whiff flag (reach retract opt-in)"
```

---

## Task 2: `SequencePlayer` reverse phase on whiff

**Files:**
- Modify: `scripts/combat/sequence_player.gd`
- Test: `test/unit/test_sequence_player_grapple.gd`

- [ ] **Step 1: Write the failing test**

Add to `test/unit/test_sequence_player_grapple.gd` (the existing `_f` helper builds a frame):

```gdscript
func _reach_grab_seq() -> MoveSequence:
	# reach(0,1) -> WAIT_HIT_OPP(2) -> connected SET_ATTACH(3) -> SLAVE_ANIM(4)
	var m := MoveSequence.new(); m.id = "neck_grab"; m.anim_name = "headlocks"
	m.is_grapple = true; m.reverse_reach_on_whiff = true
	var r0 := _f(3, SequenceFrame.Command.NONE); r0.anim_frame = 0
	var r1 := _f(3, SequenceFrame.Command.NONE); r1.anim_frame = 1
	var wait := _f(3, SequenceFrame.Command.WAIT_HIT_OPP); wait.anim_frame = 2
	wait.attack_box = Box3.new(); wait.attack_box.size = Vector3(40, 60, 10); wait.wait_hit_max_ticks = 16
	var attach := _f(4, SequenceFrame.Command.SET_ATTACH); attach.anim_frame = 3; attach.slave_anim = "headlocked"
	var pull := _f(4, SequenceFrame.Command.SLAVE_ANIM); pull.anim_frame = 4; pull.slave_anim = "headlocked"
	m.frames = [r0, r1, wait, attach, pull]
	return m

func test_whiff_reverses_the_reach_to_the_start():
	var sp := SequencePlayer.new(); sp.play(_reach_grab_seq())
	for _i in range(8):   # advance through reach 0,1 into the WAIT_HIT_OPP at index 2
		sp.advance(FRAME)
	assert_true(sp.is_waiting_for_hit(), "reached the grab window")
	# Never connect. Collect the attacker frames shown after the whiff begins.
	var seen_after_whiff := []
	for _i in range(60):
		sp.advance(FRAME)
		var f: SequenceFrame = sp.current_frame()
		if sp.whiffed and f != null:
			seen_after_whiff.append(f.anim_frame)
	assert_true(sp.whiffed, "timed out without a connect")
	assert_false(sp.attack_live, "grab box dropped while the reach retracts")
	assert_false(sp.is_playing(), "the move ends after the reach has retracted")
	# The reach retracted: frames stepped DOWN from the grab window (2) toward 0.
	assert_true(seen_after_whiff.has(1), "reverse shows reach frame 1")
	assert_true(seen_after_whiff.has(0), "reverse shows reach frame 0")
	assert_true(seen_after_whiff.find(1) < seen_after_whiff.find(0), "frames descend (2->1->0)")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_sequence_player_grapple.gd -gprefix=test_ -gsuffix=.gd -gexit`
Expected: FAIL — with today's code the whiff calls `_finish()` immediately, so `seen_after_whiff` is empty and the `has(1)` assertion fails.

- [ ] **Step 3: Implement the reverse phase**

In `scripts/combat/sequence_player.gd`:

(a) Add state vars near the other `_index`/`_time_left` declarations (around line 25-29):

```gdscript
var _grab_window_index: int = -1   # frame index of the WAIT_HIT_OPP reach apex
var _reversing: bool = false       # retracting the reach after a whiff/block
var _reverse_index: int = -1       # frame shown during the reverse phase
```

(b) Reset them in `play()` (add alongside the other resets):

```gdscript
	_grab_window_index = -1
	_reversing = false
	_reverse_index = -1
```

(c) In `_apply_command`, record the index when the wait opens (in the `WAIT_HIT_OPP` branch, after it sets `_wait_left`):

```gdscript
		SequenceFrame.Command.WAIT_HIT_OPP:
			attack_live = true
			active_attack_box = f.attack_box
			_waiting_for_hit = true
			_wait_left = ArcadeUnits.ticks_to_seconds(f.wait_hit_max_ticks)
			_grab_window_index = _index
```

(d) Add the reverse helper (after `_finish`):

```gdscript
## Begin retracting the reach (whiff/block): play the reach frames from the grab window
## back to frame 0, then finish. Only when the move opts in and there IS a reach lead-in.
## Returns true if the reverse phase started (caller should NOT finish yet).
func _begin_reverse() -> bool:
	if sequence == null or not sequence.reverse_reach_on_whiff or _grab_window_index <= 0:
		return false
	_reversing = true
	_reverse_index = _grab_window_index
	attack_live = false           # the reach is retracting, not attacking
	active_attack_box = null
	_time_left = ArcadeUnits.ticks_to_seconds(sequence.frames[_reverse_index].duration_ticks)
	return true
```

(e) Handle the reverse phase at the TOP of `advance()` (right after the `if sequence == null` guard) and route the whiff timeout through `_begin_reverse`:

```gdscript
func advance(delta: float) -> bool:
	if sequence == null:
		return false
	if _reversing:
		_time_left -= delta
		while _time_left <= 0.0:
			_reverse_index -= 1
			if _reverse_index < 0:
				_finish()
				return true
			_time_left += ArcadeUnits.ticks_to_seconds(sequence.frames[_reverse_index].duration_ticks)
		return false
	if _waiting_for_hit:
		_wait_left -= delta
		if _wait_left <= 0.0:
			whiffed = true
			_waiting_for_hit = false
			if _begin_reverse():
				return false
			_finish()
			return true
		return false
```

(Leave the rest of `advance()` below this unchanged.)

(f) Make `current_frame()` return the reversed frame during the reverse phase:

```gdscript
func current_frame() -> SequenceFrame:
	if sequence == null:
		return null
	var idx: int = _reverse_index if _reversing else _index
	if idx < 0 or idx >= sequence.frames.size():
		return null
	return sequence.frames[idx]
```

(g) Reset `_reversing` in `_finish()` (add the line):

```gdscript
func _finish() -> void:
	sequence = null
	attack_live = false
	active_attack_box = null
	_index = -1
	_waiting_for_hit = false
	_reversing = false
```

- [ ] **Step 4: Run test to verify it passes**

Run the Task 2 command.
Expected: PASS — `test_whiff_reverses_the_reach_to_the_start` green.

- [ ] **Step 5: Run the existing throw whiff tests to confirm no regression**

Run the same file. The throw `_grab_seq()` has `reverse_reach_on_whiff = false`, so `_begin_reverse()` returns false and those tests keep ending immediately.
Expected: PASS — all tests in `test_sequence_player_grapple.gd` green.

- [ ] **Step 6: Commit**

```bash
git add scripts/combat/sequence_player.gd test/unit/test_sequence_player_grapple.gd
git commit -m "feat(combat): SequencePlayer reverse phase retracts the reach on a whiff"
```

---

## Task 3: `SequencePlayer` block outcome (`notify_grab_blocked`)

**Files:**
- Modify: `scripts/combat/sequence_player.gd`
- Test: `test/unit/test_sequence_player_grapple.gd`

- [ ] **Step 1: Write the failing test**

Add to `test/unit/test_sequence_player_grapple.gd`:

```gdscript
func test_block_sets_blocked_and_reverses():
	var sp := SequencePlayer.new(); sp.play(_reach_grab_seq())
	for _i in range(8):   # into the WAIT_HIT_OPP at index 2
		sp.advance(FRAME)
	assert_true(sp.is_waiting_for_hit(), "reached the grab window")
	sp.notify_grab_blocked()
	assert_true(sp.blocked, "blocked flag set")
	assert_false(sp.is_waiting_for_hit(), "released the hold on a block")
	var reversed := false
	for _i in range(60):
		sp.advance(FRAME)
		if sp.current_frame() != null and sp.current_frame().anim_frame == 0:
			reversed = true
	assert_true(reversed, "reach retracted back to frame 0 after a block")
	assert_false(sp.is_playing(), "move ends after the block reverse")
```

- [ ] **Step 2: Run test to verify it fails**

Run the Task 2 command.
Expected: FAIL — `Invalid call ... 'notify_grab_blocked'` / `Invalid get index 'blocked'`.

- [ ] **Step 3: Implement the block outcome**

In `scripts/combat/sequence_player.gd`:

(a) Add the flag near `whiffed` (around line 13):

```gdscript
var whiffed: bool = false                    # WAIT_HIT_OPP timed out with no connect
var blocked: bool = false                    # grab landed on a guarding victim (no grab)
```

(b) Reset it in `play()` (next to `whiffed = false`):

```gdscript
	whiffed = false
	blocked = false
```

(c) Add the method after `notify_grab_connected()`:

```gdscript
## Grab landed on a guarding victim: no attach. Retract the reach (if the move opts in),
## else end the move (throws). Mirrors arcade #missedb.
func notify_grab_blocked() -> void:
	if _waiting_for_hit:
		_waiting_for_hit = false
		blocked = true
		if not _begin_reverse():
			_finish()
```

- [ ] **Step 4: Run test to verify it passes**

Run the Task 2 command.
Expected: PASS — `test_block_sets_blocked_and_reverses` green and all prior tests still green.

- [ ] **Step 5: Commit**

```bash
git add scripts/combat/sequence_player.gd test/unit/test_sequence_player_grapple.gd
git commit -m "feat(combat): SequencePlayer block outcome (notify_grab_blocked -> reverse)"
```

---

## Task 4: `AttackResolver` block detection

**Files:**
- Modify: `scripts/combat/attack_resolver.gd:22-28`
- Test: `test/unit/test_attack_resolver_grab.gd`

- [ ] **Step 1: Write the failing test**

Add to `test/unit/test_attack_resolver_grab.gd`:

```gdscript
func test_grab_on_a_guarding_victim_is_blocked_not_grabbed():
	var atk := _fighter(Vector2(100, 400), Fighter.Side.PLAYER)
	var vic := _fighter(Vector2(110, 400), Fighter.Side.ENEMY)
	vic.mode = Fighter.Mode.BLOCK            # guarding -> _is_guarding() true
	atk.start_move(_grab_seq())
	atk._player.advance(1.0 / 60.0)          # open the WAIT_HIT_OPP box
	resolver.resolve_tick()
	assert_ne(vic.mode, Fighter.Mode.GRABBED, "a guarding victim is NOT grabbed")
	assert_true(atk._player.blocked, "the attacker's grab registered as blocked")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_attack_resolver_grab.gd -gprefix=test_ -gsuffix=.gd -gexit`
Expected: FAIL — today a guarding victim is grabbed (`vic.mode == GRABBED`) because `_can_be_grabbed` ignores guarding; `atk._player.blocked` is false.

- [ ] **Step 3: Implement block routing**

In `scripts/combat/attack_resolver.gd`, replace the grapple branch (lines 22-28):

```gdscript
				var move: MoveSequence = attacker.current_move()
				if move != null and move.is_grapple:
					if victim._is_guarding():
						attacker._hit_by_current_move.append(victim)   # resolve once
						attacker._player.notify_grab_blocked()
					elif _can_be_grabbed(victim):
						attacker._hit_by_current_move.append(victim)
						victim.receive_grab(attacker, move)
				else:
					victim.receive_hit(attacker, move)
```

- [ ] **Step 4: Run test to verify it passes**

Run the Task 4 command.
Expected: PASS — `test_grab_on_a_guarding_victim_is_blocked_not_grabbed` green; the existing grab/eligibility tests still green (their victims are not guarding).

- [ ] **Step 5: Commit**

```bash
git add scripts/combat/attack_resolver.gd test/unit/test_attack_resolver_grab.gd
git commit -m "feat(combat): a guarding victim blocks a grab (routes to notify_grab_blocked)"
```

---

## Task 5: `Fighter` backward recoil on block

**Files:**
- Modify: `scripts/fighter.gd` (vars near `_leap_vel`; `start_move` ~line 324; the attacking block ~line 124)
- Test: `test/unit/test_fighter_headhold.gd`

- [ ] **Step 1: Write the failing test**

Add to `test/unit/test_fighter_headhold.gd`:

```gdscript
func test_blocked_grab_recoils_the_attacker_backward():
	var atk := Fighter.new(); atk.side = Fighter.Side.PLAYER
	add_child_autofree(atk); atk.global_position = Vector2(100, 400)
	var vic := Fighter.new(); vic.side = Fighter.Side.ENEMY
	add_child_autofree(vic); vic.global_position = Vector2(140, 400)
	atk._set_facing(1.0)                      # facing right (toward the victim)
	var seq := MoveSequence.new(); seq.id = "neck_grab"; seq.is_grapple = true
	seq.anim_name = "headlocks"; seq.reverse_reach_on_whiff = true
	var wait := SequenceFrame.new(); wait.duration_ticks = 3; wait.anim_frame = 0
	wait.command = SequenceFrame.Command.WAIT_HIT_OPP
	wait.attack_box = Box3.new(); wait.attack_box.size = Vector3(40, 60, 10); wait.wait_hit_max_ticks = 16
	var r := SequenceFrame.new(); r.duration_ticks = 3; r.anim_frame = 1; r.command = SequenceFrame.Command.NONE
	# reach frame BEFORE the window so the reverse has somewhere to retract to
	seq.frames = [r, wait]
	atk.start_move(seq)
	var x0 := atk.global_position.x
	atk._player.notify_grab_blocked()         # blocked -> reverse + recoil latch
	for _i in range(20):
		atk._physics_process(1.0 / 60.0)
	assert_lt(atk.global_position.x, x0, "a blocked grab recoils the attacker backward (away from the victim)")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_fighter_headhold.gd -gprefix=test_ -gsuffix=.gd -gexit`
Expected: FAIL — no recoil yet; `global_position.x` is unchanged (the attacker holds position during the sequence).

- [ ] **Step 3: Implement the recoil**

In `scripts/fighter.gd`:

(a) Add constants + state near `_leap_vel`/`_leap_remaining` (around line 376):

```gdscript
## Block recoil (arcade #missedb ANI_SET_YVEL): our fighters are floor-clamped with no
## jump, so a blocked grab nudges the attacker straight back instead of hopping up.
const _BLOCK_RECOIL_DIST := 12.0   # px of backward recoil (tuned in playtest)
const _BLOCK_RECOIL_SPEED := 140.0 # px/s of recoil travel
var _recoil_remaining: float = 0.0
var _block_recoiled: bool = false  # latch so the recoil fires once per blocked grab
```

(b) Reset the latch in `start_move` (inside the `if move.is_grapple:` block, ~line 324):

```gdscript
	if move.is_grapple:
		_leap_remaining = _GRAPPLE_LEAP_MAX   # fresh short step-in budget for this grab
		_leap_vel = 0.0
		_recoil_remaining = 0.0
		_block_recoiled = false
```

(c) Apply the recoil in the attacking block of `_physics_process` (right after `velocity = Vector2.ZERO` at ~line 125, before the grapple-windup `if`):

```gdscript
	if _player.is_playing():
		velocity = Vector2.ZERO
		# Block recoil: a blocked grab nudges the attacker back once, away from the victim.
		if _player.blocked and not _block_recoiled:
			_block_recoiled = true
			_recoil_remaining = _BLOCK_RECOIL_DIST
		if _recoil_remaining > 0.0:
			var rstep: float = minf(_BLOCK_RECOIL_SPEED * delta, _recoil_remaining)
			global_position.x -= _facing * rstep    # _facing points at the victim; recoil away
			_recoil_remaining -= rstep
```

- [ ] **Step 4: Run test to verify it passes**

Run the Task 5 command.
Expected: PASS — `test_blocked_grab_recoils_the_attacker_backward` green.

- [ ] **Step 5: Commit**

```bash
git add scripts/fighter.gd test/unit/test_fighter_headhold.gd
git commit -m "feat(fighter): backward recoil on a blocked grab (arcade #missedb)"
```

---

## Task 6: Re-author the `neck_grab` sequence

**Files:**
- Modify: `tools/build_doink_sequences.gd:174-199` (the `_neck_grab` function + its constants)
- Regenerate: `assets/sequences/doink/neck_grab.tres`
- Test: `test/unit/test_grapple_sequences.gd`

- [ ] **Step 1: Update the sequence-shape test for the new reach/grab layout**

Replace `test_neck_grab_walks_standing_headlock_frames` in `test/unit/test_grapple_sequences.gd` with:

```gdscript
func test_neck_grab_reaches_then_grabs_mid_clip():
	# Arcade dnk_3_head_hold_anim: reach lead-in (no grab), grab window at the reach apex
	# (headlocks frame 4 = sprite 05), then puppet into the hold pose (frame 6 = sprite 07).
	var m: MoveSequence = load("res://assets/sequences/doink/neck_grab.tres")
	assert_eq(m.anim_name, "headlocks")
	assert_true(m.reverse_reach_on_whiff, "neck grab retracts on a whiff/block")
	# Lead-in frames 0-3 are plain reach (no grab command).
	for i in range(4):
		assert_eq(m.frames[i].anim_frame, i, "reach lead-in shows headlocks frame %d" % i)
		assert_eq(m.frames[i].command, SequenceFrame.Command.NONE, "reach frame %d has no grab command" % i)
	# The grab window sits at the reach apex (frame index 4).
	assert_eq(m.frames[4].command, SequenceFrame.Command.WAIT_HIT_OPP, "grab window at the reach apex")
	assert_eq(m.frames[4].anim_frame, 4, "grab window shows headlocks frame 4 (sprite 05)")
	assert_not_null(m.frames[4].attack_box, "grab window opens a grab box")
	# The connected pull-in ends on the hold pose (headlocks frame 6 = sprite 07).
	assert_eq(m.frames[m.frames.size() - 1].anim_frame, 6, "ends on the locked pose (sprite 07)")
	# A SET_ATTACH binds the victim once the grab connects.
	var has_attach := false
	for f in m.frames:
		if f.command == SequenceFrame.Command.SET_ATTACH:
			has_attach = true
	assert_true(has_attach, "binds the victim with SET_ATTACH after the connect")
	# It's a HOLD entry: no DAMAGE_OPP / DETACH (follow-ups drive those).
	for f in m.frames:
		assert_ne(f.command, SequenceFrame.Command.DAMAGE_OPP, "neck grab does not damage on entry")
		assert_ne(f.command, SequenceFrame.Command.DETACH, "neck grab does not detach on entry")
```

Also extend `test_grapple_victim_plays_every_frame` (from the prior fix) to cover the neck grab by adding `["neck_grab", "headlocked"]` to its `pair` list:

```gdscript
	for pair in [["hip_toss", "hip_tossed"], ["grab_fling", "flinged"],
			["piledriver", "piledrivered"], ["head_slam", "faceslamed"], ["joy_buzzer", "joy_buzzer"],
			["neck_grab", "headlocked"]]:
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_grapple_sequences.gd -gprefix=test_ -gsuffix=.gd -gexit`
Expected: FAIL — the current `neck_grab.tres` has the grab window at frame 0 (not 4), no `reverse_reach_on_whiff`, and drops a `headlocked` victim frame (8 onto 7 steps).

- [ ] **Step 3: Re-author `_neck_grab` in the builder**

In `tools/build_doink_sequences.gd`, replace the `NECK_STAND_FRAMES` constant and the whole `_neck_grab` function (lines 174-199) with:

```gdscript
## Neck grab (STANDING), arcade dnk_3_head_hold_anim (DNKSEQ3.ASM:1389). Reach out through
## the lead-in frames to a grab window at the reach APEX (sprite 05 = frame 4); on connect,
## puppet the victim into the locked pose (sprite 07 = frame 6); on whiff/block the reach
## retracts (reverse_reach_on_whiff). Standing portion only (sprites 01-07 = frames 0-6); the
## from-ground headlock (sprites 08-16) is a separate move, out of scope. No DAMAGE_OPP/DETACH
## — the head-hold follow-ups drive those.
const NECK_GRAB_FRAME := 4   # headlocks sprite 05: reach apex / grab window
const NECK_HOLD_FRAME := 6   # headlocks sprite 07: locked pose

func _neck_grab() -> MoveSequence:
	var m := MoveSequence.new()
	m.id = "neck_grab"; m.anim_name = "headlocks"; m.attack_mode = AMode.PUNCH
	m.is_grapple = true; m.uninterruptable = true; m.reverse_reach_on_whiff = true
	var vframes: int = maxi(_sf.get_frame_count("headlocked"), 1)
	var arr: Array[SequenceFrame] = []
	# Reach lead-in (frames 0..NECK_GRAB_FRAME-1): no victim yet, just the reach animation.
	for i in range(NECK_GRAB_FRAME):
		arr.append(_gframe(3, i, SequenceFrame.Command.NONE, "", Vector3.ZERO, 0))
	# Grab window at the reach apex.
	var gw := _gframe(3, NECK_GRAB_FRAME, SequenceFrame.Command.WAIT_HIT_OPP, "", Vector3(30, 0, 0), 0)
	gw.attack_box = _grab_box(); gw.wait_hit_max_ticks = 16
	arr.append(gw)
	# Connected pull-in: resample attacker frames [NECK_GRAB_FRAME+1 .. NECK_HOLD_FRAME] over
	# enough steps that the victim "headlocked" clip plays EVERY frame (no drop — same rule as
	# the throws). The attacker may repeat a frame; the watched victim never skips one.
	var cont_lo := NECK_GRAB_FRAME + 1   # first connected attacker frame (5)
	var cont_span := NECK_HOLD_FRAME - cont_lo   # 1
	var nc: int = maxi(cont_span + 1, vframes)
	for s in range(nc):
		var t := float(s) / float(nc - 1)
		var aimg := cont_lo + int(round(t * float(cont_span)))
		var vimg := int(round(t * float(vframes - 1)))
		var cmd := SequenceFrame.Command.SET_ATTACH if s == 0 else SequenceFrame.Command.SLAVE_ANIM
		arr.append(_gframe(4, aimg, cmd, "headlocked", Vector3(30, 0, 0), vimg))
	m.frames = arr
	return m
```

- [ ] **Step 4: Regenerate the sequences**

Run: `godot --headless --path . -s tools/build_doink_sequences.gd`
Expected: prints `neck_grab (... ticks) -> OK` among the others, no errors.

- [ ] **Step 5: Run the grapple-sequence tests to verify they pass**

Run the Task 6 command (Step 2).
Expected: PASS — `test_neck_grab_reaches_then_grabs_mid_clip`, `test_neck_grab_reverses_reach_on_whiff_flag` (from Task 1), and `test_grapple_victim_plays_every_frame` (now including neck_grab) all green.

- [ ] **Step 6: Commit**

```bash
git add tools/build_doink_sequences.gd test/unit/test_grapple_sequences.gd assets/sequences/doink/neck_grab.tres
git commit -m "feat(combat): re-author neck grab (reach -> apex grab -> puppet into hold, retract on whiff)"
```

---

## Task 7: Full suite + integration guard

**Files:**
- Test: `test/unit/test_grapple_integration.gd` (add one end-to-end check)

- [ ] **Step 1: Add an integration test for the connect path**

Read `test/unit/test_grapple_integration.gd` first to reuse its fighter/scene setup helpers, then add a test that a connected neck grab still reaches the head hold and binds the victim. Use the same setup the file already uses for grab flows (a player fighter with the `neck_grab` sequence + an enemy in range), advancing physics until the grab window opens, calling `resolver.resolve_tick()` to connect, and asserting:

```gdscript
	assert_eq(atk.mode, Fighter.Mode.HEADHOLD, "connected neck grab enters the head hold")
	assert_eq(vic.mode, Fighter.Mode.HEADHELD, "victim is held")
	assert_eq(atk._grappling, vic, "victim bound to the captor")
```

If the file has no reusable helper that opens the grab window at the apex, advance the attacker's player frame-by-frame (`atk._player.advance(1.0/60.0)`) in a loop until `atk._player.is_waiting_for_hit()` is true, then position `vic` within the grab box and call `resolver.resolve_tick()`.

- [ ] **Step 2: Run the integration file**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_grapple_integration.gd -gprefix=test_ -gsuffix=.gd -gexit`
Expected: PASS.

- [ ] **Step 3: Run the FULL suite**

Run:
```
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -gprefix=test_ -gsuffix=.gd -ginclude_subdirs -gexit
```
Expected: PASS — all tests green (no regression in fighter/headhold/sequence/scene tests). If `test_scenes.gd` or a headhold test breaks because of the new neck-grab frame layout, fix the assertion to match the new sequence shape (grab window at index 4, hold pose at frame 6).

- [ ] **Step 4: Commit**

```bash
git add test/unit/test_grapple_integration.gd
git commit -m "test(combat): end-to-end connected neck grab still enters the head hold"
```

---

## Self-Review (completed during planning)

- **Spec coverage:** reverse phase (Task 2), block outcome (Task 3), block detection (Task 4), recoil (Task 5), re-authored reach/grab/hold with no dropped victim frames (Task 6), connect-still-works integration (Task 7), throws-unchanged gate (flag in Tasks 1-2). All spec sections mapped.
- **Type consistency:** `reverse_reach_on_whiff` (MoveSequence), `blocked` + `notify_grab_blocked()` + `_begin_reverse()` + `_grab_window_index`/`_reversing`/`_reverse_index` (SequencePlayer), `_BLOCK_RECOIL_DIST`/`_BLOCK_RECOIL_SPEED`/`_recoil_remaining`/`_block_recoiled` (Fighter), `NECK_GRAB_FRAME`/`NECK_HOLD_FRAME` (builder) — names used consistently across tasks.
- **Note:** Task 1's data assertion stays red until Task 6 regenerates `neck_grab.tres`; this is called out in Task 1 Step 4 so the executor doesn't chase it.

## Post-implementation
- Visual playtest (`godot --path .`): reach → grab window → freeze → puppet into the lock reads cleanly; a missed grab retracts the reach; a blocked grab retracts + recoils. Tune `_BLOCK_RECOIL_DIST`/`_SPEED` and the reach durations to feel.
