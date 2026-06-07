# Jump / Vertical-Axis + Ground Aerials Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a height-off-the-mat physics axis (gravity, launch, landing) and the two ground-launched aerials that ride it — the homing flying kick (HIGH_KICK at range) and the flying clothesline (HIGH_PUNCH from a run).

**Architecture:** A direct port of the arcade per-tick integrator `wrestler_veladd` (`WRESTLE2.ASM:2282`). `Fighter` gains `_height`/`_vy` and a `_step_air()` integration that runs whenever `mode == INAIR`. Aerials are ordinary `MoveSequence`s that fire a new `SET_LAUNCH` frame command; the launch sets vertical velocity (and a face-relative or homing planar velocity) and flips the fighter to `INAIR`, after which gravity carries it down to a landing. `Box3` already carries a Y/height axis — the work is plumbing the real `_height` through hit resolution. Pure helpers (`AerialLaunch` homing math, `FlyingKick` dispatch gate) are unit-tested in isolation; `Fighter`/`Player` are the stateful glue.

**Tech Stack:** Godot 4.6 / GDScript, GUT tests (`test/unit/`).

**Conventions (from CLAUDE.md):**
- Run all tests: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit`
- Run ONE test file: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/<file>.gd -gexit`
- A NEW `class_name` needs the cache rebuilt before the headless runner sees it: `godot --headless --path . --import`
- Regenerate a `.tres` from a tool: `godot --headless --path . -s tools/<tool>.gd` then `godot --headless --path . --import`
- `godot` is on PATH (`/home/pablin/.local/bin/godot`). Commit messages: NO `Co-Authored-By` / "Generated with Claude Code" trailers.

---

## File Structure

**Create:**
- `scripts/combat/aerial_launch.gd` — pure homing-velocity math (`AerialLaunch.leap_velocity`).
- `scripts/combat/flying_kick.gd` — pure dispatch gate (`FlyingKick.gate`), mirrors `HairPickup`.
- `assets/sequences/doink/flying_kick.tres` — authored by the build tool (Task 9).
- `assets/sequences/doink/flying_clothesline.tres` — authored by the build tool (Task 9).
- Test files: `test/unit/test_arcade_units_vertical.gd`, `test_aerial_launch.gd`, `test_flying_kick_gate.gd`, `test_sequence_launch.gd`, `test_fighter_jump.gd`, `test_fighter_jump_render.gd`, `test_hitbox_air.gd`, `test_flying_kick_dispatch.gd`, `test_aerial_integration.gd`.

**Modify:**
- `scripts/arcade_units.gd` — vertical constants + `accel_to_px_per_sec2` helper.
- `scripts/combat/sequence_frame.gd` — `SET_LAUNCH` command + launch payload fields.
- `scripts/combat/sequence_player.gd` — apply `SET_LAUNCH`, surface `consume_launch()` + getters.
- `scripts/fighter.gd` — `_height`/`_vy` state, `_step_air`, `apply_launch`/`_begin_launch`, INAIR integration (in the attacking branch + a standalone tail branch), sprite lift, shadow node.
- `scripts/combat/hitbox.gd` — `INAIR` hurt-box case.
- `scripts/combat/attack_resolver.gd` — pass real `_height` into `Hitbox.boxes_overlap`.
- `scripts/player.gd` — flying-kick dispatch gate swap.
- `tools/build_doink_sequences.gd` — `_aerial` recipe + author the two aerials.
- `tools/build_doink_movetable.gd` — `RUNNING + HIGH_PUNCH → flying_clothesline`.

---

## Task 1: Vertical physics constants in ArcadeUnits

**Files:**
- Modify: `scripts/arcade_units.gd`
- Test: `test/unit/test_arcade_units_vertical.gd`

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_arcade_units_vertical.gd`:

```gdscript
extends "res://addons/gut/test.gd"
## Vertical-axis constants derived straight from the arcade hex (wrestler_veladd).

func test_accel_helper_scales_by_ticks_squared():
	# 0x08000 = 0.5 px/tick^2 -> 0.5 * 53^2 px/s^2.
	assert_almost_eq(ArcadeUnits.accel_to_px_per_sec2(0x08000), 0.5 * 53.0 * 53.0, 0.01)

func test_gravity_constant_matches_arcade_hex():
	# GAME.EQU:436 GRAVITY = 0x08000.
	assert_almost_eq(ArcadeUnits.GRAVITY, ArcadeUnits.accel_to_px_per_sec2(0x08000), 0.01)

func test_max_fall_matches_arcade_hex():
	# WRESTLE2.ASM:2280 MAX_YVEL = -0x1000000 (a velocity).
	assert_almost_eq(ArcadeUnits.MAX_FALL, -ArcadeUnits.vel_to_px_per_sec(0x1000000), 0.01)

func test_flykick_launch_matches_arcade_hex():
	# DNKSEQ2.ASM:902 LEAPATOPP hiYvel = 0x90000.
	assert_almost_eq(ArcadeUnits.FLYKICK_YVEL, ArcadeUnits.vel_to_px_per_sec(0x90000), 0.01)

func test_clothesline_launch_matches_arcade_hex():
	# DNKSEQ2.ASM:2401-2402 ANI_SET_YVEL 0x64000 / ANI_SET_XVEL 0x5c000.
	assert_almost_eq(ArcadeUnits.CLINE_YVEL, ArcadeUnits.vel_to_px_per_sec(0x64000), 0.01)
	assert_almost_eq(ArcadeUnits.CLINE_XVEL, ArcadeUnits.vel_to_px_per_sec(0x5c000), 0.01)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_arcade_units_vertical.gd -gexit`
Expected: FAIL (`accel_to_px_per_sec2`/`GRAVITY` not found).

- [ ] **Step 3: Add the constants + helper**

In `scripts/arcade_units.gd`, after the `vel_to_px_per_sec` function (line 22), add:

```gdscript
## Arcade acceleration (a 16.16 px/tick^2 value) -> px/second^2. Acceleration scales by
## ticks-per-second SQUARED (it is per-tick applied per-tick).
static func accel_to_px_per_sec2(hex_per_tick2: int) -> float:
	return (float(hex_per_tick2) / 65536.0) * TICKS_PER_SECOND * TICKS_PER_SECOND
