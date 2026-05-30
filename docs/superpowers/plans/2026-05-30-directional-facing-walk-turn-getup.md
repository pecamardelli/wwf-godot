# Directional Facing, Walk, Turn-Around & Getup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the fighter a 2D facing (horizontal × depth), so it picks the correct walk/idle variant (horizontal/diagonal/vertical, front/back), plays the `rotate` turn-around pivot when facing changes (idle + walking), and runs a full two-phase getup (lie → rise) with the getup clip chosen by how it fell.

**Architecture:** Approach C (hybrid). Three new pure, unit-tested helpers — `Facing`, `RotatePlanner`, `AnimSelector` — plus a fall-orientation helper on `Reaction`. The stateful glue (depth-facing field, TURNING pivot, two-phase getup) lives in `fighter.gd`, calling the pure helpers.

**Tech Stack:** Godot 4.6 + GDScript, GUT for tests. Sprites already imported in `assets/sprites/doink/doink_frames.tres` (`rotate` = 12 frames @ 12 fps; `get_up_front/back/back_2`; all walk/idle `_front`/`_back` variants).

**Spec:** `docs/superpowers/specs/2026-05-30-directional-facing-walk-turn-getup-design.md`
**Arcade source of truth:** `/home/pablin/Games/wwf-wrestlemania`.

**Run all tests:**
```bash
GODOT=/home/pablin/.local/bin/godot
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit
```
**Run one test file:** add `-gtest=res://test/unit/test_NAME.gd` (drop `-gconfig`).

---

## File Structure

- Create `scripts/facing.gd` (`class_name Facing`) — 2D facing model + desired-depth rule.
- Create `scripts/rotate_planner.gd` (`class_name RotatePlanner`) — `rotate` frame list between two states.
- Create `scripts/anim_selector.gd` (`class_name AnimSelector`) — walk/idle anim name from movement + depth.
- Modify `scripts/combat/reaction.gd` — add `fall_orientation()`.
- Modify `scripts/fighter.gd` — `Fall` enum, `_depth_facing`, turn-around pivot, directional anim, two-phase getup.
- Create `test/unit/test_facing.gd`, `test/unit/test_rotate_planner.gd`, `test/unit/test_anim_selector.gd`.
- Modify `test/unit/test_reaction.gd`, `test/unit/test_fighter_control.gd`.
- Add tests to `test/unit/test_fighter_movement.gd` (turn + getup integration).

---

## Task 1: `Facing` — 2D facing model

**Files:**
- Create: `scripts/facing.gd`
- Test: `test/unit/test_facing.gd`

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_facing.gd`:
```gdscript
extends "res://addons/gut/test.gd"

func test_state_of_maps_four_corners():
	assert_eq(Facing.state_of(1.0, Facing.FRONT), Facing.State.FR)
	assert_eq(Facing.state_of(1.0, Facing.BACK), Facing.State.BR)
	assert_eq(Facing.state_of(-1.0, Facing.BACK), Facing.State.BL)
	assert_eq(Facing.state_of(-1.0, Facing.FRONT), Facing.State.FL)

func test_horizontal_of_state():
	assert_eq(Facing.horizontal_of(Facing.State.FR), 1.0)
	assert_eq(Facing.horizontal_of(Facing.State.BR), 1.0)
	assert_eq(Facing.horizontal_of(Facing.State.BL), -1.0)
	assert_eq(Facing.horizontal_of(Facing.State.FL), -1.0)

func test_depth_of_state():
	assert_eq(Facing.depth_of(Facing.State.FR), Facing.FRONT)
	assert_eq(Facing.depth_of(Facing.State.FL), Facing.FRONT)
	assert_eq(Facing.depth_of(Facing.State.BR), Facing.BACK)
	assert_eq(Facing.depth_of(Facing.State.BL), Facing.BACK)

func test_desired_depth_front_when_opponent_nearer_camera():
	# larger screen Y = nearer the camera = FRONT
	assert_eq(Facing.desired_depth(400.0, 500.0), Facing.FRONT)
	assert_eq(Facing.desired_depth(400.0, 300.0), Facing.BACK)

func test_desired_depth_hysteresis_keeps_current_inside_deadzone():
	assert_eq(Facing.desired_depth(400.0, 410.0, Facing.BACK, 24.0), Facing.BACK)
	assert_eq(Facing.desired_depth(400.0, 430.0, Facing.BACK, 24.0), Facing.FRONT)
	assert_eq(Facing.desired_depth(400.0, 370.0, Facing.FRONT, 24.0), Facing.BACK)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_facing.gd -gexit`
Expected: FAIL — `Facing` not found / class missing.

- [ ] **Step 3: Write minimal implementation**

Create `scripts/facing.gd`:
```gdscript
class_name Facing
## 2D facing: horizontal (±1) × depth (FRONT/BACK). The combined orientation is one of
## four corners, ordered to match the `rotate` clip cycle FR→BR→BL→FL→FR.

