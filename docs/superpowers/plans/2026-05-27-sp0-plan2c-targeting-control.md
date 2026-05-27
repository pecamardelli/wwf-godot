# SP-0 Plan 2c: Targeting, Facing, Run/Block & Move Dispatch — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the single fighter's grounded control loop — auto-target the right enemy (arcade biased scoring) → always face it → move/run/block relative to it → fire the right move from a range × relative-direction × button table → and close the knockdown loop with a getup (visual + mash-to-recover).

**Architecture:** New pure modules under `scripts/combat/` (`Targeting`, `RelativeInput`, `MoveTable`) plus integration on `Fighter` (side, target, facing-to-target, run/block, facing-aware multipliers, getup) and `Player` (dispatch). The arcade source is the authority (`/home/pablin/Games/wwf-wrestlemania`); cite `file:line`. Builds on Plan 2b (tag `sp0-plan2b-hit-detection`); reuses the `_facing` field and the `ArcadeUnits` constants staged in 2a.

**Tech Stack:** Godot 4.6.3, GDScript, GUT (headless).

**Design:** `docs/superpowers/specs/2026-05-27-plan2c-targeting-control-design.md`.

---

## Conventions (every task)

```bash
cd /media/pablin/DATOS/JUEGOS/Wrestlemania/wwfmania-godot   # `godot` is on PATH
```
After adding NEW `class_name` scripts, run an import pass BEFORE tests so the headless runner finds them:
```bash
godot --headless --path . --import
```
Run the full suite:
```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -gprefix=test_ -gsuffix=.gd -ginclude_subdirs -gexit
```
Run one file: add `-gselect=test_NAME.gd`. Axis mapping: **X = position.x (horizontal), Z = position.y (depth), Y = height (0 grounded)**.

Existing classes built on: `ArcadeUnits` (`RUN_SPEED`=331.25, `RUN_DEPTH_DRIFT`=132.5, `BACKWARD_MULT`=0.9, `OPP_DOWN_MULT`=1.5, `ticks_to_seconds`), `Fighter` (Mode enum, `_facing` logic field, `health`, `_react_timer`, `receive_hit`, `start_move`, `_physics_process` 3-phase), `Player`, `MoveSequence`, `Damage` (`LIFE_MAX`=163). Built strike sequences: `res://assets/sequences/doink/{punch,headbutt,kick,uppercut,big_boot}.tres`.

---

## File structure (this plan)

```
scripts/combat/
  targeting.gd        # NEW: biased nearest-opponent scoring (pure)
  relative_input.gd   # NEW: raw 8-way -> toward/away/up/down given facing (pure)
  move_table.gd       # NEW: MoveTable resource — range × dir × button -> MoveSequence + lookup
scripts/
  fighter.gd          # MODIFY: Side, target, recompute cadence, face-target, run/block, facing-aware mults, getup, _who_i_hit
  player.gd           # MODIFY: run/block input + MoveTable dispatch (range × relative-dir × button)
tools/
  build_doink_movetable.gd  # NEW: author Doink's MoveTable -> res://assets/movetables/doink.tres
assets/movetables/doink.tres # NEW
scenes/
  Sandbox.tscn        # MODIFY: training dummy (side=ENEMY) + side assignment
test/unit/
  test_targeting.gd        # NEW
  test_relative_input.gd   # NEW
  test_move_table.gd       # NEW
  test_fighter_control.gd  # NEW (target/facing/run/block/getup integration)
```

---

## Task 0: Branch

- [ ] **Step 1: Create the working branch**
```bash
git switch master && git switch -c player-control
git branch --show-current   # -> player-control
```

---

## Task 1: Fighter side + target fields + is_dead (TDD)

**Files:** Modify `scripts/fighter.gd`; create `test/unit/test_fighter_control.gd`

- [ ] **Step 1: Write the failing test** — `test/unit/test_fighter_control.gd`
```gdscript
extends "res://addons/gut/test.gd"

const FRAME := 1.0 / 60.0

func test_fighter_defaults_to_player_side():
	var f := Fighter.new()
	add_child_autofree(f)
	assert_eq(f.side, Fighter.Side.PLAYER)

func test_is_dead_when_health_zero():
	var f := Fighter.new()
	add_child_autofree(f)
	assert_false(f.is_dead())
	f.health = 0
	assert_true(f.is_dead())
```

- [ ] **Step 2: Run, expect fail** (`Fighter.Side`/`is_dead` undefined)
```bash
godot --headless --path . --import
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -gprefix=test_ -gsuffix=.gd -ginclude_subdirs -gselect=test_fighter_control.gd -gexit
```

- [ ] **Step 3: Implement** — in `scripts/fighter.gd`, add after the `Mode` enum / `mode` line:
```gdscript
## Faction. Targeting only considers opposite-side fighters (arcade PLYR_SIDE).
enum Side { PLAYER, ENEMY }
@export var side: int = Side.PLAYER

## The opponent this fighter is currently targeting (drives facing + dispatch range).
var target: Fighter = null
## The fighter this one most recently landed a hit on (arcade WHOIHIT; targeting bias).
var _who_i_hit: Fighter = null
## Counter to stagger target recomputation across fighters.
var _target_tick: int = 0
```
And add the helper near the other combat helpers:
```gdscript
func is_dead() -> bool:
	return health <= 0
```