```

At the end of the file (after line 34), add:

```gdscript
# --- Vertical axis (arcade wrestler_veladd, WRESTLE2.ASM:2282) ---
const GRAVITY: float = 1404.5        # 0x08000/tick^2 (GAME.EQU:436): 0.5 px/tick^2 -> px/s^2
const MAX_FALL: float = -13568.0     # MAX_YVEL -0x1000000 (WRESTLE2.ASM:2280): terminal fall vel
const FLYKICK_YVEL: float = 477.0    # 0x90000 launch (DNKSEQ2.ASM:902 spin/flying kick LEAPATOPP)
const CLINE_YVEL: float = 331.25     # 0x64000 launch (DNKSEQ2.ASM:2401 flying clothesline)
const CLINE_XVEL: float = 304.75     # 0x5c000 forward (DNKSEQ2.ASM:2402 flying clothesline)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_arcade_units_vertical.gd -gexit`
Expected: PASS (6 asserts).

- [ ] **Step 5: Commit**

```bash
git add scripts/arcade_units.gd test/unit/test_arcade_units_vertical.gd
git commit -m "feat(aerials): vertical-axis constants (gravity/launch) from arcade hex"
```

---

## Task 2: AerialLaunch homing-velocity helper (pure)

**Files:**
- Create: `scripts/combat/aerial_launch.gd`
- Test: `test/unit/test_aerial_launch.gd`

The arcade `LEAPATOPP` (`ANIM.EQU:156`) launches the attacker to ARRIVE at the target in `ticks` ticks, computing the per-axis planar velocity and clamping it to per-axis caps (`hiX`, `hiZ`). Our planar plane is `(x = screen X, z = screen depth = global_position.y)`.

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_aerial_launch.gd`:

```gdscript
extends "res://addons/gut/test.gd"
## AerialLaunch.leap_velocity: planar velocity to reach `to` from `from` in `seconds`,
## clamped per-axis. Mirrors arcade LEAPATOPP (ANIM.EQU:156).

func test_reaches_target_in_time_when_under_cap():
	# 200px in 0.5s = 400 px/s, under a 999 cap -> exact.
	var v := AerialLaunch.leap_velocity(Vector2(0, 0), Vector2(200, 0), 0.5, 9999.0, 9999.0)
	assert_almost_eq(v.x, 400.0, 0.01)
	assert_almost_eq(v.y, 0.0, 0.01)

func test_clamps_to_per_axis_cap():
	# 1000px in 0.1s = 10000 px/s, capped at 477.
	var v := AerialLaunch.leap_velocity(Vector2(0, 0), Vector2(1000, 0), 0.1, 477.0, 477.0)
	assert_almost_eq(v.x, 477.0, 0.01)

func test_negative_direction_keeps_sign_under_cap():
	var v := AerialLaunch.leap_velocity(Vector2(300, 0), Vector2(0, 0), 0.5, 9999.0, 9999.0)
	assert_almost_eq(v.x, -600.0, 0.01)

func test_depth_axis_independent():
	var v := AerialLaunch.leap_velocity(Vector2(0, 100), Vector2(0, 160), 0.5, 9999.0, 9999.0)
	assert_almost_eq(v.x, 0.0, 0.01)
	assert_almost_eq(v.y, 120.0, 0.01)

func test_zero_time_yields_zero():
	var v := AerialLaunch.leap_velocity(Vector2(0, 0), Vector2(200, 0), 0.0, 999.0, 999.0)
	assert_eq(v, Vector2.ZERO)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_aerial_launch.gd -gexit`
Expected: FAIL (`AerialLaunch` not found — and the runner may need `--import` first since this references a new class; if so run `godot --headless --path . --import` then re-run, expecting the class still undefined until Step 3).

- [ ] **Step 3: Create the helper**

Create `scripts/combat/aerial_launch.gd`:

```gdscript
class_name AerialLaunch
## Homing leap velocity (arcade LEAPATOPP, ANIM.EQU:156): the planar (X, depth) velocity that
## carries a fighter from `from` to `to` in `seconds`, clamped to per-axis caps. Vertical (Y) is
## launched separately at a fixed velocity; this is only the ground-plane component.

## `from`/`to` are world positions (x = screen X, y = screen depth). Returns (vx, vz) in px/s.
static func leap_velocity(from: Vector2, to: Vector2, seconds: float, cap_x: float, cap_z: float) -> Vector2:
	if seconds <= 0.0:
		return Vector2.ZERO
	var vx := clampf((to.x - from.x) / seconds, -cap_x, cap_x)
	var vz := clampf((to.y - from.y) / seconds, -cap_z, cap_z)
	return Vector2(vx, vz)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . --import` then
`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_aerial_launch.gd -gexit`
Expected: PASS (6 asserts).

- [ ] **Step 5: Commit**

```bash
git add scripts/combat/aerial_launch.gd scripts/combat/aerial_launch.gd.uid test/unit/test_aerial_launch.gd
git commit -m "feat(aerials): AerialLaunch homing leap-velocity helper (LEAPATOPP)"
```

---

## Task 3: FlyingKick dispatch gate (pure)

**Files:**
- Create: `scripts/combat/flying_kick.gd`
- Test: `test/unit/test_flying_kick_gate.gd`

Arcade `#super_kick` (`DNK.ASM:1848`): `NORMAL` target WITHIN the 60×60 box → close super (out of scope); OUTSIDE → the jumping/flying kick. A downed (`ONGROUND`) foe routes to the stomp branch, never the flying kick. We reuse the existing `Proximity.is_within` (`scripts/combat/proximity.gd`).

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_flying_kick_gate.gd`:

```gdscript
extends "res://addons/gut/test.gd"
## FlyingKick.gate: standing foe OUTSIDE the 60x60 close box -> flying kick (arcade #super_kick).

func test_far_standing_foe_triggers():
	# dx 120 (>= 60) -> outside the close box -> flying kick.
	assert_true(FlyingKick.gate(Vector2(0, 400), Vector2(120, 400), Fighter.Mode.NORMAL))

func test_close_foe_within_box_rejects():
	# dx 40, dz 0 -> within 60x60 -> close super (not a flying kick).
	assert_false(FlyingKick.gate(Vector2(0, 400), Vector2(40, 400), Fighter.Mode.NORMAL))