const FRONT := 1   # facing toward the camera (opponent nearer / larger screen Y)
const BACK := -1   # facing away from the camera

enum State { FR, BR, BL, FL }

## (horizontal ±1, depth FRONT/BACK) -> State.
static func state_of(horizontal: float, depth: int) -> int:
	var right := horizontal >= 0.0
	if depth == FRONT:
		return State.FR if right else State.FL
	return State.BR if right else State.BL

## State -> horizontal facing (±1).
static func horizontal_of(state: int) -> float:
	return 1.0 if (state == State.FR or state == State.BR) else -1.0

## State -> depth (FRONT/BACK).
static func depth_of(state: int) -> int:
	return FRONT if (state == State.FR or state == State.FL) else BACK

## Depth toward an opponent. FRONT when the opponent is nearer the camera (larger screen Y),
## BACK when farther. `deadzone` adds hysteresis: within it, keep `current` (anti-jitter when
## the two fighters are roughly level in depth).
static func desired_depth(self_y: float, opp_y: float, current: int = FRONT, deadzone: float = 0.0) -> int:
	var d := opp_y - self_y
	if d > deadzone:
		return FRONT
	if d < -deadzone:
		return BACK
	return current
```

- [ ] **Step 4: Run test to verify it passes**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_facing.gd -gexit`
Expected: PASS (all asserts).

- [ ] **Step 5: Commit**

```bash
git add scripts/facing.gd test/unit/test_facing.gd
git commit -m "feat(facing): 2D facing model (horizontal × depth) with depth hysteresis"
```

---

## Task 2: `RotatePlanner` — turn-around frame planning

**Files:**
- Create: `scripts/rotate_planner.gd`
- Test: `test/unit/test_rotate_planner.gd`

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_rotate_planner.gd`:
```gdscript
extends "res://addons/gut/test.gd"

func test_no_turn_when_same_state():
	assert_eq(RotatePlanner.plan(Facing.State.FR, Facing.State.FR), [])

func test_one_segment_forward():
	# FR -> BR uses the first forward segment
	assert_eq(RotatePlanner.plan(Facing.State.FR, Facing.State.BR), [2, 3, 4])
	# FL -> FR is the wrap segment
	assert_eq(RotatePlanner.plan(Facing.State.FL, Facing.State.FR), [11, 0, 1])

func test_one_segment_backward_is_reversed():
	# FR -> FL is shorter going backward (reverse the FL->FR segment)
	assert_eq(RotatePlanner.plan(Facing.State.FR, Facing.State.FL), [1, 0, 11])
	# BR -> FR backward reverses the FR->BR segment
	assert_eq(RotatePlanner.plan(Facing.State.BR, Facing.State.FR), [4, 3, 2])

func test_opposite_corner_takes_two_segments_forward_on_tie():
	# FR -> BL: forward and backward are both 2 segments -> tie picks forward
	assert_eq(RotatePlanner.plan(Facing.State.FR, Facing.State.BL), [2, 3, 4, 5, 6, 7])
	assert_eq(RotatePlanner.plan(Facing.State.BL, Facing.State.FR), [8, 9, 10, 11, 0, 1])
```

- [ ] **Step 2: Run test to verify it fails**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_rotate_planner.gd -gexit`
Expected: FAIL — `RotatePlanner` not found.

- [ ] **Step 3: Write minimal implementation**

Create `scripts/rotate_planner.gd`:
```gdscript
class_name RotatePlanner
## Plan the `rotate` clip frame list (0-indexed) to pivot between two Facing.State corners,
## along the shorter arc of the 4-cycle FR→BR→BL→FL→FR. Each adjacent step is one segment.
## Frame map (from the imported 12-frame `rotate` clip):
##   FR→BR [2,3,4]  BR→BL [5,6,7]  BL→FL [8,9,10]  FL→FR [11,0,1]
## Going backward reverses the segment that would be traversed forward.

const _SEG := [[2, 3, 4], [5, 6, 7], [8, 9, 10], [11, 0, 1]]

static func plan(from_state: int, to_state: int) -> Array:
	if from_state == to_state:
		return []
	var fwd := (to_state - from_state + 4) % 4
	var bwd := 4 - fwd
	var frames: Array = []
	if fwd <= bwd:
		for k in range(fwd):
			frames.append_array(_SEG[(from_state + k) % 4])
	else:
		for k in range(bwd):
			var s := (from_state - k + 4) % 4
			var seg: Array = _SEG[(s - 1 + 4) % 4].duplicate()
			seg.reverse()
			frames.append_array(seg)
	return frames
```