- [ ] **Step 4: Run, expect pass.**

- [ ] **Step 5: Commit**
```bash
git add scripts/fighter.gd test/unit/test_fighter_control.gd
git commit -m "feat(control): Fighter side + target fields + is_dead"
```

---

## Task 2: Targeting module — biased scoring (TDD)

**Files:** Create `scripts/combat/targeting.gd`, `test/unit/test_targeting.gd`

- [ ] **Step 1: Write the failing test** — `test/unit/test_targeting.gd`
```gdscript
extends "res://addons/gut/test.gd"

func _fighter(x: float, y: float, side: int) -> Fighter:
	var f := Fighter.new()
	add_child_autofree(f)
	f.global_position = Vector2(x, y)
	f.side = side
	return f

func test_picks_nearest_opposite_side():
	var me := _fighter(0, 400, Fighter.Side.PLAYER)
	var near := _fighter(60, 400, Fighter.Side.ENEMY)
	var far := _fighter(300, 400, Fighter.Side.ENEMY)
	assert_eq(Targeting.pick(me, [near, far]), near)

func test_skips_self_and_same_side():
	var me := _fighter(0, 400, Fighter.Side.PLAYER)
	var ally := _fighter(40, 400, Fighter.Side.PLAYER)
	var enemy := _fighter(200, 400, Fighter.Side.ENEMY)
	assert_eq(Targeting.pick(me, [me, ally, enemy]), enemy, "self + same-side skipped")

func test_downed_enemy_is_deprioritized():
	var me := _fighter(0, 400, Fighter.Side.PLAYER)
	var standing := _fighter(120, 400, Fighter.Side.ENEMY)
	var downed := _fighter(80, 400, Fighter.Side.ENEMY)  # closer, but on the ground
	downed.mode = Fighter.Mode.ONGROUND                  # score ×2 -> 160 > 120
	assert_eq(Targeting.pick(me, [standing, downed]), standing)

func test_last_hit_target_is_stickier():
	var me := _fighter(0, 400, Fighter.Side.PLAYER)
	var a := _fighter(100, 400, Fighter.Side.ENEMY)
	var b := _fighter(95, 400, Fighter.Side.ENEMY)       # slightly closer
	me._who_i_hit = a                                    # a ×0.75 -> 75 < 95
	assert_eq(Targeting.pick(me, [a, b]), a)

func test_prefers_a_live_enemy_over_a_dead_closer_one():
	var me := _fighter(0, 400, Fighter.Side.PLAYER)
	var dead := _fighter(40, 400, Fighter.Side.ENEMY)
	dead.health = 0
	var alive := _fighter(200, 400, Fighter.Side.ENEMY)
	assert_eq(Targeting.pick(me, [dead, alive]), alive)

func test_returns_null_when_no_opponents():
	var me := _fighter(0, 400, Fighter.Side.PLAYER)
	var ally := _fighter(40, 400, Fighter.Side.PLAYER)
	assert_null(Targeting.pick(me, [ally]))
```

- [ ] **Step 2: Run, expect fail** (`Targeting` undefined).

- [ ] **Step 3: Implement** — `scripts/combat/targeting.gd`
```gdscript
class_name Targeting
## Biased nearest-opponent selection (arcade calc_closest, WRESTLE.ASM:4127-4210).
## Lower score = more likely chosen. A live candidate always beats a dead one.

const DOWNED_PENALTY := 2.0   # ONGROUND opponents score ×2 (deprioritized)
const LAST_HIT_BONUS := 0.75  # the fighter you last hit scores ×0.75 (stickiness)

## Biased distance for one candidate. Distance is the X/Z plane (Y height is 0 now),
## so the 2D position distance equals the 3D distance with dy=0.
static func score(from: Fighter, cand: Fighter) -> float:
	var s := from.global_position.distance_to(cand.global_position)
	if cand.mode == Fighter.Mode.ONGROUND:
		s *= DOWNED_PENALTY
	if from._who_i_hit == cand:
		s *= LAST_HIT_BONUS
	return s

## Pick the best opposite-side target from `candidates`, or null.
static func pick(from: Fighter, candidates: Array) -> Fighter:
	var best: Fighter = null
	var best_score := INF
	var best_alive := false
	for c in candidates:
		if c == from or c.side == from.side:
			continue
		var alive := not c.is_dead()
		var sc := score(from, c)
		# Prefer alive over dead; among equal aliveness, prefer the lower score.
		if best == null or (alive and not best_alive) or (alive == best_alive and sc < best_score):
			best = c
			best_score = sc
			best_alive = alive
	return best
```

- [ ] **Step 4: Run, expect pass.** Expected: 6 pass.

- [ ] **Step 5: Commit**
```bash
git add scripts/combat/targeting.gd test/unit/test_targeting.gd
git commit -m "feat(control): biased nearest-opponent targeting (downed/last-hit/alive)"
```