func test_far_in_depth_only_triggers():
	# dx 0 but dz 80 (>= 60) -> outside the box (OR semantics) -> flying kick.
	assert_true(FlyingKick.gate(Vector2(0, 400), Vector2(0, 480), Fighter.Mode.NORMAL))

func test_downed_foe_rejects():
	# ONGROUND -> arcade routes to the stomp branch, never the flying kick.
	assert_false(FlyingKick.gate(Vector2(0, 400), Vector2(120, 400), Fighter.Mode.ONGROUND))
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_flying_kick_gate.gd -gexit`
Expected: FAIL (`FlyingKick` not found).

- [ ] **Step 3: Create the gate**

Create `scripts/combat/flying_kick.gd`:

```gdscript
class_name FlyingKick
## Arcade flying-kick gate (DNK.ASM:1848 #super_kick). HIGH_KICK against a STANDING foe that sits
## OUTSIDE the 60x60 "close" box becomes the homing jump kick; a foe inside the box gets the close
## super move (out of scope here), and a downed foe gets the stomp branch. `range_max` in the arcade
## is 999 (effectively unbounded above), so there is only a LOWER bound.

const LEAP_MIN_DX := 60.0   # arcade #super_kick close-box DX
const LEAP_MIN_DZ := 60.0   # arcade #super_kick close-box DZ

## True iff a NORMAL-range HIGH_KICK press should become a flying kick rather than the standing kick.
static func gate(attacker_pos: Vector2, target_pos: Vector2, target_mode: int) -> bool:
	if target_mode == Fighter.Mode.ONGROUND:
		return false
	# Within the 60x60 box -> close super (skip). Outside (either axis beyond) -> flying kick.
	return not Proximity.is_within(attacker_pos, target_pos, LEAP_MIN_DX, LEAP_MIN_DZ)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . --import` then
`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_flying_kick_gate.gd -gexit`
Expected: PASS (4 asserts).

- [ ] **Step 5: Commit**

```bash
git add scripts/combat/flying_kick.gd scripts/combat/flying_kick.gd.uid test/unit/test_flying_kick_gate.gd
git commit -m "feat(aerials): FlyingKick dispatch gate (>=60px standing foe)"
```

---

## Task 4: SET_LAUNCH command + launch fields on SequenceFrame

**Files:**
- Modify: `scripts/combat/sequence_frame.gd`

No standalone test (data resource); covered by Task 5.

- [ ] **Step 1: Add the command code**

In `scripts/combat/sequence_frame.gd`, extend the `Command` enum (currently ends `CLR_OPP_MODE = 10,` at line 16). Add:

```gdscript
	CLR_OPP_MODE = 10,  # restore the victim from opp_mode
	SET_LAUNCH = 11,    # launch the attacker airborne (ANI_SET_YVEL / LEAPATOPP); enters INAIR
}
```

- [ ] **Step 2: Add the launch payload fields + export hint**

Update the `@export_enum` for `command` (line 21-23) to include the new name, and add the payload fields after the `sound` field (line 35):

```gdscript
	@export_enum("NONE", "STARTATTACK", "ATTACK_ON", "ATTACK_OFF", "WAIT_HIT_OPP",
		"SET_ATTACH", "SLAVE_ANIM", "DAMAGE_OPP", "DETACH", "SET_OPP_MODE", "CLR_OPP_MODE",
		"SET_LAUNCH")
	var command: int = Command.NONE
```

After line 35 (`@export var sound: SoundEntry = null`), add:

```gdscript
## --- SET_LAUNCH payload (arcade ANI_SET_YVEL / ANI_SET_XVEL / LEAPATOPP). Values are 16.16
## px/tick hex, converted by ArcadeUnits.vel_to_px_per_sec when the launch fires. ---
@export var launch_yvel: int = 0     # upward launch velocity (e.g. 0x90000 fly kick, 0x64000 cline)
@export var launch_xvel: int = 0     # face-relative forward velocity (cline 0x5c000; 0 if homing)
@export var launch_homing: bool = false   # true -> compute planar velocity toward the target (LEAPATOPP)
@export var leap_ticks: int = 0      # LEAPATOPP arrival time (ticks); only used when homing
@export var leap_cap_x: int = 0      # LEAPATOPP per-axis X cap (16.16 px/tick); only used when homing
@export var leap_cap_z: int = 0      # LEAPATOPP per-axis Z cap (16.16 px/tick); only used when homing
```

- [ ] **Step 3: Verify it parses**

Run: `godot --headless --path . --import`
Expected: no parse errors reported for `sequence_frame.gd`.

- [ ] **Step 4: Commit**

```bash
git add scripts/combat/sequence_frame.gd
git commit -m "feat(aerials): SET_LAUNCH sequence command + launch payload fields"
```

---

## Task 5: SequencePlayer applies SET_LAUNCH and surfaces it

**Files:**
- Modify: `scripts/combat/sequence_player.gd`
- Test: `test/unit/test_sequence_launch.gd`

`SET_LAUNCH` is a one-shot intent (like `DAMAGE_OPP`): the player records it, `Fighter` reads-and-clears it after `advance()` and resolves the geometry.

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_sequence_launch.gd`:

```gdscript
extends "res://addons/gut/test.gd"
## SequencePlayer surfaces a SET_LAUNCH frame as a one-shot consume_launch() + param getters.

func _launch_seq() -> MoveSequence:
	var m := MoveSequence.new()
	m.id = "t"; m.anim_name = "x"
	var f0 := SequenceFrame.new()
	f0.duration_ticks = 2; f0.anim_frame = 0
	f0.command = SequenceFrame.Command.SET_LAUNCH
	f0.launch_yvel = 0x90000
	f0.launch_homing = true
	f0.leap_ticks = 11
	f0.leap_cap_x = 0x50000
	f0.leap_cap_z = 0x50000
	var f1 := SequenceFrame.new()
	f1.duration_ticks = 2; f1.anim_frame = 1
	m.frames = [f0, f1]
	return m

func test_launch_fires_once_then_clears():
	var sp := SequencePlayer.new()
	sp.play(_launch_seq())
	sp.advance(1.0 / 60.0)            # enters frame 0 -> SET_LAUNCH
	assert_true(sp.consume_launch(), "launch intent set on the SET_LAUNCH frame")
	assert_false(sp.consume_launch(), "read-and-clear: second read is false")

func test_launch_params_exposed():
	var sp := SequencePlayer.new()
	sp.play(_launch_seq())
	sp.advance(1.0 / 60.0)
	assert_eq(sp.launch_yvel(), 0x90000)
	assert_true(sp.launch_homing())
	assert_eq(sp.leap_ticks(), 11)
	assert_eq(sp.leap_cap_x(), 0x50000)
	assert_eq(sp.leap_cap_z(), 0x50000)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_sequence_launch.gd -gexit`
