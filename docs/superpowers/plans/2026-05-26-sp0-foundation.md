# SP-0 Plan 1: Foundation & Co-op Movement — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Godot 4 project where two players control Doink fighters that walk 8-way on a depth plane with correct Y-sort and play imported Doink walk/idle animations, backed by a headless unit-test harness with green tests.

**Architecture:** A `Fighter` (`CharacterBody2D`) holds movement + depth-clamp logic delegated to a pure, unit-tested `MovementMath` helper. `Player` subclasses `Fighter` and reads per-player input actions (`p1_*` / `p2_*`). A `Sandbox` scene (Y-sorted `Node2D`) hosts two players over a floor so depth sorting is visible. Gameplay runs in `_physics_process` (fixed 60 Hz).

**Tech Stack:** Godot 4.6.3 (standalone binary), GDScript, GUT 9.x (Godot Unit Test) run headless.

---

## Conventions used in every task

- The Godot binary lives outside the repo. **Export this in every shell you use:**
  ```bash
  export GODOT="/media/pablin/DATOS/JUEGOS/Wrestlemania/Godot_v4.6.3-stable_linux.x86_64"
  ```
- All commands run from the repo root unless stated:
  ```bash
  cd /media/pablin/DATOS/JUEGOS/Wrestlemania/wwfmania-godot
  ```
- Asset source root (read-only originals):
  `/media/pablin/DATOS/JUEGOS/Wrestlemania/WWF Sources/Sprites/Doink_sprites/Doink The Clown`

---

## File structure (created by this plan)

```
wwfmania-godot/
  project.godot                       # Godot project config + input map
  addons/gut/                         # GUT test framework (vendored)
  .gutconfig.json                     # GUT headless config
  scripts/
    movement_math.gd                  # pure movement/depth helpers (class_name MovementMath)
    fighter.gd                        # base fighter (class_name Fighter)
    player.gd                         # input-driven fighter (class_name Player)
  scenes/
    Fighter.tscn                      # CharacterBody2D + AnimatedSprite2D + CollisionShape2D
    Sandbox.tscn                      # Y-sorted room with two players (main scene)
  assets/sprites/doink/
    idle/                             # normalized idle frames
    walk/                             # normalized walk frames
  test/unit/
    test_smoke.gd                     # proves the harness runs
    test_movement_math.gd             # movement/depth unit tests
```

---

## Task 0: Verify the Godot binary

**Files:** none (environment check).

- [ ] **Step 1: Make the binary executable and check the version**

```bash
export GODOT="/media/pablin/DATOS/JUEGOS/Wrestlemania/Godot_v4.6.3-stable_linux.x86_64"
chmod +x "$GODOT"
"$GODOT" --version
```

Expected: prints `4.6.3.stable.official.<hash>`.

- [ ] **Step 2 (optional convenience): symlink onto PATH**

```bash
mkdir -p ~/.local/bin
ln -sf "$GODOT" ~/.local/bin/godot
```

(If you do this and `~/.local/bin` is on PATH, you may use `godot` instead of `"$GODOT"`. The plan uses `"$GODOT"` throughout for certainty.)

---

## Task 1: Initialize the Godot project

**Files:**
- Create: `project.godot`

- [ ] **Step 1: Write a minimal project.godot**

Create `project.godot`:

```ini
; Engine configuration file.
config_version=5

[application]

config/name="wwfmania-godot"
run/main_scene="res://scenes/Sandbox.tscn"
config/features=PackedStringArray("4.6", "GL Compatibility")

[display]

window/size/viewport_width=1280
window/size/viewport_height=720
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[physics]

common/physics_ticks_per_second=60

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

(`Sandbox.tscn` does not exist yet; that's fine — we create it in Task 7 and the editor won't complain until run.)

- [ ] **Step 2: Open the editor once to let Godot initialize the project**

```bash
"$GODOT" --path . -e &
```

Wait for the editor window, confirm the project opens without fatal errors, then close it. This generates the gitignored `.godot/` cache.

- [ ] **Step 3: Verify the project boots headlessly**

```bash
"$GODOT" --headless --path . --quit-after 2
```

Expected: exits cleanly (exit code 0), no "Failed to load project" error. (A warning about the missing main scene is acceptable at this stage.)

- [ ] **Step 4: Commit**

```bash
git add project.godot
git commit -m "chore: initialize Godot 4.6 project"
```

---

## Task 2: Install GUT and a headless test harness

**Files:**
- Create: `addons/gut/` (vendored), `.gutconfig.json`, `test/unit/test_smoke.gd`

- [ ] **Step 1: Vendor GUT into the project**

```bash
git clone --depth 1 https://github.com/bitwes/Gut.git /tmp/gut
mkdir -p addons
cp -r /tmp/gut/addons/gut addons/gut
ls addons/gut/gut_cmdln.gd   # must exist
```

Expected: `addons/gut/gut_cmdln.gd` exists.

- [ ] **Step 2: Create the GUT config**

Create `.gutconfig.json`:

```json
{
  "dirs": ["res://test/unit"],
  "include_subdirs": true,
  "log_level": 1,
  "should_exit": true
}
```

- [ ] **Step 3: Write a smoke test**

Create `test/unit/test_smoke.gd`:

```gdscript
extends "res://addons/gut/test.gd"