---

## Task 3: Target recompute cadence + acquisition (TDD)

**Files:** Modify `scripts/fighter.gd`; extend `test/unit/test_fighter_control.gd`

`Fighter` recomputes `target` immediately when it has none or the current one died, else every 4th tick (staggered by `_target_tick`).

- [ ] **Step 1: Write failing tests** — append to `test/unit/test_fighter_control.gd`
```gdscript
func _at(x: float, side: int) -> Fighter:
	var f := Fighter.new()
	add_child_autofree(f)
	f.global_position = Vector2(x, 400)
	f.side = side
	f.separation_radii = Vector2.ZERO
	return f

func test_acquires_nearest_enemy_target():
	var me := _at(0, Fighter.Side.PLAYER)
	var enemy := _at(120, Fighter.Side.ENEMY)
	me._physics_process(FRAME)
	assert_eq(me.target, enemy)

func test_retargets_when_current_target_dies():
	var me := _at(0, Fighter.Side.PLAYER)
	var near := _at(100, Fighter.Side.ENEMY)
	var far := _at(260, Fighter.Side.ENEMY)
	me._physics_process(FRAME)
	assert_eq(me.target, near)
	near.health = 0                      # current target dies
	me._physics_process(FRAME)           # must retarget immediately
	assert_eq(me.target, far)
```

- [ ] **Step 2: Run, expect fail** (no targeting in `_physics_process`).

- [ ] **Step 3: Implement** — in `scripts/fighter.gd`, add a method and call it at the TOP of `_physics_process` (right after `_sim_time += delta`):
```gdscript
## Refresh `target` from the "fighters" group. Recompute immediately when we have
## no live target; otherwise only every 4th tick, staggered per fighter.
func _update_target() -> void:
	_target_tick += 1
	var stale: bool = target == null or target.is_dead() or not is_instance_valid(target)
	if not stale and (_target_tick % 4) != (get_instance_id() % 4):
		return
	target = Targeting.pick(self, get_tree().get_nodes_in_group("fighters"))
```
In `_physics_process`, add the call:
```gdscript
func _physics_process(delta: float) -> void:
	_sim_time += delta
	_update_target()
	# ... existing phase 1/2/3 unchanged ...
```

- [ ] **Step 4: Run, expect pass.** Also run the FULL suite — the existing combat tests create fighters without a `side` mismatch; confirm still green. (In `test_fighter_combat.gd` both fighters default to PLAYER side, so they will NOT target each other — that's fine; those tests call `start_move` directly and don't depend on `target`.)

- [ ] **Step 5: Commit**
```bash
git add scripts/fighter.gd test/unit/test_fighter_control.gd
git commit -m "feat(control): target acquisition + arcade recompute cadence"
```

---

## Task 4: Continuous facing toward target (TDD)

**Files:** Modify `scripts/fighter.gd`; extend `test/unit/test_fighter_control.gd`

- [ ] **Step 1: Write failing test** — append to `test/unit/test_fighter_control.gd`
```gdscript
func test_faces_target_continuously():
	var me := _at(100, Fighter.Side.PLAYER)
	var enemy := _at(300, Fighter.Side.ENEMY)   # to the right
	me._physics_process(FRAME)
	assert_eq(me.facing(), 1.0, "faces right toward the right-side target")
	enemy.global_position.x = -50               # move target to the left
	me._physics_process(FRAME)
	assert_eq(me.facing(), -1.0, "turns to keep facing the target")
```

- [ ] **Step 2: Run, expect fail** (facing only changes on walk/attack input).

- [ ] **Step 3: Implement** — in `scripts/fighter.gd`, add to `_physics_process` after `_update_target()`:
```gdscript
	if target != null and is_instance_valid(target):
		_set_facing(target.global_position.x - global_position.x)
```
(`_set_facing` already exists from 2b; it sets `_facing` and mirrors the sprite. The per-attack `_face_nearest_opponent()` is now redundant — leave it; it is a harmless safety net when there is no target.)

- [ ] **Step 4: Run, expect pass.** Full suite stays green (combat tests have no enemy-side target, so facing there is driven by the existing `_face_nearest_opponent` on attack as before).

- [ ] **Step 5: Commit**
```bash
git add scripts/fighter.gd test/unit/test_fighter_control.gd
git commit -m "feat(control): continuously face the current target"
```

---

## Task 5: RelativeInput module (TDD)

**Files:** Create `scripts/combat/relative_input.gd`, `test/unit/test_relative_input.gd`