- [ ] **Step 4: Run test to verify it passes**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_rotate_planner.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/rotate_planner.gd test/unit/test_rotate_planner.gd
git commit -m "feat(rotate): plan the turn-around clip frames along the shorter arc"
```

---

## Task 3: `AnimSelector` — directional walk/idle name

**Files:**
- Create: `scripts/anim_selector.gd`
- Test: `test/unit/test_anim_selector.gd`

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_anim_selector.gd`:
```gdscript
extends "res://addons/gut/test.gd"

func test_idle_when_no_movement():
	assert_eq(AnimSelector.walk_anim(Vector2.ZERO, Facing.FRONT), "idle_front")
	assert_eq(AnimSelector.walk_anim(Vector2.ZERO, Facing.BACK), "idle_back")

func test_horizontal_only():
	assert_eq(AnimSelector.walk_anim(Vector2(1, 0), Facing.FRONT), "walk_horisontal_front")
	assert_eq(AnimSelector.walk_anim(Vector2(-1, 0), Facing.BACK), "walk_horisontal_back")

func test_vertical_only():
	assert_eq(AnimSelector.walk_anim(Vector2(0, 1), Facing.FRONT), "walk_vertical_front")
	assert_eq(AnimSelector.walk_anim(Vector2(0, -1), Facing.BACK), "walk_vertical_back")

func test_diagonal():
	assert_eq(AnimSelector.walk_anim(Vector2(1, 1), Facing.FRONT), "walk_diagonal_front")
	assert_eq(AnimSelector.walk_anim(Vector2(-1, -1), Facing.BACK), "walk_diagonal_back")

func test_uses_sign_only():
	assert_eq(AnimSelector.walk_anim(Vector2(0.2, 0.0), Facing.FRONT), "walk_horisontal_front")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_anim_selector.gd -gexit`
Expected: FAIL — `AnimSelector` not found.

- [ ] **Step 3: Write minimal implementation**

Create `scripts/anim_selector.gd`:
```gdscript
class_name AnimSelector
## Pick the walk/idle animation base name from movement input + depth facing.
## Type comes from the movement axes (arcade legs key off MOVE_DIR); the _front/_back
## suffix comes from the depth facing. Horizontal flip is applied separately by
## Fighter.flip_h_for (idle/walk art is right-drawn). The `rotate` and `run` clips are
## handled by the fighter directly, not here.

static func walk_anim(move_dir: Vector2, depth: int) -> String:
	var suffix := "_front" if depth == Facing.FRONT else "_back"
	var ix := signf(move_dir.x)
	var iy := signf(move_dir.y)
	if ix == 0.0 and iy == 0.0:
		return "idle" + suffix
	if ix != 0.0 and iy != 0.0:
		return "walk_diagonal" + suffix
	if iy != 0.0:
		return "walk_vertical" + suffix
	return "walk_horisontal" + suffix
```

- [ ] **Step 4: Run test to verify it passes**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_anim_selector.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/anim_selector.gd test/unit/test_anim_selector.gd
git commit -m "feat(anim): directional walk/idle name selection (type × depth)"
```

---

## Task 4: `Reaction.fall_orientation` + `Fighter.Fall`

The getup clip is chosen by how the wrestler fell. The orientation enum lives on `Fighter`;
the move→orientation lookup is a pure function on `Reaction`.

**Files:**
- Modify: `scripts/fighter.gd` (add `Fall` enum near `Mode`)
- Modify: `scripts/combat/reaction.gd`
- Modify: `test/unit/test_reaction.gd`

- [ ] **Step 1: Add the `Fall` enum to `fighter.gd`**

In `scripts/fighter.gd`, immediately after the `Mode` enum + `var mode` (line 8-9), add:
```gdscript
## How a wrestler landed when knocked down — selects the getup clip.
## FACE_UP = on its back (get_up_front); FACE_DOWN = face/back-turned (get_up_back);
## FACE_DOWN_ROLL = slammed/rolled face-first (get_up_back_2).
enum Fall { FACE_UP, FACE_DOWN, FACE_DOWN_ROLL }
```

- [ ] **Step 2: Write the failing test**

Append to `test/unit/test_reaction.gd`:
```gdscript
func test_fall_orientation_defaults_face_up():
	assert_eq(Reaction.fall_orientation(AMode.Family.KNOCKDOWN, "big_boot"), Fighter.Fall.FACE_UP)
	assert_eq(Reaction.fall_orientation(AMode.Family.FALL_BACK, "uppercut"), Fighter.Fall.FACE_UP)