Expected: FAIL (`consume_launch` not found).

- [ ] **Step 3: Add the launch state, command handler, and getters**

In `scripts/combat/sequence_player.gd`, after line 24 (`var _opp_mode: int = 0`), add the launch state:

```gdscript
	var _pending_launch: bool = false
	var _launch_yvel: int = 0
	var _launch_xvel: int = 0
	var _launch_homing: bool = false
	var _leap_ticks: int = 0
	var _leap_cap_x: int = 0
	var _leap_cap_z: int = 0
```

In `play()` reset block (after `_pending_clr_opp_mode = false`, line 51), add:

```gdscript
		_pending_launch = false
```

Add the consume + getters next to the other consumers (after `consume_clr_opp_mode`, line 95):

```gdscript
	func consume_launch() -> bool:
		var v := _pending_launch; _pending_launch = false; return v
	func launch_yvel() -> int: return _launch_yvel
	func launch_xvel() -> int: return _launch_xvel
	func launch_homing() -> bool: return _launch_homing
	func leap_ticks() -> int: return _leap_ticks
	func leap_cap_x() -> int: return _leap_cap_x
	func leap_cap_z() -> int: return _leap_cap_z
```

In `_apply_command`, add a case before the `_:` default (after the `CLR_OPP_MODE` case, line 197):

```gdscript
			SequenceFrame.Command.SET_LAUNCH:
				_pending_launch = true
				_launch_yvel = f.launch_yvel
				_launch_xvel = f.launch_xvel
				_launch_homing = f.launch_homing
				_leap_ticks = f.leap_ticks
				_leap_cap_x = f.leap_cap_x
				_leap_cap_z = f.leap_cap_z
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_sequence_launch.gd -gexit`
Expected: PASS (7 asserts).

- [ ] **Step 5: Commit**

```bash
git add scripts/combat/sequence_player.gd test/unit/test_sequence_launch.gd
git commit -m "feat(aerials): SequencePlayer applies + surfaces SET_LAUNCH"
```

---

## Task 6: Fighter height physics — state, integration, launch, landing

**Files:**
- Modify: `scripts/fighter.gd`
- Test: `test/unit/test_fighter_jump.gd`

This is the core. `apply_launch()` flips the fighter to `INAIR` and seeds velocity; `_step_air()` integrates each tick and lands; `_begin_launch()` resolves the sequence launch params (homing vs forward) into a planar velocity.

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_fighter_jump.gd`:

```gdscript
extends "res://addons/gut/test.gd"
## Fighter height physics: apply_launch -> INAIR, rises then lands back to the mat.

const FRAME: float = 1.0 / 60.0

func test_launch_enters_inair():
	var f := Fighter.new()
	add_child_autofree(f)
	f.mode = Fighter.Mode.NORMAL
	f.apply_launch(ArcadeUnits.FLYKICK_YVEL, Vector2.ZERO)
	assert_eq(f.mode, Fighter.Mode.INAIR)
	assert_gt(f._vy, 0.0, "seeded with upward velocity")

func test_rises_then_lands():
	var f := Fighter.new()
	add_child_autofree(f)
	f.mode = Fighter.Mode.NORMAL
	f.apply_launch(ArcadeUnits.FLYKICK_YVEL, Vector2.ZERO)
	var max_h := 0.0
	var landed := false
	for _i in range(180):
		f._physics_process(FRAME)
		max_h = maxf(max_h, f._height)
		if f.mode == Fighter.Mode.NORMAL:
			landed = true
			break
	assert_gt(max_h, 50.0, "rose meaningfully off the mat")
	assert_true(landed, "returned to NORMAL on landing")
	assert_almost_eq(f._height, 0.0, 0.001, "height clamped to the mat")
	assert_almost_eq(f._vy, 0.0, 0.001, "vertical velocity cleared on landing")

func test_planar_velocity_carries_horizontally():
	var f := Fighter.new()
	add_child_autofree(f)
	f.mode = Fighter.Mode.NORMAL
	f.global_position = Vector2(0, 400)
	f.apply_launch(ArcadeUnits.FLYKICK_YVEL, Vector2(200, 0))
	for _i in range(8):
		f._physics_process(FRAME)
	assert_gt(f.global_position.x, 0.0, "moved forward in the air")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_fighter_jump.gd -gexit`
Expected: FAIL (`apply_launch`/`_height` not found).

- [ ] **Step 3: Add state + methods**

In `scripts/fighter.gd`, after line 80 (`var _react_recover_mode: int = Mode.NORMAL`), add:

```gdscript
var _height: float = 0.0   # altitude in px above the mat (0 = grounded). Render-up axis.
var _vy: float = 0.0       # vertical velocity, px/s (+up). Arcade OBJ_YVEL (WRESTLE2.ASM:2282).
```

Add these methods near `start_move` (e.g. after `start_move`, before `_drive_victim` at line 531):

```gdscript
## Launch the fighter airborne (arcade ANI_SET_YVEL / LEAPATOPP). `planar` is the (X, depth)
## velocity in px/s that carries the body across the ground plane during the arc.
func apply_launch(yvel: float, planar: Vector2) -> void:
	mode = Mode.INAIR
	_vy = yvel
	velocity = planar

