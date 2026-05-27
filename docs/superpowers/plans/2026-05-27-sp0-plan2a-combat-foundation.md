# SP-0 Plan 2a: Combat Foundation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Doink moves with arcade-faithful walk speeds in a proper `PLYRMODE` state machine (helpless states ignore input, exactly as the arcade disables control), running on a fixed 60 Hz logic step with an explicit arcade-tick→seconds conversion, with Doink's ENTIRE animation library imported and addressable for later combat plans.

**Architecture:** A pure `ArcadeUnits` module holds the arcade↔our-world conversions (`TSEC=53`, 16.16 fixed-point → px/second). `MovementMath` gains the arcade 8-way walk table (non-normalized cardinal/diagonal). `Fighter` gets a `Mode` state machine whose `input_allowed()` predicate is the real arcade stun mechanism (helpless modes never read input). An importer tool ingests every Doink move folder into one `SpriteFrames` animation each.

**Tech Stack:** Godot 4.6.3, GDScript, GUT (headless). Builds on Plan 1 (tag `sp0-plan1-foundation`).

**Fidelity sources:** `docs/superpowers/research/2026-05-27-arcade-movement-state-dizzy-getup.md` (movement constants, tick model, state machine) and the other two research docs.

---

## Conventions (every task)

```bash
export GODOT="/media/pablin/DATOS/JUEGOS/Wrestlemania/Godot_v4.6.3-stable_linux.x86_64"
cd /media/pablin/DATOS/JUEGOS/Wrestlemania/wwfmania-godot
```
Run tests: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit`
(If GUT/scripts were just added, run `"$GODOT" --headless --path . --import` once first.)

Arcade source (read-only reference): `/home/pablin/Games/wwf-wrestlemania`
Doink PNG sequences (read-only): `/media/pablin/DATOS/JUEGOS/Wrestlemania/WWF Sources/Sprites/Doink_sprites/Doink The Clown`

---

## File structure (this plan)

```
scripts/
  arcade_units.gd     # NEW: TSEC + 16.16->px/s + tick->sec conversions and derived speeds
  movement_math.gd    # MODIFY: replace move_velocity with arcade walk_velocity table
  fighter.gd          # MODIFY: Mode enum + input_allowed(); use walk_velocity; px/s speeds
tools/
  copy_doink_assets.sh   # NEW: copy+normalize ALL Doink move folders into assets/
  build_doink_frames.gd  # MODIFY: scan all assets/sprites/doink/* -> one animation each
assets/sprites/doink/<move>/NN.png   # NEW: full Doink library
test/unit/
  test_arcade_units.gd     # NEW
  test_movement_math.gd    # MODIFY (walk_velocity tests)
  test_fighter_mode.gd     # NEW
  test_scenes.gd           # MODIFY (assert key animations exist)
```

---

## Task 0: Branch

- [ ] **Step 1: Create the working branch**

```bash
git checkout -b combat-foundation
git branch --show-current   # -> combat-foundation
```

---

## Task 1: ArcadeUnits conversion module (TDD)

**Files:** Create `scripts/arcade_units.gd`, `test/unit/test_arcade_units.gd`

- [ ] **Step 1: Write the failing tests**

Create `test/unit/test_arcade_units.gd`:

```gdscript
extends "res://addons/gut/test.gd"

func test_ticks_to_seconds_uses_53():
	assert_almost_eq(ArcadeUnits.ticks_to_seconds(53.0), 1.0, 0.0001)

func test_vel_hex_to_px_per_sec_walk_cardinal():
	# 0x3a000 = 3.625 px/tick; * 53 ticks/s = 192.125 px/s
	assert_almost_eq(ArcadeUnits.vel_to_px_per_sec(0x3a000), 192.125, 0.01)

func test_vel_hex_to_px_per_sec_run():
	# 0x64000 = 6.25 px/tick; * 53 = 331.25 px/s
	assert_almost_eq(ArcadeUnits.vel_to_px_per_sec(0x64000), 331.25, 0.01)