func test_fall_orientation_roll_moves_are_face_down_roll():
	assert_eq(Reaction.fall_orientation(AMode.Family.KNOCKDOWN, "faceslam"), Fighter.Fall.FACE_DOWN_ROLL)
	assert_eq(Reaction.fall_orientation(AMode.Family.KNOCKDOWN, "flying_clothesline"), Fighter.Fall.FACE_DOWN_ROLL)
```

- [ ] **Step 3: Run test to verify it fails**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_reaction.gd -gexit`
Expected: FAIL — `fall_orientation` not defined.

- [ ] **Step 4: Implement `fall_orientation`**

Append to `scripts/combat/reaction.gd`:
```gdscript
## Moves that drop the victim face-first (slam / roll) -> get_up_back_2. Everything else is
## a face-up knockdown (lands on the back) -> get_up_front. Arcade parallel: #getup_tbl
## defaults to *_faceup_getup_anim, with *_facedown_getup_anim for face-down falls
## (REACT1.ASM, ADMSEQ2.ASM #choose_dir). Seed list is forward-looking — add slam/roll
## finishers here as they get wired; verify against the art in playtest.
const _ROLL_FALL_MOVES := {"flying_clothesline": true, "faceslam": true}

static func fall_orientation(_family: int, move_id: String) -> int:
	if _ROLL_FALL_MOVES.has(move_id):
		return Fighter.Fall.FACE_DOWN_ROLL
	return Fighter.Fall.FACE_UP
```

- [ ] **Step 5: Run test to verify it passes**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_reaction.gd -gexit`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add scripts/fighter.gd scripts/combat/reaction.gd test/unit/test_reaction.gd
git commit -m "feat(getup): Fall orientation enum + move→orientation lookup"
```

---

## Task 5: Fighter — depth facing field + orientation snap

Introduce `_depth_facing` and make every non-locomotion state snap BOTH axes toward the
target (so control returns with a consistent orientation and no spurious pivot). Free NORMAL
idle/walk facing is left for Task 6's pivot; running sets its own facing (add depth there).

**Files:**
- Modify: `scripts/fighter.gd`

- [ ] **Step 1: Add the depth-facing field**

In `scripts/fighter.gd`, right after `var _facing: float = 1.0 ...` (line 45), add:
```gdscript
var _depth_facing: int = Facing.FRONT   # FRONT = toward camera, BACK = away (Y-depth facing)
```

- [ ] **Step 2: Replace the top facing-snap block**

Replace the current continuous-facing block (the `if target != null ... _set_facing(...)`
two lines just after `_update_target()`, ~line 106-107) with:
```gdscript
	# Orientation. Free NORMAL idle/walk is animated by the turn-around pivot (Task 6);
	# every other state snaps BOTH axes toward the target so control returns already facing
	# correctly (no spurious pivot). Running sets its own facing below; guarding freezes it.
	var controlling: bool = Fighter.input_allowed(mode) and not _player.is_playing() \
			and _react_timer <= 0.0 and not _is_guarding()
	if not controlling and not _is_guarding() and target != null and is_instance_valid(target) \
			and (_grappling == null or not _player.is_playing()):
		_set_facing(target.global_position.x - global_position.x)
		_depth_facing = Facing.desired_depth(global_position.y, target.global_position.y)
```

- [ ] **Step 3: Add depth to the run branch**

In the run branch, the `else:` that calls `_set_facing(_run_dir_x)` (~line 208), add a depth
line so running keys depth off the vertical run input (arcade run depth-drift):
```gdscript
			else:
				_set_facing(_run_dir_x)   # face the run direction (no moonwalk)
				if signf(dir.y) != 0.0:
					_depth_facing = Facing.FRONT if dir.y > 0.0 else Facing.BACK
				var run_vel := Vector2(_run_dir_x * ArcadeUnits.RUN_SPEED, signf(dir.y) * ArcadeUnits.RUN_DEPTH_DRIFT)
				velocity = velocity.move_toward(run_vel, walk_acceleration * delta)
```