func test_harness_runs():
	assert_true(true, "GUT harness is alive")
```

- [ ] **Step 4: Run the harness headlessly**

```bash
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit
```

Expected: output ends with `1 passing` (the smoke test) and the process exits 0.
(If the first run errors about GUT needing import, run `"$GODOT" --headless --path . --quit-after 2` once to import, then re-run.)

- [ ] **Step 5: Commit**

```bash
git add addons/gut .gutconfig.json test/unit/test_smoke.gd
git commit -m "test: vendor GUT and add headless smoke test"
```

---

## Task 3: Movement & depth math (TDD, pure functions)

**Files:**
- Create: `scripts/movement_math.gd`
- Test: `test/unit/test_movement_math.gd`

- [ ] **Step 1: Write the failing tests**

Create `test/unit/test_movement_math.gd`:

```gdscript
extends "res://addons/gut/test.gd"

func test_zero_input_gives_zero_velocity():
	assert_eq(MovementMath.move_velocity(Vector2.ZERO, 100.0), Vector2.ZERO)

func test_right_input_gives_rightward_velocity():
	assert_eq(MovementMath.move_velocity(Vector2.RIGHT, 100.0), Vector2(100.0, 0.0))

func test_diagonal_input_is_normalized_to_speed():
	var v: Vector2 = MovementMath.move_velocity(Vector2(1.0, 1.0), 100.0)
	assert_almost_eq(v.length(), 100.0, 0.01)

func test_clamp_below_band_snaps_to_max_y():
	assert_eq(MovementMath.clamp_to_floor(Vector2(50.0, 999.0), 200.0, 400.0), Vector2(50.0, 400.0))

func test_clamp_above_band_snaps_to_min_y():
	assert_eq(MovementMath.clamp_to_floor(Vector2(50.0, 0.0), 200.0, 400.0), Vector2(50.0, 200.0))

func test_clamp_within_band_unchanged():
	assert_eq(MovementMath.clamp_to_floor(Vector2(50.0, 300.0), 200.0, 400.0), Vector2(50.0, 300.0))
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit
```

Expected: FAIL — errors referencing an unknown identifier `MovementMath`.

- [ ] **Step 3: Write the minimal implementation**

Create `scripts/movement_math.gd`:

```gdscript
class_name MovementMath
## Pure movement/depth helpers. No scene-tree dependencies, fully unit-testable.

## Velocity for an 8-way input direction at the given speed.
## Diagonals are normalized so speed is constant in every direction.
static func move_velocity(input_dir: Vector2, speed: float) -> Vector2:
	if input_dir == Vector2.ZERO:
		return Vector2.ZERO
	return input_dir.normalized() * speed

## Clamp a position's Y into the walkable floor band [floor_min_y, floor_max_y].
static func clamp_to_floor(pos: Vector2, floor_min_y: float, floor_max_y: float) -> Vector2:
	return Vector2(pos.x, clampf(pos.y, floor_min_y, floor_max_y))
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit
```

Expected: `7 passing` (smoke + 6 movement tests), exit 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/movement_math.gd test/unit/test_movement_math.gd
git commit -m "feat: add unit-tested movement and floor-clamp math"
```

---

## Task 4: Base Fighter script + scene

**Files:**
- Create: `scripts/fighter.gd`, `scenes/Fighter.tscn`

- [ ] **Step 1: Write the Fighter script**

Create `scripts/fighter.gd`:

```gdscript
class_name Fighter
extends CharacterBody2D
## Base fighter: depth-plane movement, facing, walk/idle animation.
## Movement input is supplied by subclasses via get_input_direction().

@export var walk_speed: float = 140.0
## Walkable depth band in global Y. The fighter's origin sits at its feet.
@export var floor_min_y: float = 360.0
@export var floor_max_y: float = 660.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

## Subclasses override this to return an 8-way direction (each axis in -1..1).
func get_input_direction() -> Vector2:
	return Vector2.ZERO

func _physics_process(_delta: float) -> void:
	var dir: Vector2 = get_input_direction()
	velocity = MovementMath.move_velocity(dir, walk_speed)
	move_and_slide()
	global_position = MovementMath.clamp_to_floor(global_position, floor_min_y, floor_max_y)
	_update_facing(dir)
	_update_animation(dir)

func _update_facing(dir: Vector2) -> void:
	if dir.x != 0.0:
		sprite.flip_h = dir.x < 0.0

func _update_animation(dir: Vector2) -> void:
	if sprite.sprite_frames == null:
		return
	var anim: String = "walk" if dir != Vector2.ZERO else "idle"
	if sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
		sprite.play(anim)
	elif not sprite.is_playing():
		sprite.play(anim)
```