- [ ] **Step 1: Write failing test** — `test/unit/test_relative_input.gd`
```gdscript
extends "res://addons/gut/test.gd"

func test_toward_when_input_matches_facing():
	var r := RelativeInput.resolve(Vector2(1, 0), 1.0)   # pushing right, facing right
	assert_true(r.toward)
	assert_false(r.away)

func test_away_when_input_opposes_facing():
	var r := RelativeInput.resolve(Vector2(-1, 0), 1.0)  # pushing left, facing right
	assert_true(r.away)
	assert_false(r.toward)

func test_toward_is_relative_to_facing_left():
	var r := RelativeInput.resolve(Vector2(-1, 0), -1.0) # pushing left, facing left
	assert_true(r.toward, "left input is 'toward' when facing left")

func test_vertical_flags_are_absolute():
	var up := RelativeInput.resolve(Vector2(0, -1), 1.0)
	var down := RelativeInput.resolve(Vector2(0, 1), 1.0)
	assert_true(up.up)
	assert_true(down.down)

func test_neutral_input_has_no_flags():
	var r := RelativeInput.resolve(Vector2.ZERO, 1.0)
	assert_false(r.toward or r.away or r.up or r.down)
```

- [ ] **Step 2: Run, expect fail** (`RelativeInput` undefined).

- [ ] **Step 3: Implement** — `scripts/combat/relative_input.gd`
```gdscript
class_name RelativeInput
## Map raw 8-way input to directions relative to facing (arcade J_TOWARD/J_AWAY).
## `toward` = horizontal input pointing the same way the fighter faces (at the target).

static func resolve(raw: Vector2, facing: float) -> Dictionary:
	var ix := signf(raw.x)
	var fx := signf(facing)
	return {
		"toward": ix != 0.0 and ix == fx,
		"away": ix != 0.0 and ix == -fx,
		"up": raw.y < 0.0,
		"down": raw.y > 0.0,
	}
```

- [ ] **Step 4: Run, expect pass.** Expected: 5 pass.

- [ ] **Step 5: Commit**
```bash
git add scripts/combat/relative_input.gd test/unit/test_relative_input.gd
git commit -m "feat(control): RelativeInput — toward/away/up/down vs facing"
```

---

## Task 6: Facing-aware walk multipliers (TDD)

**Files:** Modify `scripts/fighter.gd`; extend `test/unit/test_fighter_control.gd`

Walking away from the target is slower (`BACKWARD_MULT` 0.9); when the target is grounded you close faster (`OPP_DOWN_MULT` 1.5). These multiply the horizontal walk target on top of `walk_speed_scale`.

- [ ] **Step 1: Write failing test** — append to `test/unit/test_fighter_control.gd`
```gdscript
class _HoldTowardWhenFacingRight extends Fighter:
	func get_input_direction() -> Vector2:
		return Vector2.RIGHT

func test_backward_walk_is_slower_than_forward():
	# facing right toward a right-side target, but walking LEFT (away) -> ×0.9
	var f := _HoldTowardWhenFacingRight.new()
	add_child_autofree(f)
	# helper exposes the multiplier directly for a deterministic unit check:
	assert_almost_eq(f.walk_dir_multiplier(false, false), 1.0, 0.001)   # toward, target up
	assert_almost_eq(f.walk_dir_multiplier(true, false), ArcadeUnits.BACKWARD_MULT, 0.001)  # away
	assert_almost_eq(f.walk_dir_multiplier(false, true), ArcadeUnits.OPP_DOWN_MULT, 0.001)  # target down
```

- [ ] **Step 2: Run, expect fail** (`walk_dir_multiplier` undefined).

- [ ] **Step 3: Implement** — in `scripts/fighter.gd` add the pure helper:
```gdscript
## Walk-speed multiplier from facing-relative state (arcade walk table modifiers).
func walk_dir_multiplier(moving_away: bool, target_down: bool) -> float:
	var m := 1.0
	if moving_away:
		m *= ArcadeUnits.BACKWARD_MULT
	if target_down:
		m *= ArcadeUnits.OPP_DOWN_MULT
	return m
```
Then in `_physics_process` phase 3 (normal movement), apply it to the horizontal target after `walk_speed_scale`:
```gdscript
		dir = get_input_direction()
		var target_vel: Vector2 = MovementMath.walk_velocity(dir) * walk_speed_scale
		target_vel.y *= depth_speed_scale
		var rel := RelativeInput.resolve(dir, _facing)
		var target_down: bool = target != null and is_instance_valid(target) and target.mode == Mode.ONGROUND
		target_vel.x *= walk_dir_multiplier(rel.away, target_down)
		velocity = velocity.move_toward(target_vel, walk_acceleration * delta)
```
(Rename the local `target` velocity var to `target_vel` to avoid shadowing the new `target` field — update the two references in this branch accordingly.)

- [ ] **Step 4: Run, expect pass.** Full suite green (the `_HoldRight`/`_HoldDown` movement tests have no `target`, so `target_down` is false and `rel.away` is false → multiplier 1.0 → unchanged).

- [ ] **Step 5: Commit**
```bash
git add scripts/fighter.gd test/unit/test_fighter_control.gd
git commit -m "feat(control): facing-aware walk multipliers (backward 0.9 / opp-down 1.5)"
```

---

## Task 7: Run mode (TDD)

**Files:** Modify `scripts/fighter.gd`, `scripts/player.gd`; extend `test/unit/test_fighter_control.gd`

Holding run enters `RUNNING` and moves at `RUN_SPEED` with `RUN_DEPTH_DRIFT`; releasing returns to NORMAL.