- [ ] **Step 4: Run the control + movement suites to verify still green**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_fighter_control.gd -gexit`
Then: `... -gtest=res://test/unit/test_fighter_movement.gd -gexit`
Expected: PASS. (No target in movement tests → no behaviour change; control tests still snap
during attacks/blocks. `test_faces_target_continuously` still passes here because Task 6's
pivot is not added yet — it is edited in Task 6.)

- [ ] **Step 5: Commit**

```bash
git add scripts/fighter.gd
git commit -m "feat(facing): depth-facing field + snap orientation in non-locomotion states"
```

---

## Task 6: Fighter — turn-around pivot (TURNING)

While idle OR walking, if facing must change, play the `rotate` clip (manually, fixed
cadence) instead of moving; commit the new facing on the last frame.

**Files:**
- Modify: `scripts/fighter.gd`
- Modify: `test/unit/test_fighter_control.gd`
- Add test: `test/unit/test_fighter_movement.gd`

- [ ] **Step 1: Add turn state + helpers to `fighter.gd`**

After the `_depth_facing` field, add the turn state:
```gdscript
const _TURN_FRAME_TICKS := 4          # arcade rotate cadence (~4 ticks/frame)
const _DEPTH_DEADZONE := 24.0         # px of Y separation before flipping front/back
var _turning: bool = false
var _turn_frames: Array = []
var _turn_idx: int = 0
var _turn_dest: int = Facing.State.FR
var _turn_accum: float = 0.0
```

Add these methods (place them near `_update_facing`, after `_set_facing`):
```gdscript
## Desired facing corner this tick, from the target (horizontal side + depth, with
## hysteresis). Caller guarantees a valid target.
func _desired_facing_state() -> int:
	var h: float = signf(target.global_position.x - global_position.x)
	if h == 0.0:
		h = _facing
	var d: int = Facing.desired_depth(global_position.y, target.global_position.y, _depth_facing, _DEPTH_DEADZONE)
	return Facing.state_of(h, d)

## Commit a finished pivot: adopt the destination corner's facing + depth.
func _commit_facing_state(state: int) -> void:
	_facing = Facing.horizontal_of(state)
	_depth_facing = Facing.depth_of(state)
	_refresh_flip()

## Show one frame of the `rotate` clip (driven manually, never mirrored — the clip is drawn
## for all four corners).
func _show_rotate_frame(frame: int) -> void:
	if sprite == null or sprite.sprite_frames == null or not sprite.sprite_frames.has_animation("rotate"):
		return
	sprite.animation = "rotate"
	sprite.pause()
	var last: int = sprite.sprite_frames.get_frame_count("rotate") - 1
	sprite.frame = clampi(frame, 0, maxi(last, 0))
	sprite.flip_h = false
	sprite.offset = Vector2.ZERO

## Hold position for a tick (no walk): used by the pivot and the getup phases.
func _hold_in_place() -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	global_position = MovementMath.clamp_to_floor(global_position, floor_min_y, floor_max_y)

## Turn-around pivot. While idle or walking, if facing must change, play the `rotate` clip
## instead of moving; commit the new facing on the last frame. Returns true while turning
## (caller skips walking this tick). Attacks/grapples/reactions/running never call this.
func _service_turn(delta: float) -> bool:
	var per: float = ArcadeUnits.ticks_to_seconds(_TURN_FRAME_TICKS)
	if _turning:
		_turn_accum += delta
		while _turn_accum >= per and _turn_idx < _turn_frames.size() - 1:
			_turn_accum -= per
			_turn_idx += 1
		_show_rotate_frame(_turn_frames[_turn_idx])
		if _turn_idx >= _turn_frames.size() - 1:
			_commit_facing_state(_turn_dest)
			_turning = false
		_hold_in_place()
		return true
	if target == null or not is_instance_valid(target):
		return false
	var des: int = _desired_facing_state()
	if des == Facing.state_of(_facing, _depth_facing):
		return false
	_turn_frames = RotatePlanner.plan(Facing.state_of(_facing, _depth_facing), des)
	if _turn_frames.is_empty():
		return false
	_turning = true
	_turn_dest = des
	_turn_idx = 0
	_turn_accum = 0.0
	_show_rotate_frame(_turn_frames[0])
	_hold_in_place()
	return true
```

- [ ] **Step 2: Gate the walk path on the pivot**

In the normal-movement section, inside the `if mode != Mode.RUNNING:` block (the one that
builds `walk_vel`, ~line 211), add the pivot gate as the FIRST thing in that block:
```gdscript
		if mode != Mode.RUNNING:
			# Turn-around pivot (idle + walking): if facing must change, play the rotate
			# clip this tick instead of walking.
			if _service_turn(delta):
				return
			var walk_vel: Vector2 = MovementMath.walk_velocity(dir) * walk_speed_scale
```