- [ ] **Step 2: Build the Fighter scene in the editor**

Open the editor (`"$GODOT" --path . -e &`) and create `scenes/Fighter.tscn`:
1. New Scene → choose **CharacterBody2D** as root. Rename it `Fighter`.
2. Attach script `scripts/fighter.gd` to the root (it will resolve via `class_name`, but attaching the file is fine).
3. Add child **AnimatedSprite2D**, named exactly `AnimatedSprite2D`.
4. Add child **CollisionShape2D**; give it a `RectangleShape2D` ~`40 x 24` (a small "feet" footprint near the origin).
5. Save as `res://scenes/Fighter.tscn`.

- [ ] **Step 3: Verify the scene loads headlessly**

```bash
"$GODOT" --headless --path . --quit-after 2
```

Expected: no parse/load errors mentioning `Fighter.tscn` or `fighter.gd`.

- [ ] **Step 4: Commit**

```bash
git add scripts/fighter.gd scenes/Fighter.tscn
git commit -m "feat: base Fighter scene with depth movement and animation switching"
```

---

## Task 5: Player input + input map

**Files:**
- Create: `scripts/player.gd`
- Modify: `project.godot` (input map — added via editor)

- [ ] **Step 1: Add the input actions in the editor**

Editor → **Project → Project Settings → Input Map**. Add these 8 actions and bind the listed key to each (click **+** on the action, then **Add Event → Key**):

Player 1 (WASD):
- `p1_up` → W
- `p1_down` → S
- `p1_left` → A
- `p1_right` → D

Player 2 (arrows):
- `p2_up` → Up Arrow
- `p2_down` → Down Arrow
- `p2_left` → Left Arrow
- `p2_right` → Right Arrow

Save. (Gamepad bindings are deferred to a later plan; two-on-one-keyboard is enough to prove co-op.)

- [ ] **Step 2: Write the Player script**

Create `scripts/player.gd`:

```gdscript
class_name Player
extends Fighter
## A Fighter driven by per-player input actions.
## player_index 0 -> p1_* actions; player_index 1 -> p2_* actions.

@export var player_index: int = 0

func _action_prefix() -> String:
	return "p1_" if player_index == 0 else "p2_"

func get_input_direction() -> Vector2:
	var p: String = _action_prefix()
	return Vector2(
		Input.get_axis(p + "left", p + "right"),
		Input.get_axis(p + "up", p + "down")
	)
```

- [ ] **Step 3: Verify it parses headlessly**

```bash
"$GODOT" --headless --path . --quit-after 2
```

Expected: no parse errors mentioning `player.gd`.

- [ ] **Step 4: Commit**

```bash
git add scripts/player.gd project.godot
git commit -m "feat: per-player input map and Player input controller"
```

---

## Task 6: Import Doink idle + walk animations

**Files:**
- Create: `assets/sprites/doink/idle/*.png`, `assets/sprites/doink/walk/*.png`
- Modify: `scenes/Fighter.tscn` (assign SpriteFrames)

- [ ] **Step 1: Copy and normalize the frames**

Source folders have mixed-case extensions (`1.png`, `2.PNG`, …) and stray `Thumbs.db`. Copy into the repo with normalized, zero-padded lowercase names:

```bash
cd /media/pablin/DATOS/JUEGOS/Wrestlemania/wwfmania-godot
SRC="/media/pablin/DATOS/JUEGOS/Wrestlemania/WWF Sources/Sprites/Doink_sprites/Doink The Clown"

for pair in "Idle front:idle" "Walk horisontal front:walk"; do
  s="${pair%%:*}"; d="${pair##*:}"
  mkdir -p "assets/sprites/doink/$d"
  i=1
  # numeric-sort the PNG frames, skip Thumbs.db, copy as 01.png, 02.png, ...
  find "$SRC/$s" -maxdepth 1 -type f -iname '*.png' \
    | sort -V \
    | while read -r f; do
        printf -v out '%02d.png' "$i"
        cp "$f" "assets/sprites/doink/$d/$out"
        i=$((i+1))
      done
  echo "$d: $(ls assets/sprites/doink/$d | wc -l) frames"
done
```