## Resolve a SequencePlayer SET_LAUNCH into a concrete launch. Homing computes the planar
## velocity toward the current target (LEAPATOPP); otherwise a face-relative forward push.
func _begin_launch() -> void:
	var yvel := ArcadeUnits.vel_to_px_per_sec(_player.launch_yvel())
	var planar := Vector2.ZERO
	if _player.launch_homing() and target != null and is_instance_valid(target):
		var seconds := ArcadeUnits.ticks_to_seconds(_player.leap_ticks())
		var cap_x := ArcadeUnits.vel_to_px_per_sec(_player.leap_cap_x())
		var cap_z := ArcadeUnits.vel_to_px_per_sec(_player.leap_cap_z())
		planar = AerialLaunch.leap_velocity(global_position, target.global_position, seconds, cap_x, cap_z)
	else:
		planar = Vector2(ArcadeUnits.vel_to_px_per_sec(_player.launch_xvel()) * _facing, 0.0)
	apply_launch(yvel, planar)

## Integrate the vertical arc one tick (arcade wrestler_veladd). Carries the planar velocity
## across the ground plane; on landing, zeroes vertical + planar velocity and recovers to NORMAL.
func _step_air(delta: float) -> void:
	_vy -= ArcadeUnits.GRAVITY * delta
	_vy = maxf(_vy, ArcadeUnits.MAX_FALL)
	_height += _vy * delta
	if _height <= 0.0:
		_height = 0.0
		_vy = 0.0
		velocity = Vector2.ZERO
		mode = Mode.NORMAL
		return
	move_and_slide()
	global_position = MovementMath.clamp_to_floor(global_position, floor_min_y, floor_max_y)
```

- [ ] **Step 4: Wire integration into `_physics_process`**

In the attacking branch, replace the unconditional `velocity = Vector2.ZERO` (line 172) with:

```gdscript
		if mode == Mode.INAIR:
			_step_air(delta)
		else:
			velocity = Vector2.ZERO
```

Immediately after `_player.advance(delta)` (line 193), add the launch consume:

```gdscript
		if _player.consume_launch():
			_begin_launch()
```

Add a standalone airborne-tail branch so a descent that outlives its sequence still lands. Insert it AFTER the block-mode `elif` (after line 242 `_block_bouncing = false`) and BEFORE the `# 3) Normal movement` comment (line 244):

```gdscript
	# Airborne tail: the launching move ended but we're still descending. Finish the arc
	# (no input, no walk) until we touch the mat, then recover to NORMAL.
	if mode == Mode.INAIR:
		_step_air(delta)
		return
```

- [ ] **Step 5: Run test to verify it passes**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_fighter_jump.gd -gexit`
Expected: PASS (6 asserts).

- [ ] **Step 6: Run the full suite (no regressions)**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit`
Expected: all green (the new branch is inert while grounded — `mode` is never `INAIR` for existing moves).

- [ ] **Step 7: Commit**

```bash
git add scripts/fighter.gd test/unit/test_fighter_jump.gd
git commit -m "feat(aerials): Fighter height physics — launch, gravity integration, landing"
```

---

## Task 7: Render the altitude (sprite lift + ground shadow)

**Files:**
- Modify: `scripts/fighter.gd`
- Test: `test/unit/test_fighter_jump_render.gd`

The sprite lifts up the screen by `_height` (screen +y is down, so subtract). A simple drawn ground shadow stays at the body origin so the leap reads.

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_fighter_jump_render.gd`:

```gdscript
extends "res://addons/gut/test.gd"
## Altitude rendering: the sprite offset lifts by _height; a shadow node exists at the feet.

func test_sprite_lifts_with_height():
	var f := Fighter.new()
	add_child_autofree(f)
	await get_tree().process_frame   # let _ready wire @onready sprite + shadow
	if f.sprite == null:
		pass_test("no AnimatedSprite2D in the bare Fighter; lift is a no-op")
		return
	var base := f.sprite.offset.y
	f._height = 80.0
	f._refresh_flip()
	assert_almost_eq(f.sprite.offset.y, base - 80.0, 0.01, "sprite lifted up by _height")

func test_shadow_node_created():
	var f := Fighter.new()
	add_child_autofree(f)
	await get_tree().process_frame
	assert_not_null(f.get_node_or_null("Shadow"), "a ground shadow node exists")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_fighter_jump_render.gd -gexit`
Expected: FAIL (no `Shadow` node; offset not lifted).

- [ ] **Step 3: Lift the sprite by `_height` in `_refresh_flip`**

In `scripts/fighter.gd`, in `_refresh_flip()` (line 343), change the `offset.y` line to subtract the altitude:

```gdscript
		sprite.offset.y = _ANIM_Y_OFFSET.get(sprite.animation, 0.0) - _height
```

- [ ] **Step 4: Create the shadow node in `_ready`**

`Fighter` already has an `@onready var sprite` (line 93). Find the existing `_ready()` (search `func _ready`); if one exists, append the shadow setup at its end. If none exists, add:

```gdscript
func _ready() -> void:
	_ensure_shadow()

## A simple elliptical ground shadow drawn at the body origin. Stays on the mat while the sprite
## lifts, so an airborne fighter reads as off the ground (the arcade draws a separate shadow obj).
func _ensure_shadow() -> void:
	if get_node_or_null("Shadow") != null:
		return
	var sh := _Shadow.new()
	sh.name = "Shadow"
	sh.z_index = -1   # behind the body
	add_child(sh)

class _Shadow extends Node2D:
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))   # squash to an ellipse
		draw_circle(Vector2.ZERO, 26.0, Color(0, 0, 0, 0.35))
```

> NOTE: if a `_ready()` already exists, do NOT add a second one — append `_ensure_shadow()` to the existing body and add only the `_ensure_shadow()` + `_Shadow` definitions.

- [ ] **Step 5: Run test to verify it passes**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_fighter_jump_render.gd -gexit`
Expected: PASS.

- [ ] **Step 6: Run the full suite**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit`
Expected: all green (grounded `_height == 0` leaves `offset.y` unchanged).

- [ ] **Step 7: Commit**

```bash
git add scripts/fighter.gd test/unit/test_fighter_jump_render.gd
git commit -m "feat(aerials): render altitude — sprite lift + ground shadow node"
```

---

## Task 8: Air-aware hit detection

**Files:**
- Modify: `scripts/combat/hitbox.gd`, `scripts/combat/attack_resolver.gd`
- Test: `test/unit/test_hitbox_air.gd`

`Box3` already carries Y; the resolver just hard-codes `0.0`. Pass the real `_height` so an airborne attacker's box rises with it, and add an `INAIR` hurt-box case.

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_hitbox_air.gd`:

```gdscript
extends "res://addons/gut/test.gd"
## Box3 already has a Y axis; verify the height parameter actually separates boxes vertically,
## and that hurt_box_for_mode handles INAIR.

func _box(w: float, h: float, d: float, oy: float) -> Box3:
	var b := Box3.new(); b.size = Vector3(w, h, d); b.offset = Vector3(0, oy, 0); return b

func test_height_separates_boxes_vertically():
	var a := _box(40, 40, 40, 0)
	var b := _box(40, 40, 40, 0)
	# Same X/Z. At equal height they overlap; lift one by 200 and they no longer do.
	assert_true(Hitbox.boxes_overlap(a, Vector2(0, 400), 1.0, 0.0, b, Vector2(0, 400), 1.0, 0.0))
	assert_false(Hitbox.boxes_overlap(a, Vector2(0, 400), 1.0, 0.0, b, Vector2(0, 400), 1.0, 200.0))

func test_inair_hurt_box_exists():
	var hb := Hitbox.hurt_box_for_mode(Fighter.Mode.INAIR)
	assert_not_null(hb)
	assert_gt(hb.size.y, 0.0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_hitbox_air.gd -gexit`
Expected: the first two asserts PASS (Box3 already supports height), `test_inair_hurt_box_exists` PASSES too only if the default `_` arm returns a box — it does (depth 60). So this test likely PASSES already; if so, it documents the contract. Proceed to make the resolver pass real height (the behavioral change).

> If `test_inair_hurt_box_exists` passes via the default arm, that is acceptable — Step 3 still adds an explicit `INAIR` arm for clarity and future tuning.

- [ ] **Step 3: Add an explicit INAIR hurt-box arm**

In `scripts/combat/hitbox.gd`, in `hurt_box_for_mode` (line 16-19), add an `INAIR` case:

```gdscript
	match mode:
		Fighter.Mode.ONGROUND: depth = 30.0
		Fighter.Mode.RUNNING: depth = 10.0
		Fighter.Mode.INAIR: depth = 50.0   # airborne torso (arcade in-air hit volume, approximated)
		_: depth = 60.0
```

- [ ] **Step 4: Pass real `_height` into the resolver overlap**

In `scripts/combat/attack_resolver.gd`, in `_closest_overlapping` (line 54-55), replace the hard-coded `0.0` heights with the fighters' altitudes:

```gdscript
			if not Hitbox.boxes_overlap(atk_box, attacker.global_position, attacker.facing(), attacker._height,
					hb, victim.global_position, victim.facing(), victim._height):
```

- [ ] **Step 5: Run test + full suite**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_hitbox_air.gd -gexit`
Expected: PASS.
Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit`
Expected: all green (grounded fighters have `_height == 0`, so behavior is unchanged for existing moves).

- [ ] **Step 6: Commit**

```bash
git add scripts/combat/hitbox.gd scripts/combat/attack_resolver.gd test/unit/test_hitbox_air.gd
git commit -m "feat(aerials): air-aware hit detection (real height + INAIR hurt box)"
```

---

## Task 9: Author the two aerial sequences + wire the clothesline into the MoveTable

**Files:**
- Modify: `tools/build_doink_sequences.gd`, `tools/build_doink_movetable.gd`
- Create (generated): `assets/sequences/doink/flying_kick.tres`, `assets/sequences/doink/flying_clothesline.tres`

The arcade sequences: flying kick `dnk_2_spin_kick_anim` (`DNKSEQ2.ASM:888`) — `STARTATTACK` frame 15, `LEAPATOPP 11,_,50,50,0x90000,head,…`, `ATTACK_ON 46,76,42,42`. Flying clothesline `dnk_fly_cline_anim` (`DNKSEQ2.ASM:2387`) — `SET_YVEL 0x64000` + `SET_XVEL 0x5c000`, `ATTACK_ON 25,6,23,37`.

- [ ] **Step 1: Add the `_aerial` recipe**

In `tools/build_doink_sequences.gd`, add a recipe helper (place it after the `_strike` function, before `_grab_box`). It walks the whole clip like `_strike`, fires `SET_LAUNCH` on the launch frame, and opens the attack box on the contact frame:

```gdscript
## An aerial strike: walks the whole clip; frame `launch` fires SET_LAUNCH (airborne), the box
## is live from `contact` to `contact+2`. `homing` true -> LEAPATOPP toward the target (flying
## kick); false -> a fixed face-relative forward launch (clothesline).
func _aerial(id: String, anim_name: String, amode: int, frame_count: int, launch: int, contact: int, box: Box3,
		yvel: int, xvel: int, homing: bool, leap_ticks: int, cap_x: int, cap_z: int, ticks_per_frame: int = 3, anim_back: String = "") -> MoveSequence:
	var m := MoveSequence.new()
	m.id = id; m.anim_name = anim_name; m.anim_name_back = anim_back; m.attack_mode = amode
	var off_frame := mini(contact + 2, frame_count - 1)
	var arr: Array[SequenceFrame] = []
	for i in range(frame_count):
		var f := SequenceFrame.new()
		f.duration_ticks = ticks_per_frame
		f.anim_frame = i
		if i == launch:
			f.command = SequenceFrame.Command.SET_LAUNCH
			f.launch_yvel = yvel
			f.launch_xvel = xvel
			f.launch_homing = homing
			f.leap_ticks = leap_ticks
			f.leap_cap_x = cap_x
			f.leap_cap_z = cap_z
		elif i == contact:
			f.command = SequenceFrame.Command.ATTACK_ON
			f.attack_box = box
		elif i == off_frame:
			f.command = SequenceFrame.Command.ATTACK_OFF
		arr.append(f)
	m.frames = arr
	return m
```

- [ ] **Step 2: Author both moves in `_init`**

In `tools/build_doink_sequences.gd` `_init()`, after the grapple-throw `_save(...)` lines (after the `_save(_throw("grab_fling", ...))` line), add:

```gdscript
	# Aerials (arcade DNKSEQ2.ASM). Flying kick: homing LEAPATOPP (11 ticks, caps 0x50000),
	# launch yvel 0x90000, box 46,76 / 42x42 (DNKSEQ2.ASM:902-909). Use the existing power-kick
	# art; launch on an early frame, contact mid-clip.
	_save(_aerial("flying_kick", "power_kick_front", AMode.SPINKICK,
		_sf.get_frame_count("power_kick_front"), 1, 3, _ab(46, 76, 0, 42, 42, 10),
		0x90000, 0, true, 11, 0x50000, 0x50000, 3, "power_kick_back"))
	# Flying clothesline: fixed launch yvel 0x64000 + forward xvel 0x5c000, box 25,6 / 23x37
	# (DNKSEQ2.ASM:2401-2405). Use the boxing-glove smash art as the body-check clip placeholder
	# (tune the anim/box in playtest).
	_save(_aerial("flying_clothesline", "boxing_glove_smash_front", AMode.BIGBOOT,
		_sf.get_frame_count("boxing_glove_smash_front"), 0, 2, _ab(25, 6, 0, 23, 37, 10),
		0x64000, 0x5c000, false, 0, 0, 0, 3, "boxing_glove_smash_back"))
```

> NOTE: `power_kick_front` / `boxing_glove_smash_front` are the art clips already used by `spin_kick` / `boxing_glove` (confirmed present in `_init`). The exact launch/contact frame indices are seeded for playtest tuning, not final.

- [ ] **Step 3: Regenerate the sequence `.tres` files**

Run: `godot --headless --path . -s tools/build_doink_sequences.gd`
Expected: prints each move + `OK`; creates `assets/sequences/doink/flying_kick.tres` and `flying_clothesline.tres`.
Then: `godot --headless --path . --import`

- [ ] **Step 4: Wire the clothesline into the MoveTable**

In `tools/build_doink_movetable.gd`: load the new sequence and replace the `RUNNING + HIGH_PUNCH` mapping. After the existing `var big_boot := load(...)` line, add:

```gdscript
	var flying_clothesline: MoveSequence = load(SEQ + "flying_clothesline.tres")
```

Change the SPUNCH running line (currently `t.add(R.RUNNING, D.NEUTRAL, B.HIGH_PUNCH, big_boot)`) to:

```gdscript
	t.add(R.RUNNING,  D.NEUTRAL, B.HIGH_PUNCH, flying_clothesline)  # arcade #super_punch -> #punch_clothesline
```

Update the SPUNCH comment above the block to read `running flying clothesline` instead of `running big boot`.

- [ ] **Step 5: Regenerate the MoveTable + import**

Run: `godot --headless --path . -s tools/build_doink_movetable.gd`
Expected: `doink movetable -> OK`.
Then: `godot --headless --path . --import`

- [ ] **Step 6: Commit**

```bash
git add tools/build_doink_sequences.gd tools/build_doink_movetable.gd \
	assets/sequences/doink/flying_kick.tres assets/sequences/doink/flying_clothesline.tres \
	assets/movetables/doink.tres
git add assets/sequences/doink/flying_kick.tres.uid assets/sequences/doink/flying_clothesline.tres.uid 2>/dev/null || true
git commit -m "feat(aerials): author flying kick + flying clothesline; wire clothesline to RUNNING+SPUNCH"
```

---

## Task 10: Player dispatch — flying-kick gate swap

**Files:**
- Modify: `scripts/player.gd`
- Test: `test/unit/test_flying_kick_dispatch.gd`

Mirror `_grounded_move_or_hair_pickup`: when the resolved move is the standing `spin_kick` (HIGH_KICK) and `FlyingKick.gate` passes, swap to the airborne `flying_kick` sequence. The clothesline needs no dispatch code — the MoveTable cell (Task 9) handles it.

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_flying_kick_dispatch.gd`:

```gdscript
extends "res://addons/gut/test.gd"
## _normal_kick_or_flying_kick: HIGH_KICK at range swaps the standing spin_kick for flying_kick.

func _spin_kick() -> MoveSequence:
	var m := MoveSequence.new(); m.id = "spin_kick"; return m

func test_far_target_swaps_to_flying_kick():
	var p := Player.new()
	add_child_autofree(p)
	var foe := Fighter.new()
	add_child_autofree(foe)
	p.global_position = Vector2(0, 400); p._set_facing(1.0)
	foe.global_position = Vector2(150, 400); foe.mode = Fighter.Mode.NORMAL
	p.target = foe
	var out := p._normal_kick_or_flying_kick(_spin_kick(), MoveTable.Btn.HIGH_KICK)
	assert_eq(out.id, "flying_kick", "far HIGH_KICK -> flying kick")

func test_close_target_keeps_spin_kick():
	var p := Player.new()
	add_child_autofree(p)
	var foe := Fighter.new()
	add_child_autofree(foe)
	p.global_position = Vector2(0, 400); p._set_facing(1.0)
	foe.global_position = Vector2(30, 400); foe.mode = Fighter.Mode.NORMAL
	p.target = foe
	var out := p._normal_kick_or_flying_kick(_spin_kick(), MoveTable.Btn.HIGH_KICK)
	assert_eq(out.id, "spin_kick", "within 60px -> standing spin kick stays")

func test_low_kick_is_untouched():
	var p := Player.new()
	add_child_autofree(p)
	var foe := Fighter.new()
	add_child_autofree(foe)
	p.global_position = Vector2(0, 400); p._set_facing(1.0)
	foe.global_position = Vector2(150, 400); foe.mode = Fighter.Mode.NORMAL
	p.target = foe
	var kick := MoveSequence.new(); kick.id = "kick"
	var out := p._normal_kick_or_flying_kick(kick, MoveTable.Btn.LOW_KICK)
	assert_eq(out.id, "kick", "low kick is never swapped")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_flying_kick_dispatch.gd -gexit`
Expected: FAIL (`_normal_kick_or_flying_kick` not found).

- [ ] **Step 3: Add the gate swap + preload**

In `scripts/player.gd`, after line 7 (`const _HAIR_PICKUP := preload(...)`), add:

```gdscript
const _FLYING_KICK := preload("res://assets/sequences/doink/flying_kick.tres")
```

After `_grounded_move_or_hair_pickup` (line 66), add:

```gdscript
## Flying kick pre-empts the standing spin kick (HIGH_KICK) when the target stands beyond the
## 60x60 close box (arcade #super_kick: within = close super, outside = jumping kick). Geometric
## gate, not a MoveTable cell — so we intercept the resolved move here.
func _normal_kick_or_flying_kick(seq: MoveSequence, btn: int) -> MoveSequence:
	if seq != null and seq.id == "spin_kick" and btn == MoveTable.Btn.HIGH_KICK \
			and target != null and is_instance_valid(target) \
			and FlyingKick.gate(global_position, target.global_position, target.mode):
		return _FLYING_KICK
	return seq