- [ ] **Step 3: Update the existing facing test (idle now pivots)**

In `test/unit/test_fighter_control.gd`, replace `test_faces_target_continuously` with:
```gdscript
func test_faces_target_continuously():
	var me := _at(100, Fighter.Side.PLAYER)
	var enemy := _at(300, Fighter.Side.ENEMY)   # to the right, same depth -> no turn needed
	me._physics_process(FRAME)
	assert_eq(me.facing(), 1.0, "faces right toward the right-side target")
	enemy.global_position.x = -50               # move target to the left -> pivot around
	for _i in range(30):
		me._physics_process(FRAME)              # let the turn-around pivot complete
	assert_eq(me.facing(), -1.0, "pivots around to keep facing the target")
```

- [ ] **Step 4: Write the pivot integration test**

Append to `test/unit/test_fighter_movement.gd`:
```gdscript
func _at_xy(x: float, y: float, side: int) -> Fighter:
	var f := Fighter.new()
	add_child_autofree(f)
	f.global_position = Vector2(x, y)
	f.side = side
	f.separation_radii = Vector2.ZERO
	return f

func test_depth_facing_pivots_to_back_when_target_behind():
	var me := _at_xy(100, 400, Fighter.Side.PLAYER)
	# target far above (smaller Y = behind in depth) and to the right
	var enemy := _at_xy(140, 200, Fighter.Side.ENEMY)
	for _i in range(40):
		me._physics_process(FRAME)
	assert_eq(me._depth_facing, Facing.BACK, "turns to face the behind/up target (back view)")
	assert_eq(me.facing(), 1.0, "still horizontally facing the right-side target")

func test_no_pivot_when_already_facing_target():
	var me := _at_xy(100, 400, Fighter.Side.PLAYER)
	var enemy := _at_xy(300, 500, Fighter.Side.ENEMY)  # right + nearer camera -> FR (default)
	me._set_facing(1.0)
	me._physics_process(FRAME)
	assert_false(me._turning, "no pivot needed: already facing the target corner")
```

- [ ] **Step 5: Run both tests**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_fighter_control.gd -gexit`
Then: `... -gtest=res://test/unit/test_fighter_movement.gd -gexit`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add scripts/fighter.gd test/unit/test_fighter_control.gd test/unit/test_fighter_movement.gd
git commit -m "feat(facing): turn-around pivot (rotate clip) when facing changes idle/walking"
```

---

## Task 7: Fighter — directional walk/idle animation

Wire `AnimSelector` so idle/walk play the correct directional + front/back variant.

**Files:**
- Modify: `scripts/fighter.gd`
- Add test: `test/unit/test_fighter_movement.gd`

- [ ] **Step 1: Write the failing test**

A bare `Fighter.new()` has no `AnimatedSprite2D` (the `sprite` is `@onready
get_node_or_null`), so these tests use the scene instance and call `_update_animation`
directly (no target, so the pivot never interferes). Append to
`test/unit/test_fighter_movement.gd`:
```gdscript
const FIGHTER_SCENE := preload("res://scenes/Fighter.tscn")

func _spawn() -> Fighter:
	var f: Fighter = FIGHTER_SCENE.instantiate()
	add_child_autofree(f)                       # triggers _ready -> resolves `sprite`
	f.global_position = Vector2(100, 400)
	f.separation_radii = Vector2.ZERO
	return f

func test_vertical_walk_plays_vertical_clip():
	var f := _spawn()
	f._depth_facing = Facing.FRONT
	f._update_animation(Vector2.UP)
	assert_eq(f.sprite.animation, "walk_vertical_front")

func test_diagonal_walk_plays_diagonal_clip():
	var f := _spawn()
	f._depth_facing = Facing.FRONT
	f._update_animation(Vector2(1, 1))
	assert_eq(f.sprite.animation, "walk_diagonal_front")

func test_back_depth_plays_back_variant():
	var f := _spawn()
	f._depth_facing = Facing.BACK
	f._update_animation(Vector2.RIGHT)
	assert_eq(f.sprite.animation, "walk_horisontal_back")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_fighter_movement.gd -gexit`
Expected: FAIL — `_update_animation` still hardcodes `walk_horisontal_front` / `idle_front`,
so the vertical/diagonal/back assertions don't match.

- [ ] **Step 3: Replace `_update_animation`**

Replace `_update_animation` (~line 320-334) with:
```gdscript
func _update_animation(dir: Vector2) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var anim: String
	if mode == Mode.RUNNING:
		anim = "run"
	else:
		anim = AnimSelector.walk_anim(dir, _depth_facing)
	if not sprite.sprite_frames.has_animation(anim):
		return
	if sprite.animation != anim:
		sprite.play(anim)
	elif not sprite.is_playing():
		sprite.play(anim)
	_refresh_flip()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_fighter_movement.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/fighter.gd test/unit/test_fighter_movement.gd