Expected: `idle: 6 frames`, `walk: <N> frames` (N matches the source walk folder count).

> If `sort -V` mis-orders due to the mixed case, list with `ls "$SRC/$s"` and confirm the numeric order visually; the frames are named `1`..`N`.

- [ ] **Step 2: Import the textures**

```bash
"$GODOT" --headless --path . --quit-after 3
```

This makes Godot generate `.import` files for the new PNGs. Expected: exits cleanly.

- [ ] **Step 3: Build the SpriteFrames in the editor**

Open the editor. Open `scenes/Fighter.tscn`, select the `AnimatedSprite2D`:
1. In the inspector, set **Sprite Frames → New SpriteFrames**, then click it to open the SpriteFrames panel.
2. Rename the default animation `default` to **`idle`**. Use **Add frames from a Sprite Sheet → no**; instead use **Add frames from file(s)** and select all of `assets/sprites/doink/idle/01.png … 06.png` in order. Set FPS ~8, ensure **Loop** is on.
3. Click **New Animation**, name it **`walk`**. Add all `assets/sprites/doink/walk/*.png` in order. Set FPS ~12, **Loop** on.
4. On the `AnimatedSprite2D`, set **Offset** so the feet sit near the node origin (these are 180×180 frames — an offset around `(0, -150)` puts the origin at the feet; tune visually).
5. Save the scene.

- [ ] **Step 4: Verify headless load**

```bash
"$GODOT" --headless --path . --quit-after 2
```

Expected: no errors about missing animations or textures.

- [ ] **Step 5: Commit**

```bash
git add assets/sprites/doink scenes/Fighter.tscn
git commit -m "feat: import Doink idle and walk animations"
```

---

## Task 7: Sandbox scene with two co-op players + Y-sort

**Files:**
- Create: `scenes/Sandbox.tscn`

- [ ] **Step 1: Build the Sandbox scene in the editor**

Create `scenes/Sandbox.tscn`:
1. New Scene → root **Node2D**, rename `Sandbox`. In the inspector enable **Y Sort Enabled = On** (Ordering section).
2. Add a child **ColorRect** named `Floor` for a visible backdrop: set a dark color, size `1280 x 720`, position `(0,0)`. (Place it first so it's behind; it does not participate in Y-sort visually since it's a full-screen backdrop.)
3. Add an instance of `Fighter.tscn` (drag it in, or **Instantiate Child Scene**). Rename to `Player1`. Attach script `scripts/player.gd`, set `player_index = 0`, position `(480, 480)`.
4. Add a second instance of `Fighter.tscn`. Rename to `Player2`. Attach `scripts/player.gd`, set `player_index = 1`, position `(800, 520)`.
5. On both players, confirm `floor_min_y`/`floor_max_y` bracket the floor band (defaults 360–660 are fine for a 720-tall view).
6. Save as `res://scenes/Sandbox.tscn`.

> Note: For Y-sort to order the two players by depth, both are direct children of the Y-sorted `Sandbox` node, and their origins are at the feet (Task 6 Step 3.4). The player lower on screen (greater Y) draws in front.

- [ ] **Step 2: Verify headless load**

```bash
"$GODOT" --headless --path . --quit-after 2
```

Expected: clean exit, no errors loading `Sandbox.tscn`.

- [ ] **Step 3: Commit**

```bash
git add scenes/Sandbox.tscn
git commit -m "feat: co-op sandbox scene with two players and Y-sort"
```

---

## Task 8: Manual playtest + Definition of Done

**Files:** none (verification).

- [ ] **Step 1: Run the game**

```bash
"$GODOT" --path . &
```

- [ ] **Step 2: Verify the Definition of Done**

Confirm by playing:
- [ ] Player 1 walks 8-way with **WASD**; Player 2 walks 8-way with **arrow keys** — simultaneously.
- [ ] Each player faces left/right based on horizontal movement (sprite flips).
- [ ] The `walk` animation plays while moving, `idle` while still.
- [ ] Walking up/down changes depth: the player with the greater Y (lower on screen) **draws in front** of the other when they overlap.
- [ ] Neither player can walk outside the floor band (Y clamped).

- [ ] **Step 3: Re-run the full test suite (regression)**

```bash
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit
```

Expected: all tests passing, exit 0.

- [ ] **Step 4: Tag the milestone**

```bash
git tag sp0-plan1-foundation
git log --oneline | head -10
```

---

## Definition of Done (Plan 1)

Two players walk a room in local co-op (WASD vs arrows), with 8-way depth-plane movement, correct Y-sort depth ordering, floor clamping, and walk/idle animations from imported Doink frames — and the GUT suite passes headlessly. This is the runnable base that Plan 2 (combat + assets) builds on.