```

In `_dispatch_normal_move` (line 75-76), add the swap right after the hair-pickup swap:

```gdscript
	var seq: MoveSequence = _MOVES.lookup(_current_range(), _current_dir(), btn)
	seq = _grounded_move_or_hair_pickup(seq, btn)   # hair pickup pre-empts elbow drop at the head
	seq = _normal_kick_or_flying_kick(seq, btn)     # flying kick pre-empts the standing spin kick
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --path . --import` then
`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_flying_kick_dispatch.gd -gexit`
Expected: PASS (3 asserts).

- [ ] **Step 5: Commit**

```bash
git add scripts/player.gd test/unit/test_flying_kick_dispatch.gd
git commit -m "feat(aerials): dispatch — flying kick pre-empts the standing spin kick"
```

---

## Task 11: End-to-end aerial integration

**Files:**
- Test: `test/unit/test_aerial_integration.gd`

Verify the full path: starting the authored `flying_kick` sequence launches the fighter (`INAIR`, rises, lands back to `NORMAL`), and the clothesline launches forward.

- [ ] **Step 1: Write the test**

Create `test/unit/test_aerial_integration.gd`:

```gdscript
extends "res://addons/gut/test.gd"
## End-to-end: the authored aerial sequences launch the fighter and land it.

const FRAME: float = 1.0 / 60.0
const FLY_KICK := preload("res://assets/sequences/doink/flying_kick.tres")
const CLOTHESLINE := preload("res://assets/sequences/doink/flying_clothesline.tres")

func test_flying_kick_launches_and_lands():
	var p := Player.new()
	add_child_autofree(p)
	var foe := Fighter.new()
	add_child_autofree(foe)
	p.global_position = Vector2(0, 400); p._set_facing(1.0)
	foe.global_position = Vector2(150, 400); foe.mode = Fighter.Mode.NORMAL
	p.target = foe
	p.start_move(FLY_KICK)
	var went_airborne := false
	var max_h := 0.0
	for _i in range(240):
		p._physics_process(FRAME)
		if p.mode == Fighter.Mode.INAIR:
			went_airborne = true
		max_h = maxf(max_h, p._height)
		if went_airborne and p.mode == Fighter.Mode.NORMAL and not p.is_attacking():
			break
	assert_true(went_airborne, "flying kick took the fighter airborne")
	assert_gt(max_h, 50.0, "rose off the mat")
	assert_almost_eq(p._height, 0.0, 0.001, "landed back on the mat")

func test_clothesline_launches_forward():
	var p := Player.new()
	add_child_autofree(p)
	p.global_position = Vector2(0, 400); p._set_facing(1.0)
	p.start_move(CLOTHESLINE)
	for _i in range(12):
		p._physics_process(FRAME)
	assert_gt(p.global_position.x, 0.0, "clothesline carried the body forward")
```

- [ ] **Step 2: Run the test**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_aerial_integration.gd -gexit`
Expected: PASS. If `max_h` is too low or it never lands within 240 frames, tune the launch/contact frame indices in `tools/build_doink_sequences.gd` (Task 9 Step 2), regenerate, `--import`, and re-run — the frame indices are explicitly seeded for playtest tuning.

- [ ] **Step 3: Run the full suite**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit`
Expected: all green.

- [ ] **Step 4: Commit**

```bash
git add test/unit/test_aerial_integration.gd
git commit -m "test(aerials): end-to-end flying kick + clothesline launch/land"
```

---

## Task 12: Manual playtest checklist (no code)

- [ ] Launch the sandbox scene; with a foe >60px away, press HIGH_KICK → Doink should leap toward the foe (homing), the sprite rises with a shadow on the mat, connects, and lands.
- [ ] With a foe <60px away, HIGH_KICK should still do the standing spin kick (no launch).
- [ ] Start a run, press HIGH_PUNCH → flying clothesline launches forward and lands.
- [ ] Confirm grounded combat (punch/kick/grapples/hair-pickup) is unchanged.
- [ ] If launch height/horizontal reach/landing timing feels off, tune: `ArcadeUnits` launch constants are arcade-exact (leave them); adjust the `launch`/`contact` frame indices and `ticks_per_frame` in the `_aerial(...)` calls (Task 9), regenerate, `--import`, re-test.

---

## Self-Review Notes

- **Spec coverage:** §2 height subsystem → Tasks 1,6; §3 launch commands → Tasks 4,5,6; §4.1 flying kick → Tasks 2,3,9,10; §4.2 clothesline → Task 9; §5 air hit detection → Task 8; §6 rendering → Task 7; §7 testing → every task + Task 11; §7 non-goals respected (no free jump, no turnbuckle, no y-sort). The two §4 fidelity deltas (HIGH_PUNCH clothesline scoped to RUNNING; flying kick = airborne spin_kick gated ≥60) are implemented as specified.
- **Type consistency:** `consume_launch()` / `launch_yvel()` / `leap_ticks()` etc. are defined in Task 5 and consumed in Task 6 (`_begin_launch`). `apply_launch(yvel, planar)` defined Task 6, called by `_begin_launch` and tests. `FlyingKick.gate(Vector2, Vector2, int)` defined Task 3, called Task 10. `AerialLaunch.leap_velocity(Vector2, Vector2, float, float, float)` defined Task 2, called Task 6. `_height`/`_vy` defined Task 6, read Task 7 (`_refresh_flip`) and Task 8 (resolver). Sequence ids `"flying_kick"` / `"flying_clothesline"` authored Task 9, referenced Tasks 10,11.
- **Open tuning knobs (intentional, flagged):** aerial clip choice + launch/contact frame indices + `ticks_per_frame` are playtest-tunable (Task 9/11/12); the physics constants are arcade-exact and fixed.