git commit -m "feat(anim): play directional walk/idle variant from movement + depth"
```

---

## Task 8: Fighter — full two-phase getup

Knockdown → DOWN (lie + countdown + mash) → RISE (getup clip plays to completion) → NORMAL.
Getup clip chosen by `_fall_orientation`.

**Files:**
- Modify: `scripts/fighter.gd`
- Add test: `test/unit/test_fighter_movement.gd`

- [ ] **Step 1: Add getup fields + add `get_up_back_2` to left-drawn set**

After the `_depth_facing` field add:
```gdscript
var _fall_orientation: int = Fall.FACE_UP   # set at knockdown; selects the getup clip
var _getup_rising: bool = false             # RISE phase: getup clip is playing
var _getup_rise_time: float = 0.0           # seconds left in the RISE clip
```

In the `_LEFT_DRAWN` dictionary (~line 244), add `get_up_back_2` to the getup line:
```gdscript
	"get_up_front": true, "get_up_back": true, "get_up_back_2": true,
```

- [ ] **Step 2: Replace the reaction-countdown block with the two-phase getup**

Replace the reaction block (the `if _react_timer > 0.0:` block, ~line 109-121) with:
```gdscript
	# 1) Reaction / down-time countdown: no control, no walk. A knockdown (ONGROUND) hands
	# off to the RISE phase when it expires; other reactions recover straight to NORMAL.
	if _react_timer > 0.0:
		_react_timer -= delta
		_hold_in_place()
		if _react_timer <= 0.0:
			if mode == Mode.ONGROUND:
				_begin_getup_rise()
			else:
				mode = _react_recover_mode
		return
	# RISE phase: play the getup clip; control returns only when it finishes (arcade
	# ANI_GETUP_WAIT -> rise frames -> MODE_NORMAL).
	if _getup_rising:
		_getup_rise_time -= delta
		_hold_in_place()
		if _getup_rise_time <= 0.0:
			_getup_rising = false
			mode = Mode.NORMAL
		return
```

- [ ] **Step 3: Add the getup helpers**

Add near `_detach_victim`:
```gdscript
## Start the getup RISE: play the clip chosen by how we fell, hold control until it ends.
func _begin_getup_rise() -> void:
	var anim: String = _getup_anim()
	if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
		_refresh_flip()
		_getup_rising = true
		_getup_rise_time = _anim_length_seconds(anim)
	else:
		mode = _react_recover_mode   # no clip available: recover immediately

## Getup clip name from the recorded fall orientation.
func _getup_anim() -> String:
	match _fall_orientation:
		Fall.FACE_DOWN:
			return "get_up_back"
		Fall.FACE_DOWN_ROLL:
			return "get_up_back_2"
		_:
			return "get_up_front"

## Length of an animation in seconds (frames / fps), from the SpriteFrames.
func _anim_length_seconds(anim: String) -> float:
	if sprite == null or sprite.sprite_frames == null:
		return 0.0
	var n: int = sprite.sprite_frames.get_frame_count(anim)
	var fps: float = sprite.sprite_frames.get_animation_speed(anim)
	if fps <= 0.0:
		return 0.0
	return float(n) / fps
```

- [ ] **Step 4: Record fall orientation at knockdown**

In `receive_hit`, set the orientation right before `_enter_reaction(r, hit_dir)` (after the
`var family := AMode.reaction_for(move.attack_mode)` line):
```gdscript
	var family := AMode.reaction_for(move.attack_mode)
	_fall_orientation = Reaction.fall_orientation(family, move.id)
	var r := Reaction.resolve(family, hit_dir, move.causes_dizzy)
	_enter_reaction(r, hit_dir)
```

In `_detach_victim`, insert these two lines immediately BEFORE the existing
`vic._react_timer = ArcadeUnits.ticks_to_seconds(AMode.getup_ticks(...))` line (leave the
surrounding `vic.mode = Mode.ONGROUND` / `vic._react_recover_mode = Mode.NORMAL` /
`vic._react_timer = ...` lines as they are):
```gdscript
		var mv_id: String = _player.sequence.id if _player.sequence != null else ""
		vic._fall_orientation = Reaction.fall_orientation(AMode.Family.KNOCKDOWN, mv_id)