func test_derived_constants():
	assert_almost_eq(ArcadeUnits.WALK_CARDINAL, 192.125, 0.01)
	assert_almost_eq(ArcadeUnits.WALK_DIAGONAL_AXIS, 162.3125, 0.01)
	assert_almost_eq(ArcadeUnits.RUN_SPEED, 331.25, 0.01)
```

- [ ] **Step 2: Run, expect fail** (`ArcadeUnits` undefined).

```bash
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit
```
Expected: parse error referencing `ArcadeUnits`.

- [ ] **Step 3: Implement**

Create `scripts/arcade_units.gd`:

```gdscript
class_name ArcadeUnits
## Conversions from the arcade's tick / 16.16-fixed-point model to our world
## (fixed 60 Hz logic, float, pixels). See research doc 2026-05-27-arcade-movement-*.

## The arcade treats 1 second = 53 ticks (DISPLAY.EQU TSEC). DIRQ is 60 Hz but
## effective dispatch averages ~53/s; speeds-per-second use 53.
const TICKS_PER_SECOND: float = 53.0

## Arcade velocity, written as a 16.16 hex value in px/tick, converted to px/second.
static func vel_to_px_per_sec(hex_per_tick: int) -> float:
	return (float(hex_per_tick) / 65536.0) * TICKS_PER_SECOND

## Arcade duration in ticks -> seconds.
static func ticks_to_seconds(ticks: float) -> float:
	return ticks / TICKS_PER_SECOND

# Derived walk/run speeds (px/second) straight from the arcade velocity table.
const WALK_CARDINAL: float = 192.125        # 0x3a000 (3.625 px/tick)
const WALK_DIAGONAL_AXIS: float = 162.3125  # 0x31000 (3.0625 px/tick, per axis)
const RUN_SPEED: float = 331.25             # 0x64000 (6.25 px/tick, Doink)
const RUN_DEPTH_DRIFT: float = 132.5        # 0x28000 (2.5 px/tick)
const BACKWARD_MULT: float = 0.9
const OPP_DOWN_MULT: float = 1.5
```

- [ ] **Step 4: Run, expect pass.** Expected: the 4 new tests pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/arcade_units.gd test/unit/test_arcade_units.gd
git commit -m "feat: ArcadeUnits tick/fixed-point conversions and derived speeds"
```

---

## Task 2: Arcade 8-way walk velocity (TDD, replaces move_velocity)

**Files:** Modify `scripts/movement_math.gd`, `test/unit/test_movement_math.gd`

- [ ] **Step 1: Replace the move_velocity tests with walk_velocity tests**

In `test/unit/test_movement_math.gd`, replace the three `move_velocity` tests
(`test_zero_input_gives_zero_velocity`, `test_right_input_gives_rightward_velocity`,
`test_diagonal_input_is_normalized_to_speed`) with:

```gdscript
func test_walk_zero_input_is_zero():
	assert_eq(MovementMath.walk_velocity(Vector2.ZERO), Vector2.ZERO)

func test_walk_cardinal_uses_cardinal_speed():
	assert_almost_eq(MovementMath.walk_velocity(Vector2.RIGHT).x, ArcadeUnits.WALK_CARDINAL, 0.01)
	assert_almost_eq(MovementMath.walk_velocity(Vector2.RIGHT).y, 0.0, 0.01)

func test_walk_diagonal_uses_per_axis_diagonal_speed_not_normalized():
	var v: Vector2 = MovementMath.walk_velocity(Vector2(1, 1))
	assert_almost_eq(v.x, ArcadeUnits.WALK_DIAGONAL_AXIS, 0.01)
	assert_almost_eq(v.y, ArcadeUnits.WALK_DIAGONAL_AXIS, 0.01)
	# Arcade diagonals are intentionally faster than cardinal (not normalized).
	assert_gt(v.length(), ArcadeUnits.WALK_CARDINAL)

func test_walk_uses_sign_only_of_input():
	# analog-ish input still snaps to 8-way speeds
	assert_almost_eq(MovementMath.walk_velocity(Vector2(0.3, 0)).x, ArcadeUnits.WALK_CARDINAL, 0.01)
```