- [ ] **Step 1: Write failing test** — append to `test/unit/test_fighter_control.gd`
```gdscript
class _RunningRight extends Fighter:
	func get_input_direction() -> Vector2:
		return Vector2.RIGHT
	func wants_to_run() -> bool:
		return true

func test_run_uses_run_speed():
	var f := _RunningRight.new()
	add_child_autofree(f)
	f.mode = Fighter.Mode.NORMAL
	f.velocity = Vector2.ZERO
	for _i in range(120):
		f._physics_process(FRAME)
	assert_eq(f.mode, Fighter.Mode.RUNNING)
	assert_almost_eq(f.velocity.x, ArcadeUnits.RUN_SPEED, 1.0)
```

- [ ] **Step 2: Run, expect fail** (`wants_to_run`/run handling undefined).

- [ ] **Step 3: Implement** — in `scripts/fighter.gd`:
Add the overridable input hook (base returns false; `Player` overrides):
```gdscript
## Subclasses (Player) override to report the run button being held.
func wants_to_run() -> bool:
	return false
```
In `_physics_process` phase 3, branch on run BEFORE the normal walk (only when there is movement input and not blocking):
```gdscript
	var dir: Vector2 = Vector2.ZERO
	if Fighter.input_allowed(mode):
		dir = get_input_direction()
		if wants_to_run() and dir != Vector2.ZERO:
			mode = Mode.RUNNING
			var run_vel := Vector2(signf(_facing) * ArcadeUnits.RUN_SPEED, signf(dir.y) * ArcadeUnits.RUN_DEPTH_DRIFT)
			velocity = velocity.move_toward(run_vel, walk_acceleration * delta)
		else:
			if mode == Mode.RUNNING:
				mode = Mode.NORMAL
			var target_vel: Vector2 = MovementMath.walk_velocity(dir) * walk_speed_scale
			target_vel.y *= depth_speed_scale
			var rel := RelativeInput.resolve(dir, _facing)
			var target_down: bool = target != null and is_instance_valid(target) and target.mode == Mode.ONGROUND
			target_vel.x *= walk_dir_multiplier(rel.away, target_down)
			velocity = velocity.move_toward(target_vel, walk_acceleration * delta)
	else:
		velocity = Vector2.ZERO
```
(This restructures phase 3's input branch; keep `move_and_slide()`, `_apply_separation()`, clamp, `_update_facing`, `_update_animation` calls after it as before. Note `input_allowed` already returns true for RUNNING.)

In `scripts/player.gd`, override the hook:
```gdscript
func wants_to_run() -> bool:
	return Input.is_action_pressed(_action_prefix() + "run")
```

- [ ] **Step 4: Run, expect pass.** Full suite green.

- [ ] **Step 5: Commit**
```bash
git add scripts/fighter.gd scripts/player.gd test/unit/test_fighter_control.gd
git commit -m "feat(control): run mode at RUN_SPEED + depth drift, held run key"
```

---

## Task 8: Block mode (TDD)

**Files:** Modify `scripts/fighter.gd`, `scripts/player.gd`; extend `test/unit/test_fighter_control.gd`

Holding block enters `BLOCK` (no move, no attack); incoming front damage resolves to 1 (the `blocked` path already exists in `Damage`/`Reaction`). `receive_hit` already reads `mode == Mode.BLOCK`.

- [ ] **Step 1: Write failing test** — append to `test/unit/test_fighter_control.gd`
```gdscript
class _Blocker extends Fighter:
	func wants_to_block() -> bool:
		return true

func test_block_enters_block_mode_and_holds_still():
	var f := _Blocker.new()
	add_child_autofree(f)
	f.mode = Fighter.Mode.NORMAL
	f._physics_process(FRAME)
	assert_eq(f.mode, Fighter.Mode.BLOCK)
	assert_eq(f.velocity, Vector2.ZERO, "no movement while blocking")

func test_block_reduces_damage_to_one():
	var attacker := _at(100, Fighter.Side.ENEMY)
	var victim := _at(140, Fighter.Side.PLAYER)
	victim.mode = Fighter.Mode.BLOCK
	victim.receive_hit(attacker, load("res://assets/sequences/doink/punch.tres"))
	assert_eq(victim.health, Damage.LIFE_MAX - 1, "blocked punch deals 1")
```

- [ ] **Step 2: Run, expect fail** (`wants_to_block`/block handling undefined).

- [ ] **Step 3: Implement** — in `scripts/fighter.gd`:
```gdscript
## Subclasses (Player) override to report the block button being held.
func wants_to_block() -> bool:
	return false
```
In `_physics_process`, at the START of phase 3 (before reading movement; only when `input_allowed`), handle block:
```gdscript
	if Fighter.input_allowed(mode) and wants_to_block():
		mode = Mode.BLOCK
		velocity = Vector2.ZERO
		move_and_slide()
		global_position = MovementMath.clamp_to_floor(global_position, floor_min_y, floor_max_y)
		_update_animation(Vector2.ZERO)   # idle/defence pose
		return
	elif mode == Mode.BLOCK:
		mode = Mode.NORMAL
```
(Note: `input_allowed` returns true for NORMAL/RUNNING but not BLOCK, so once in BLOCK the `wants_to_block` branch above won't re-enter via `input_allowed`. Adjust: gate the block check on `mode == Mode.NORMAL or mode == Mode.RUNNING or mode == Mode.BLOCK` so a held block persists. Use:)
```gdscript
	if (mode == Mode.NORMAL or mode == Mode.RUNNING or mode == Mode.BLOCK) and wants_to_block():
		mode = Mode.BLOCK
		velocity = Vector2.ZERO
		move_and_slide()
		global_position = MovementMath.clamp_to_floor(global_position, floor_min_y, floor_max_y)
		_update_animation(Vector2.ZERO)
		return
	elif mode == Mode.BLOCK:
		mode = Mode.NORMAL
```
In `scripts/player.gd`:
```gdscript
func wants_to_block() -> bool:
	return Input.is_action_pressed(_action_prefix() + "block")
```

- [ ] **Step 4: Run, expect pass.** Full suite green (`receive_hit` BLOCK path already exists; the 1px assert exercises it via the new block-mode entry).

- [ ] **Step 5: Commit**
```bash
git add scripts/fighter.gd scripts/player.gd test/unit/test_fighter_control.gd
git commit -m "feat(control): block mode — hold to guard, front damage -> 1"
```

---

## Task 9: MoveTable + Doink data + dispatch (TDD)

**Files:** Create `scripts/combat/move_table.gd`, `tools/build_doink_movetable.gd`, `assets/movetables/doink.tres`, `test/unit/test_move_table.gd`; modify `scripts/player.gd`

- [ ] **Step 1: Implement the resource** — `scripts/combat/move_table.gd`
```gdscript
class_name MoveTable
extends Resource
## Maps range × relative-direction × button -> MoveSequence (arcade mode_table/action_table/JJXM).
## Stored as a flat dict keyed "range|dir|button". Lookup falls back dir-specific -> NEUTRAL.

enum Range { NORMAL, CLOSE, RUNNING }
enum Dir { NEUTRAL, TOWARD, AWAY, DOWN }
enum Button { LOW_PUNCH, HIGH_PUNCH, LOW_KICK, HIGH_KICK }

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
```

- [ ] **Step 2: Write the builder** — `tools/build_doink_movetable.gd`
```gdscript
extends SceneTree
## Author Doink's MoveTable -> res://assets/movetables/doink.tres
## Run: godot --headless --path . -s tools/build_doink_movetable.gd

const OUT := "res://assets/movetables/doink.tres"
const SEQ := "res://assets/sequences/doink/"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/movetables"))
	var t := MoveTable.new()
	var punch: MoveSequence = load(SEQ + "punch.tres")
	var headbutt: MoveSequence = load(SEQ + "headbutt.tres")
	var kick: MoveSequence = load(SEQ + "kick.tres")
	var uppercut: MoveSequence = load(SEQ + "uppercut.tres")
	var big_boot: MoveSequence = load(SEQ + "big_boot.tres")
	# Low punch: far -> punch, close -> headbutt.
	t.add(MoveTable.Range.NORMAL, MoveTable.Dir.NEUTRAL, MoveTable.Button.LOW_PUNCH, punch)
	t.add(MoveTable.Range.CLOSE,  MoveTable.Dir.NEUTRAL, MoveTable.Button.LOW_PUNCH, headbutt)
	# High punch -> uppercut (both ranges).
	t.add(MoveTable.Range.NORMAL, MoveTable.Dir.NEUTRAL, MoveTable.Button.HIGH_PUNCH, uppercut)
	t.add(MoveTable.Range.CLOSE,  MoveTable.Dir.NEUTRAL, MoveTable.Button.HIGH_PUNCH, uppercut)
	# Low kick -> kick (both ranges).
	t.add(MoveTable.Range.NORMAL, MoveTable.Dir.NEUTRAL, MoveTable.Button.LOW_KICK, kick)
	t.add(MoveTable.Range.CLOSE,  MoveTable.Dir.NEUTRAL, MoveTable.Button.LOW_KICK, kick)
	# High kick -> big boot (all ranges; it is also the running attack).
	for r in [MoveTable.Range.NORMAL, MoveTable.Range.CLOSE, MoveTable.Range.RUNNING]:
		t.add(r, MoveTable.Dir.NEUTRAL, MoveTable.Button.HIGH_KICK, big_boot)
	var err := ResourceSaver.save(t, OUT)
	print("doink movetable -> ", error_string(err))
	if err != OK:
		quit(1)
	quit()
```

- [ ] **Step 3: Build it**
```bash
godot --headless --path . --import
godot --headless --path . -s tools/build_doink_movetable.gd   # -> "doink movetable -> OK"
godot --headless --path . --import
```

- [ ] **Step 4: Write the test** — `test/unit/test_move_table.gd`
```gdscript
extends "res://addons/gut/test.gd"

func _table() -> MoveTable:
	return load("res://assets/movetables/doink.tres")

func test_low_punch_far_is_punch_close_is_headbutt():
	var t := _table()
	assert_eq(t.lookup(MoveTable.Range.NORMAL, MoveTable.Dir.NEUTRAL, MoveTable.Button.LOW_PUNCH).id, "punch")
	assert_eq(t.lookup(MoveTable.Range.CLOSE, MoveTable.Dir.NEUTRAL, MoveTable.Button.LOW_PUNCH).id, "headbutt")

func test_high_punch_is_uppercut():
	assert_eq(_table().lookup(MoveTable.Range.NORMAL, MoveTable.Dir.NEUTRAL, MoveTable.Button.HIGH_PUNCH).id, "uppercut")

func test_dir_specific_falls_back_to_neutral():
	# no TOWARD entry exists -> falls back to the NEUTRAL low-kick (kick)
	assert_eq(_table().lookup(MoveTable.Range.NORMAL, MoveTable.Dir.TOWARD, MoveTable.Button.LOW_KICK).id, "kick")

func test_running_high_kick_is_big_boot():
	assert_eq(_table().lookup(MoveTable.Range.RUNNING, MoveTable.Dir.NEUTRAL, MoveTable.Button.HIGH_KICK).id, "big_boot")
```

- [ ] **Step 5: Run, expect pass.**

- [ ] **Step 6: Wire dispatch in `scripts/player.gd`** — replace the body of `_unhandled_input` and the move consts with table-driven dispatch. Replace the 5 `preload` consts with:
```gdscript
const _MOVES := preload("res://assets/movetables/doink.tres")

const _CLOSE_GATE := 70.0   # arcade close range (~CLOSEST_XDIST); refine per playtest

func _unhandled_input(_event: InputEvent) -> void:
	if not Fighter.input_allowed(mode) or is_attacking():
		return
	var btn := _pressed_button()
	if btn < 0:
		return
	var rng := _current_range()
	var dir := _current_dir()
	var seq: MoveSequence = _MOVES.lookup(rng, dir, btn)
	if seq != null:
		start_move(seq)

## Which attack button was just pressed, or -1.
func _pressed_button() -> int:
	var p := _action_prefix()
	if _pressed(p + "punch"): return MoveTable.Button.LOW_PUNCH
	if _pressed(p + "high_punch"): return MoveTable.Button.HIGH_PUNCH
	if _pressed(p + "kick"): return MoveTable.Button.LOW_KICK
	if _pressed(p + "high_kick"): return MoveTable.Button.HIGH_KICK
	return -1

func _current_range() -> int:
	if mode == Mode.RUNNING:
		return MoveTable.Range.RUNNING
	if target != null and is_instance_valid(target) \
			and global_position.distance_to(target.global_position) <= _CLOSE_GATE:
		return MoveTable.Range.CLOSE
	return MoveTable.Range.NORMAL

func _current_dir() -> int:
	var rel := RelativeInput.resolve(get_input_direction(), _facing)
	if rel.down: return MoveTable.Dir.DOWN
	if rel.toward: return MoveTable.Dir.TOWARD
	if rel.away: return MoveTable.Dir.AWAY
	return MoveTable.Dir.NEUTRAL
```
Delete the now-unused `_opponent_is_close()` (the close/far decision now lives in `_current_range`). Keep `_pressed`, `_action_prefix`, `get_input_direction`, `wants_to_run`, `wants_to_block`.

- [ ] **Step 7: Run the FULL suite, expect green.**
```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -gprefix=test_ -gsuffix=.gd -ginclude_subdirs -gexit
```

- [ ] **Step 8: Commit**
```bash
git add scripts/combat/move_table.gd tools/build_doink_movetable.gd assets/movetables scripts/player.gd test/unit/test_move_table.gd
git commit -m "feat(control): MoveTable dispatch (range × dir × button) + Doink data"
```

---

## Task 10: Getup — visual + mash-to-recover (TDD)

**Files:** Modify `scripts/fighter.gd`; extend `test/unit/test_fighter_control.gd`

When a knockdown's down-time ends, play `get_up_front/back` before returning control; mashing during the down-time shortens it (floor applies).

- [ ] **Step 1: Write failing tests** — append to `test/unit/test_fighter_control.gd`
```gdscript
func test_mash_reduces_remaining_getup_time():
	var f := _at(0, Fighter.Side.PLAYER)
	f._react_timer = 2.0
	f.mode = Fighter.Mode.ONGROUND
	var before := f._react_timer
	f.mash_recover()
	assert_lt(f._react_timer, before, "a mash press shortens the down-time")

func test_mash_cannot_go_below_floor():
	var f := _at(0, Fighter.Side.PLAYER)
	f.mode = Fighter.Mode.ONGROUND
	f._react_timer = 0.05
	f.mash_recover()
	assert_gte(f._react_timer, 0.0, "never negative")
```

- [ ] **Step 2: Run, expect fail** (`mash_recover` undefined).

- [ ] **Step 3: Implement** — in `scripts/fighter.gd`:
```gdscript
const _MASH_REDUCE := 0.08   # seconds shaved per mash press (arcade GETUP mash)

## Called when the player presses anything while downed — speeds up getup.
func mash_recover() -> void:
	if mode == Mode.ONGROUND and _react_timer > 0.0:
		_react_timer = maxf(_react_timer - _MASH_REDUCE, 0.0)
```
Add the getup visual: when a reaction timer expires while `ONGROUND`, play the getup anim. In `_physics_process` phase 1, change the expiry handling:
```gdscript
	if _react_timer > 0.0:
		_react_timer -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		global_position = MovementMath.clamp_to_floor(global_position, floor_min_y, floor_max_y)
		if _react_timer <= 0.0:
			if mode == Mode.ONGROUND and sprite != null:
				var anim := "get_up_back" if _facing < 0.0 else "get_up_front"
				if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim):
					sprite.play(anim)
			mode = _react_recover_mode
		return
```
Wire mash in `scripts/player.gd` — call `mash_recover()` on any attack/direction press while downed. In `_unhandled_input`, before the `input_allowed` early-return:
```gdscript
func _unhandled_input(_event: InputEvent) -> void:
	if mode == Mode.ONGROUND:
		var p := _action_prefix()
		if _pressed(p + "punch") or _pressed(p + "kick") or _pressed(p + "high_punch") \
				or _pressed(p + "high_kick") or _pressed(p + "left") or _pressed(p + "right"):
			mash_recover()
		return
	if not Fighter.input_allowed(mode) or is_attacking():
		return
	# ... rest unchanged ...
```

- [ ] **Step 4: Run, expect pass.** Full suite green.

- [ ] **Step 5: Commit**
```bash
git add scripts/fighter.gd scripts/player.gd test/unit/test_fighter_control.gd
git commit -m "feat(control): getup visual + mash-to-recover shortens knockdown"
```

---

## Task 11: Sandbox training dummy + playtest + tag

**Files:** Modify `scenes/Sandbox.tscn`

- [ ] **Step 1: Set sides + add a dummy** — edit `scenes/Sandbox.tscn`
  - On the existing `Player1` node, add `side = 1` is NOT wanted — keep Player1 as PLAYER (side 0, the default; no line needed).
  - On `Player2`, set it to the enemy side so Player1 targets it: add the property line `side = 1` under the Player2 node (1 = `Side.ENEMY`).
  - Add a stationary enemy dummy: instance `res://scenes/Fighter.tscn` as a node named `Dummy`, child of the root, at a visible position, with `side = 1`. Mirror how `Player1`/`Player2` are declared (they `instance=ExtResource("1")`); the Dummy uses the same Fighter scene WITHOUT the Player script, so it just stands, targetable and hittable. Example node block:
    ```
    [node name="Dummy" parent="." instance=ExtResource("1")]
    position = Vector2(640, 500)
    side = 1
    ```
  Keep the rest of the scene byte-for-byte. Verify with the full suite (the sandbox-instantiation test loads this scene).

- [ ] **Step 2: Build + run the full suite (regression)**
```bash
godot --headless --path . --import
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -gprefix=test_ -gsuffix=.gd -ginclude_subdirs -gexit
```
Expected: all green.

- [ ] **Step 3: Playtest — verify Definition of Done**
```bash
godot --path .
```
- [ ] Player1 auto-faces the nearest enemy (Player2 / Dummy) and turns when the nearest changes.
- [ ] Walking away from the target is slightly slower; closing on a downed target is faster.
- [ ] Hold `I` → runs (noticeably faster, with depth drift); a high-kick while running fires the big boot.
- [ ] Hold `K` → blocks; an incoming hit chips ~1 and you can't move/attack while holding.
- [ ] Up close, low punch becomes a headbutt; at range it's a straight punch; high punch = uppercut; low kick = kick.
- [ ] After a knockdown, Doink plays a get-up animation; mashing gets him up faster.
- [ ] No errors about missing animations/sequences/actions.

- [ ] **Step 4: Commit & tag**
```bash
git add scenes/Sandbox.tscn
git commit -m "feat(control): Sandbox training dummy + enemy sides; playtest pass"
git tag sp0-plan2c-targeting-control
```

---

## Definition of Done (Plan 2c)

A player fighter auto-targets the correct opponent via arcade biased scoring, continuously faces it, moves/runs/blocks relative to it with the arcade walk modifiers, fires the right move from the range × relative-direction × button table, and recovers from knockdowns with a getup animation and mash-to-recover. GUT suite green; playtest confirms feel.

## Notes / deferred to later plans

- Motion-buffer specials (double-tap dashes, charge/secret moves), grapples/throws + puppet victim channel (2d), combo scaling, jump/height (Y), multi-enemy AI + waves, ring regions / `INRING` targeting bias, and `_2_`/`_4_` vertical facing anim variants.
- Exact close-gate distance (`_CLOSE_GATE`, currently 70) and mash-reduce rate (`_MASH_REDUCE`, 0.08s) are first-pass values to tune in playtest against the arcade.
- `BACKWARD_MULT`/`OPP_DOWN_MULT`/`RUN_SPEED`/`RUN_DEPTH_DRIFT` were staged in `ArcadeUnits` in 2a and are wired here.
```