```

- [ ] **Step 5: Write the getup integration test**

The RISE phase reads the getup clip length from the SpriteFrames, so use the scene-instanced
`_spawn()` helper from Task 7 (real sprite). Append to `test/unit/test_fighter_movement.gd`:
```gdscript
func test_getup_rise_gates_recovery_then_returns_to_normal():
	var f := _spawn()
	f.mode = Fighter.Mode.ONGROUND
	f._fall_orientation = Fighter.Fall.FACE_UP
	f._react_timer = 1.0 / 60.0           # one tick of down-time left
	f._physics_process(1.0 / 60.0)        # DOWN expires -> RISE begins
	assert_true(f._getup_rising, "enters the RISE phase after down-time")
	assert_eq(f.mode, Fighter.Mode.ONGROUND, "still no control during the rise")
	# Run well past the get_up_front clip length to finish the rise.
	for _i in range(60):
		f._physics_process(1.0 / 60.0)
	assert_false(f._getup_rising, "rise finished")
	assert_eq(f.mode, Fighter.Mode.NORMAL, "control returns only after the getup clip ends")

func test_getup_clip_chosen_by_fall_orientation():
	var f := _spawn()
	f._fall_orientation = Fighter.Fall.FACE_DOWN_ROLL
	assert_eq(f._getup_anim(), "get_up_back_2")
	f._fall_orientation = Fighter.Fall.FACE_DOWN
	assert_eq(f._getup_anim(), "get_up_back")
	f._fall_orientation = Fighter.Fall.FACE_UP
	assert_eq(f._getup_anim(), "get_up_front")
```

- [ ] **Step 6: Run test to verify it passes**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_fighter_movement.gd -gexit`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add scripts/fighter.gd test/unit/test_fighter_movement.gd
git commit -m "feat(getup): two-phase getup (down→rise) with fall-orientation clip choice"
```

---

## Task 9: Full suite + manual playtest

**Files:** none (verification only)

- [ ] **Step 1: Run the whole suite**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit`
Expected: all green.

- [ ] **Step 2: Fix any timing fallout**

If a test knocks a fighter down and loops waiting for `Mode.NORMAL`, it now also needs the
RISE frames: `get_up_front` is `frame_count / 12` s. Extend that test's loop by
`ceil(frame_count / 12 * 60) + 2` iterations. (Known down-state tests assert `ONGROUND`
within ≤20 ticks and are unaffected: `test_fighter_grapple` line ~84-90, `test_fighter_combat`
line ~99.) If any facing test fails because a pivot is mid-flight, extend its loop to ~30
ticks as in `test_faces_target_continuously`.

- [ ] **Step 3: Manual playtest in the Sandbox**

Run: `"$GODOT" --path . scenes/Sandbox.tscn`
Confirm visually:
- Walking diagonally / vertically plays the diagonal / vertical clip; front vs back matches
  the opponent's depth side. (Spec note: if front/back reads inverted, flip the single
  comparison in `Facing.desired_depth`.)
- Moving the opponent across (left/right) and across the depth midline triggers the rotate
  pivot before the fighter settles facing them; no jitter when roughly level in depth.
- Knock a fighter down: it lies, mashing shortens the down-time, then the getup clip plays
  fully before control returns.

- [ ] **Step 4: Final commit (if any test edits were needed)**

```bash
git add -A
git commit -m "test: adjust timing-dependent tests for the getup RISE phase"
```

---

## Self-Review Notes

- **Spec coverage:** Component 1 (facing+pivot) = Tasks 1,2,5,6; Component 2 (directional
  walk) = Tasks 3,7; Component 3 (getup) = Tasks 4,8. Depth convention, hysteresis, snap-vs-
  pivot, running exception, and the `get_up_back_2` mapping are all covered.
- **Out of scope (per spec):** post-getup `DELAY_BUTNS` lockout, rise invulnerability,
  non-Doink wrestlers, run-state pivot.
- **Type consistency:** `Facing.State`, `Facing.FRONT/BACK`, `Fighter.Fall.*`,
  `RotatePlanner.plan`, `AnimSelector.walk_anim`, `Reaction.fall_orientation`,
  `_service_turn`/`_hold_in_place`/`_commit_facing_state`/`_show_rotate_frame`/
  `_begin_getup_rise`/`_getup_anim`/`_anim_length_seconds` used consistently across tasks.
```