(Keep the existing `clamp_to_floor` and `separation_push` tests unchanged.)

- [ ] **Step 2: Run, expect fail** (`walk_velocity` undefined).

- [ ] **Step 3: Implement — replace `move_velocity` with `walk_velocity`**

In `scripts/movement_math.gd`, replace the `move_velocity` function with:

```gdscript
## Arcade 8-way walk velocity in px/second. Uses the SIGN of each input axis;
## cardinal and diagonal use different per-axis speeds (arcade table, not normalized).
static func walk_velocity(input_dir: Vector2) -> Vector2:
	var ix: float = signf(input_dir.x)
	var iy: float = signf(input_dir.y)
	if ix == 0.0 and iy == 0.0:
		return Vector2.ZERO
	if ix != 0.0 and iy != 0.0:
		return Vector2(ix * ArcadeUnits.WALK_DIAGONAL_AXIS, iy * ArcadeUnits.WALK_DIAGONAL_AXIS)
	return Vector2(ix * ArcadeUnits.WALK_CARDINAL, iy * ArcadeUnits.WALK_CARDINAL)
```

- [ ] **Step 4: Run, expect pass.**

- [ ] **Step 5: Commit**

```bash
git add scripts/movement_math.gd test/unit/test_movement_math.gd
git commit -m "feat: arcade 8-way walk velocity table (non-normalized), replaces move_velocity"
```

---

## Task 3: Fighter Mode state machine (TDD)

**Files:** Modify `scripts/fighter.gd`, Create `test/unit/test_fighter_mode.gd`

- [ ] **Step 1: Write failing tests**

Create `test/unit/test_fighter_mode.gd`:

```gdscript
extends "res://addons/gut/test.gd"

func test_input_allowed_only_in_normal_and_running():
	assert_true(Fighter.input_allowed(Fighter.Mode.NORMAL))
	assert_true(Fighter.input_allowed(Fighter.Mode.RUNNING))
	assert_false(Fighter.input_allowed(Fighter.Mode.DIZZY))
	assert_false(Fighter.input_allowed(Fighter.Mode.ONGROUND))
	assert_false(Fighter.input_allowed(Fighter.Mode.INAIR))
	assert_false(Fighter.input_allowed(Fighter.Mode.BLOCK))

func test_fighter_starts_in_normal():
	var f := Fighter.new()
	add_child_autofree(f)
	assert_eq(f.mode, Fighter.Mode.NORMAL)
```

- [ ] **Step 2: Run, expect fail** (`Fighter.Mode`/`input_allowed` undefined).

- [ ] **Step 3: Implement — add the Mode enum, predicate, and gate input**

In `scripts/fighter.gd`, add near the top (after `extends`):

```gdscript
## PLYRMODE-style state (arcade PLYR.EQU MODE_*). Helpless modes never read input —
## that is exactly how the arcade disables control while stunned/down.
enum Mode { NORMAL, RUNNING, INAIR, ONGROUND, BLOCK, DIZZY }
var mode: int = Mode.NORMAL

## Input is only read in NORMAL/RUNNING (arcade: other mode_* handlers are rets).
static func input_allowed(m: int) -> bool:
	return m == Mode.NORMAL or m == Mode.RUNNING
```

Then change `_physics_process` to gate input and use `walk_velocity` (px/second) via
`move_and_slide` (collision_mask is 0, so this just integrates velocity*delta):

```gdscript
func _physics_process(_delta: float) -> void:
	var dir: Vector2 = Vector2.ZERO
	if Fighter.input_allowed(mode):
		dir = get_input_direction()
	velocity = MovementMath.walk_velocity(dir)
	move_and_slide()
	_apply_separation()
	global_position = MovementMath.clamp_to_floor(global_position, floor_min_y, floor_max_y)
	_update_facing(dir)
	_update_animation(dir)
```

Remove the now-unused `@export var walk_speed` line (speeds come from `ArcadeUnits`).

- [ ] **Step 4: Run, expect pass.** Also confirm the existing scene/player tests still pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/fighter.gd test/unit/test_fighter_mode.gd
git commit -m "feat: Fighter Mode state machine; input gated to NORMAL/RUNNING (arcade stun model)"
```

---

## Task 4: Copy Doink's full animation library into the project

**Files:** Create `tools/copy_doink_assets.sh`, create `assets/sprites/doink/<move>/*.png`

- [ ] **Step 1: Write the copy/normalize script**

Create `tools/copy_doink_assets.sh`:

```bash
#!/usr/bin/env bash
# Copy every Doink move folder into assets/, normalizing frame names to NN.png
# (handles mixed-case .png/.PNG and skips Thumbs.db). Animation folder names are
# sanitized to lowercase_snake (Godot-friendly).
set -euo pipefail
SRC="/media/pablin/DATOS/JUEGOS/Wrestlemania/WWF Sources/Sprites/Doink_sprites/Doink The Clown"
DEST="assets/sprites/doink"
rm -rf "$DEST"; mkdir -p "$DEST"

find "$SRC" -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
  raw="$(basename "$dir")"
  anim="$(echo "$raw" | tr '[:upper:] ' '[:lower:]_' | tr -cd 'a-z0-9_' )"
  mkdir -p "$DEST/$anim"
  i=1
  find "$dir" -maxdepth 1 -type f -iname '*.png' | sort -V | while read -r f; do
    printf -v out '%02d.png' "$i"
    cp "$f" "$DEST/$anim/$out"
    i=$((i+1))
  done
  echo "$anim ($(ls "$DEST/$anim" | wc -l) frames)"
done
echo "total animations: $(find "$DEST" -mindepth 1 -maxdepth 1 -type d | wc -l)"
```

- [ ] **Step 2: Run it**

```bash
bash tools/copy_doink_assets.sh
```
Expected: prints each sanitized animation name + frame count, and a total (~80 folders).
Sanity-check a few exist: `ls assets/sprites/doink | grep -E 'idle_front|walk_horisontal_front|mid_punch_front|big_boot'`

- [ ] **Step 3: Import the textures**

```bash
"$GODOT" --headless --path . --import
```
Expected: clean import of the new PNGs (no errors).

- [ ] **Step 4: Commit**

```bash
git add tools/copy_doink_assets.sh assets/sprites/doink
git commit -m "assets: import Doink's full animation library (all move folders)"
```

---

## Task 5: Build a SpriteFrames with one animation per move (TDD)

**Files:** Modify `tools/build_doink_frames.gd`, modify `test/unit/test_scenes.gd`

- [ ] **Step 1: Rewrite the frame builder to scan all move folders**

Replace `tools/build_doink_frames.gd` with:

```gdscript
extends SceneTree
## Build doink_frames.tres: one animation per folder under assets/sprites/doink/.
## Run: godot --headless --path . -s tools/build_doink_frames.gd
## (PNGs must be imported first: godot --headless --path . --import)

const ROOT := "res://assets/sprites/doink"
# Animations that should loop (movement/idle); everything else plays once.
const LOOPING := ["idle_front", "idle_back", "walk_horisontal_front", "walk_horisontal_back",
	"walk_vertical_front", "walk_vertical_back", "walk_diagonal_front", "walk_diagonal_back", "run"]

func _init() -> void:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	var dirs := DirAccess.open(ROOT)
	if dirs == null:
		push_error("cannot open " + ROOT)
		quit(1)
		return
	var anim_names := dirs.get_directories()
	anim_names.sort()
	var count := 0
	for anim in anim_names:
		_add_anim(sf, anim)
		count += 1
	var err := ResourceSaver.save(sf, ROOT + "/doink_frames.tres")
	print("animations: ", count, "  save -> ", error_string(err))
	quit()

func _add_anim(sf: SpriteFrames, anim: String) -> void:
	sf.add_animation(anim)
	sf.set_animation_loop(anim, anim in LOOPING)
	sf.set_animation_speed(anim, 12.0)
	var d := DirAccess.open(ROOT + "/" + anim)
	if d == null:
		return
	var files: Array[String] = []
	for f in d.get_files():
		if f.to_lower().ends_with(".png"):
			files.append(f)
	files.sort()
	for f in files:
		var tex: Texture2D = load(ROOT + "/" + anim + "/" + f)
		sf.add_frame(anim, tex)
```

- [ ] **Step 2: Build the resource**

```bash
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . -s tools/build_doink_frames.gd
```
Expected: `animations: <~80>  save -> OK`.

- [ ] **Step 3: Update the scene animation assertions**

In `test/unit/test_scenes.gd`, replace `test_fighter_has_idle_and_walk_animations` with:

```gdscript
func test_fighter_has_core_doink_animations():
	var f: Node = load("res://scenes/Fighter.tscn").instantiate()
	add_child_autofree(f)
	var spr: AnimatedSprite2D = f.get_node("AnimatedSprite2D")
	assert_not_null(spr.sprite_frames, "AnimatedSprite2D has SpriteFrames")
	for anim in ["idle_front", "walk_horisontal_front", "mid_punch_front", "mid_kick_front", "big_boot"]:
		assert_true(spr.sprite_frames.has_animation(anim), "has animation: " + anim)
```

- [ ] **Step 4: Point Fighter's animation switching at the new names**

In `scripts/fighter.gd` `_update_animation`, the slice uses `idle_front`/`walk_horisontal_front`
until directional animation selection arrives in 2b. Change the chosen names:

```gdscript
func _update_animation(dir: Vector2) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	var anim: String = "walk_horisontal_front" if dir != Vector2.ZERO else "idle_front"
	if sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
		sprite.play(anim)
	elif not sprite.is_playing():
		sprite.play(anim)
```

Also update `Fighter.tscn`'s `AnimatedSprite2D` default `animation = &"idle_front"` (edit the
`.tscn` text: change `animation = &"idle"` to `animation = &"idle_front"`).

- [ ] **Step 5: Run tests, expect pass**

```bash
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit
```
Expected: all tests pass (arcade units, walk_velocity, fighter mode, scenes with core anims, player, sandbox).

- [ ] **Step 6: Commit**

```bash
git add tools/build_doink_frames.gd scripts/fighter.gd scenes/Fighter.tscn test/unit/test_scenes.gd
git commit -m "feat: build full Doink SpriteFrames (one anim per move); wire idle_front/walk"
```

---

## Task 6: Playtest + Definition of Done

**Files:** none (verification — needs the human).

- [ ] **Step 1: Run the game**

```bash
"$GODOT" --path . &
```

- [ ] **Step 2: Verify DoD by playing**

- [ ] Both players walk 8-way; movement *feel/speed* now matches the arcade (noticeably brisk; diagonals slightly faster than cardinals — that's faithful, not a bug).
- [ ] Walk/idle animations still play; facing flips.
- [ ] Depth sort + soft separation still correct (regression from Plan 1).
- [ ] No errors in the Godot output about missing animations.

- [ ] **Step 3: Re-run full suite (regression)**

```bash
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit
```
Expected: all green.

- [ ] **Step 4: Tag**

```bash
git tag sp0-plan2a-combat-foundation
```

---

## Definition of Done (Plan 2a)

Doink walks/idles at arcade-faithful speeds inside a `PLYRMODE` state machine whose helpless
modes ignore input (the real arcade stun mechanism, ready for 2c), on a 60 Hz logic step with an
explicit `TSEC=53` conversion model; his complete animation library is imported and addressable
by move name for the combat work in 2b–2e. GUT suite green.

## Notes / deferred to later sub-plans
- Backward (×0.9) and opponent-down (×1.5) walk multipliers, and run/dash + depth-drift: deferred
  to 2b (they need facing-toward-target and the button model). Constants are already in `ArcadeUnits`.
- Directional animation selection (`_2_`/`_4_` facing variants, vertical/diagonal walk): 2b.
- Jump/gravity (Y axis): 2c/2e as needed (grounded brawler may not need it for Doink's core set).
