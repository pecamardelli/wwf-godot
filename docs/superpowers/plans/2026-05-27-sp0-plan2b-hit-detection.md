# SP-0 Plan 2b: Sequence Engine + Hit Detection + Damage + Reactions — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A data-driven move-sequence ("puppet") player that fires Doink strikes whose `ANI_ATTACK_ON/OFF` windows open a 3D-AABB attack box; when it overlaps a victim's mode-dependent hurt box, damage is applied with the arcade formula (×1.348 offense, ⅔ repeat, block→1, health 163), and the victim plays the correct reaction family (head/body hit, fall-back, knockdown+getup, stagger, dizzy, on-ground) selected by the attacker's `ATTACK_MODE`.

**Architecture:** Pure, unit-testable combat modules under `scripts/combat/` (units already in `ArcadeUnits` from Plan 2a): `AMode` (attack-mode + reaction-family enums and the `hit_table`), `DamageTable` + `Damage` (values + formula + health), `Box3`/`Hitbox` (3D-AABB geometry with mode-dependent depth), `SequenceFrame`/`MoveSequence` (typed `Resource`s authored as `.tres`), `SequencePlayer` (steps a sequence by `ticks_to_seconds`, raising attack-on/off/finished), and `Reaction` (family → behaviour). `Fighter` gains health, a per-frame hurt box, a current `SequencePlayer`, and reaction handling; a per-tick `AttackResolver` matches every live attack box against every hurt box. Axis mapping in our belt-scroll world: **X = `position.x` (horizontal), Z = depth = `position.y` (floor band), Y = height off ground (0 while grounded — jumps are 2c/2e).**

**Tech Stack:** Godot 4.6.3, GDScript, GUT (headless). Builds on Plan 2a (tag `sp0-plan2a-combat-foundation`).

**Fidelity sources:** `docs/superpowers/research/2026-05-27-arcade-damage-collision-reactions.md` (damage formula, 3D-AABB, depth-by-mode, reaction families, health) and `…-arcade-move-animation-system.md` (sequence format, `STARTATTACK`/`ATTACK_ON`/`ATTACK_OFF`, Doink moveset + AMODEs).

---

## Conventions (every task)

```bash
export GODOT="/media/pablin/DATOS/JUEGOS/Wrestlemania/Godot_v4.6.3-stable_linux.x86_64"   # also on PATH as `godot`
cd /media/pablin/DATOS/JUEGOS/Wrestlemania/wwfmania-godot
```
Run the full suite:
```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -gprefix=test_ -gsuffix=.gd -ginclude_subdirs -gexit
```
(If scripts/resources were just added, run `godot --headless --path . --import` once first.)

Read-only references: arcade source `/home/pablin/Games/wwf-wrestlemania`; the research docs above.

**Decisions locked for this plan:** sequence data = typed `Resource` (`.tres`); reaction scope = the full family set (head/body hit, fall-back, knockdown+getup, stagger, dizzy, on-ground), mapped to Doink's imported reaction anims.

---

## Axis & box conventions (read once, used everywhere)

- A **box** is a `Box3` = `offset: Vector3` + `size: Vector3`, in the fighter's local frame.
  `offset.x` extends **toward facing** (multiplied by `facing` = +1 right / −1 left).
- World AABB for a fighter at `pos` (`Vector2`), `facing` (±1), `height` (float, 0 grounded):
  - centre = `Vector3(pos.x + facing*offset.x, height + offset.y, pos.y + offset.z)`
  - min/max = centre ∓ `size/2`. (X horizontal, Y height, **Z = `pos.y`** depth.)
- **Hurt-box depth is set by `Mode`** (`COLLIS.ASM:270-296`): standing `zoff=-30, depth=60`; `ONGROUND` `-15/30`; `RUNNING` `-5/10`. Encoded in `Hitbox.hurt_box_for_mode`.
- Attack boxes come from each move's `ANI_ATTACK_ON x,y,w,h` (Z depth default 10) — e.g. Doink punch `AMODE_PUNCH,22,86,55,9` (`DNKSEQ2.ASM:93-132`).

---

## File structure (this plan)

```
scripts/combat/
  amode.gd            # NEW: AMODE_* + ReactionFamily enums; hit_table (AMODE->family); getup_ticks
  damage_table.gd     # NEW: D_*/RD_* per AMODE; lookup
  damage.gd           # NEW: offense mod ×1.348, repeat ⅔ (≤50 ticks), block→1, health clamp/KO/lethal-fudge
  box3.gd             # NEW: Box3 Resource (offset+size) + world-AABB build
  hitbox.gd           # NEW: 3D-AABB overlap; hurt_box_for_mode (depth model); hit_side
  sequence_frame.gd   # NEW: SequenceFrame Resource (duration_ticks, anim_frame, command, attack box)
  move_sequence.gd    # NEW: MoveSequence Resource (id, anim_name, attack_mode, frames[], flags)
  sequence_player.gd  # NEW: steps a MoveSequence by ticks_to_seconds; signals attack_on/off/finished
  reaction.gd         # NEW: ReactionFamily -> {anim, hitstun, knockback, becomes_mode, getup_ticks}
  attack_resolver.gd  # NEW: per-tick match of live attack boxes vs hurt boxes across "fighters" group
tools/
  build_doink_sequences.gd  # NEW: author the strike MoveSequences -> res://assets/sequences/doink/*.tres
scripts/
  fighter.gd          # MODIFY: health, hurt box, current SequencePlayer, fire-move + receive-hit + reactions
  player.gd           # MODIFY: read attack buttons -> request move
scenes/
  Sandbox.tscn        # MODIFY: add an AttackResolver node
assets/sequences/doink/*.tres   # NEW: built strike sequences
test/unit/
  test_amode.gd               # NEW
  test_damage.gd              # NEW
  test_hitbox.gd              # NEW
  test_sequence_player.gd     # NEW
  test_reaction.gd            # NEW
  test_fighter_combat.gd      # NEW (integration)
```

---

## Task 0: Branch

- [ ] **Step 1: Create the working branch**

```bash
git switch master && git switch -c combat-sequences
git branch --show-current   # -> combat-sequences
```

---

## Task 1: AMode enums, hit_table, getup timing (TDD)

**Files:** Create `scripts/combat/amode.gd`, `test/unit/test_amode.gd`

- [ ] **Step 1: Write the failing test** — `test/unit/test_amode.gd`

```gdscript
extends "res://addons/gut/test.gd"

func test_punch_maps_to_head_hit():
	assert_eq(AMode.reaction_for(AMode.PUNCH), AMode.Family.HEAD_HIT)

func test_kick_maps_to_body_hit():
	assert_eq(AMode.reaction_for(AMode.KICK), AMode.Family.BODY_HIT)

func test_bigboot_is_a_knockdown():
	assert_eq(AMode.reaction_for(AMode.BIGBOOT), AMode.Family.KNOCKDOWN)

func test_uppercut_falls_back():
	assert_eq(AMode.reaction_for(AMode.UPRCUT), AMode.Family.FALL_BACK)

func test_knockdown_getup_is_270_ticks():
	# STAY_TIME = 270 ticks ~= 5.1s (GAME.EQU:14)
	assert_eq(AMode.getup_ticks(AMode.Family.KNOCKDOWN), 270)

func test_most_moves_get_right_up():
	assert_eq(AMode.getup_ticks(AMode.Family.HEAD_HIT), 0)
```

- [ ] **Step 2: Run, expect fail** (`AMode` undefined).

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -gprefix=test_ -gsuffix=.gd -ginclude_subdirs -gselect=test_amode.gd -gexit
```
Expected: parse error referencing `AMode`.

- [ ] **Step 3: Implement** — `scripts/combat/amode.gd`

```gdscript
class_name AMode
## Attack modes (arcade AMODE_*) and the reaction-family dispatch (arcade #hit_table,
## REACT1.ASM:833-901): the reaction is chosen by the ATTACKER's mode, not by damage.

## Subset of AMODE_* we implement in 2b (the wired strikes). Extend in later plans.
enum { PUNCH, HDBUTT, KICK, KNEE, UPRCUT, BIGBOOT, STOMP, LBDROP }

## Reaction families (arcade STDSEQ reaction tables, REACT1.ASM:1723-1866).
enum Family { HEAD_HIT, BODY_HIT, FALL_BACK, KNOCKDOWN, STAGGER, ONGROUND, BLOCK, DIZZY }

## AMODE -> reaction family.
const _HIT_TABLE := {
	PUNCH: Family.HEAD_HIT,
	HDBUTT: Family.HEAD_HIT,
	KICK: Family.BODY_HIT,
	KNEE: Family.BODY_HIT,
	UPRCUT: Family.FALL_BACK,
	BIGBOOT: Family.KNOCKDOWN,
	STOMP: Family.ONGROUND,
	LBDROP: Family.ONGROUND,
}

static func reaction_for(amode: int) -> int:
	return _HIT_TABLE.get(amode, Family.BODY_HIT)

## Time the victim stays down before getup (set_getup_time, GETUP.ASM:32-184).
## Knockdowns = STAY_TIME 270 ticks; fall-back is shorter; everything else = 0 (get right up).
const _GETUP_TICKS := {
	Family.KNOCKDOWN: 270,
	Family.FALL_BACK: 90,
	Family.DIZZY: 120,
}

static func getup_ticks(family: int) -> int:
	return _GETUP_TICKS.get(family, 0)
```

- [ ] **Step 4: Run, expect pass** (same `-gselect` command). Expected: 6 pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/combat/amode.gd test/unit/test_amode.gd
git commit -m "feat(combat): AMODE enums, attacker-mode hit_table, getup timing"
```

---

## Task 2: Damage formula + health (TDD)

**Files:** Create `scripts/combat/damage_table.gd`, `scripts/combat/damage.gd`, `test/unit/test_damage.gd`

- [ ] **Step 1: Write the failing test** — `test/unit/test_damage.gd`

```gdscript
extends "res://addons/gut/test.gd"

# Offense mod is the universal _35PCT=89 -> ×(256+89)/256 (REACT1.ASM:490-507, 1695-1704).
func test_punch_base_8_after_offense_mod():
	# 8 * 345 / 256 = 10 (integer)
	assert_eq(Damage.resolve(AMode.PUNCH, false, false), 10)

func test_kick_base_13_after_offense_mod():
	# 13 * 345 / 256 = 17
	assert_eq(Damage.resolve(AMode.KICK, false, false), 17)

func test_repeat_uses_two_thirds_column():
	# RD_PUNCH = floor(8*2/3)=5; 5*345/256 = 6
	assert_eq(Damage.resolve(AMode.PUNCH, true, false), 6)

func test_block_is_one_pixel():
	assert_eq(Damage.resolve(AMode.BIGBOOT, false, true), 1)

func test_small_hit_kills_no_fudge():
	# lethal fudge needs a 20+ hit; a 10 hit on 6 life -> after -4, no fudge -> dead at 0
	assert_eq(Damage.apply_health(6, 10), 0)

func test_big_hit_near_miss_survives_at_5():
	# 22 hit (>=20) on 15 -> after -7 (> -10) -> fudge: survives at 5 (LIFEBAR.ASM:1557-1573)
	assert_eq(Damage.apply_health(15, 22), 5)

func test_big_hit_far_overkill_still_kills():
	# 24 hit on 6 -> after -18 (<= -10) -> outside fudge margin -> dead at 0
	assert_eq(Damage.apply_health(6, 24), 0)

func test_apply_normal_subtract():
	assert_eq(Damage.apply_health(163, 10), 153)
```

- [ ] **Step 2: Run, expect fail** (`Damage` undefined).

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -gprefix=test_ -gsuffix=.gd -ginclude_subdirs -gselect=test_damage.gd -gexit
```

- [ ] **Step 3: Implement** — `scripts/combat/damage_table.gd`

```gdscript
class_name DamageTable
## Base strike damage per AMODE (DAMAGE.EQU). Repeat damage RD_* = floor(D_* * 2/3),
## used when the victim was damaged within the last 50 ticks (REACT1.ASM:457-466).

const _BASE := {
	AMode.PUNCH: 8,
	AMode.HDBUTT: 12,
	AMode.KICK: 13,
	AMode.KNEE: 12,
	AMode.UPRCUT: 20,
	AMode.BIGBOOT: 18,
	AMode.STOMP: 8,
	AMode.LBDROP: 17,
}

static func base(amode: int) -> int:
	return int(_BASE.get(amode, 0))

static func repeat(amode: int) -> int:
	return (base(amode) * 2) / 3   # integer floor
```

Then `scripts/combat/damage.gd`:

```gdscript
class_name Damage
## Arcade damage resolution + health bookkeeping.
## final = base × (256 + offense_mod)/256 × (256 + defense_mod)/256  (REACT1.ASM:490-507).
## offense_mod = _35PCT = 89 (universal); defense_mod = 0.

const OFFENSE_MOD := 89          # _35PCT (GAME.EQU:460)
const LIFE_MAX := 163            # LIFEBAR.ASM:135
const REPEAT_WINDOW_TICKS := 50  # REACT1.ASM:457-466
const BLOCK_DAMAGE := 1          # blocked hits = 1px (REACT1.ASM block_hit)

## Damage a hit deals. `repeat` picks the ⅔ column; `blocked` overrides to 1px.
static func resolve(amode: int, repeat: bool, blocked: bool) -> int:
	if blocked:
		return BLOCK_DAMAGE
	var base_dmg := DamageTable.repeat(amode) if repeat else DamageTable.base(amode)
	return (base_dmg * (256 + OFFENSE_MOD)) / 256   # ×1.348, integer

## Subtract `dmg` from `life`, clamped [0, LIFE_MAX], with the lethal fudge:
## a would-be kill survives at 5 when life-after > -10 and the hit was >= 20 (LIFEBAR.ASM:1557-1573).
static func apply_health(life: int, dmg: int) -> int:
	var after := life - dmg
	if after <= 0 and after > -10 and dmg >= 20:
		return 5
	return clampi(after, 0, LIFE_MAX)
```

- [ ] **Step 4: Run, expect pass.** Expected: 7 pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/combat/damage_table.gd scripts/combat/damage.gd test/unit/test_damage.gd
git commit -m "feat(combat): damage table + ×1.348 formula, ⅔ repeat, block, health/KO/fudge"
```

---

## Task 3: 3D-AABB geometry + depth-by-mode (TDD)

**Files:** Create `scripts/combat/box3.gd`, `scripts/combat/hitbox.gd`, `test/unit/test_hitbox.gd`

- [ ] **Step 1: Write the failing test** — `test/unit/test_hitbox.gd`

```gdscript
extends "res://addons/gut/test.gd"

func _box(ox, oy, oz, w, h, d) -> Box3:
	var b := Box3.new()
	b.offset = Vector3(ox, oy, oz)
	b.size = Vector3(w, h, d)
	return b

func test_world_aabb_offsets_toward_facing():
	# offset.x extends toward facing: facing -1 mirrors it to the left.
	# centre x = 100 + (-1)*20 = 80; width 10 -> [75, 85].
	var aabb := Box3.world_aabb(_box(20, 86, 0, 10, 10, 10), Vector2(100, 400), -1.0, 0.0)
	assert_almost_eq(aabb.position.x, 75.0, 0.01)
	assert_almost_eq(aabb.end.x, 85.0, 0.01)

func test_overlapping_boxes_hit():
	var a := _box(0, 50, 0, 40, 40, 60)   # attacker box around its centre
	var b := _box(0, 50, 0, 40, 40, 60)
	assert_true(Hitbox.boxes_overlap(a, Vector2(100, 400), 1.0, 0.0,
	                                  b, Vector2(120, 405), 1.0, 0.0), "20px apart, within widths")

func test_disjoint_on_depth_misses():
	var a := _box(0, 50, 0, 40, 40, 10)   # thin attack depth
	var b := _box(0, 50, 0, 40, 40, 10)
	assert_false(Hitbox.boxes_overlap(a, Vector2(100, 400), 1.0, 0.0,
	                                  b, Vector2(100, 460), 1.0, 0.0), "60px apart in depth (Z) -> miss")

func test_standing_hurt_box_depth_is_60():
	var hb := Hitbox.hurt_box_for_mode(Fighter.Mode.NORMAL)
	assert_almost_eq(hb.size.z, 60.0, 0.01)
	assert_almost_eq(hb.offset.z, 0.0, 0.01)   # zoff -30 + half-depth 30 -> centred on plane

func test_running_hurt_box_is_thin():
	var hb := Hitbox.hurt_box_for_mode(Fighter.Mode.RUNNING)
	assert_almost_eq(hb.size.z, 10.0, 0.01)

func test_hit_side_is_left_when_attacker_is_to_the_right():
	# attacker at x=120 hitting victim at x=100 -> victim hit on its right? side reported from victim POV
	assert_eq(Hitbox.hit_side(Vector2(120, 400), Vector2(100, 400)), -1, "attacker on +x => push victim -x")
```

> **Note:** `world_aabb` returns Godot's built-in `AABB` (`position` + `size`, kept all-positive); assert against `aabb.position` / `aabb.end`.

- [ ] **Step 2: Run, expect fail** (`Box3`/`Hitbox` undefined).

- [ ] **Step 3: Implement** — `scripts/combat/box3.gd`

```gdscript
class_name Box3
extends Resource
## A combat box in a fighter's local frame: offset.x extends toward facing.
## Axis mapping to our 2D world: X = position.x, Y = height off ground, Z = position.y (depth).

@export var offset: Vector3 = Vector3.ZERO
@export var size: Vector3 = Vector3.ZERO

## World-space AABB for `box` on a fighter at `pos`, facing ±1, at `height` (0 grounded).
static func world_aabb(box: Box3, pos: Vector2, facing: float, height: float) -> AABB:
	var centre := Vector3(pos.x + facing * box.offset.x, height + box.offset.y, pos.y + box.offset.z)
	return AABB(centre - box.size * 0.5, box.size)
```

Then `scripts/combat/hitbox.gd`:

```gdscript
class_name Hitbox
## 3D-AABB hit test (check_collis, COLLIS.ASM:486-524) and the mode-dependent hurt-box
## depth model (COLLIS.ASM:270-296). A hit lands only when all three axes overlap.

static func boxes_overlap(a: Box3, a_pos: Vector2, a_face: float, a_h: float,
		b: Box3, b_pos: Vector2, b_face: float, b_h: float) -> bool:
	var aw := Box3.world_aabb(a, a_pos, a_face, a_h)
	var bw := Box3.world_aabb(b, b_pos, b_face, b_h)
	return aw.intersects(bw)

## Defensive hurt box whose DEPTH (Z) is set by the victim's Mode.
## standing -30/60, ONGROUND -15/30, RUNNING -5/10. Width/height are a body default
## (per-frame IANI3* boxes are not readable from the arcade IMG headers — approximated).
static func hurt_box_for_mode(mode: int) -> Box3:
	var depth := 60.0
	match mode:
		Fighter.Mode.ONGROUND: depth = 30.0
		Fighter.Mode.RUNNING: depth = 10.0
		_: depth = 60.0
	var hb := Box3.new()
	hb.size = Vector3(44.0, 120.0, depth)   # body width/height defaults; depth by mode
	hb.offset = Vector3(0.0, 60.0, 0.0)      # centred on the plane (zoff -30 + depth/2), origin at feet
	return hb

## Which way to push the victim: -1 if attacker is on the victim's +x side, else +1.
static func hit_side(attacker_pos: Vector2, victim_pos: Vector2) -> int:
	return -1 if attacker_pos.x >= victim_pos.x else 1
```

- [ ] **Step 4: Run, expect pass.** Expected: 6 pass (with the `world_aabb` assertions adjusted per the impl note).

- [ ] **Step 5: Commit**

```bash
git add scripts/combat/box3.gd scripts/combat/hitbox.gd test/unit/test_hitbox.gd
git commit -m "feat(combat): Box3 world-AABB + 3D hit test + mode-dependent hurt-box depth"
```

---

## Task 4: MoveSequence / SequenceFrame Resources + sequence builder (TDD)

**Files:** Create `scripts/combat/sequence_frame.gd`, `scripts/combat/move_sequence.gd`, `tools/build_doink_sequences.gd`, `test/unit/test_sequence_player.gd` (data-shape tests here; player behaviour in Task 5)

- [ ] **Step 1: Define the Resources** — `scripts/combat/sequence_frame.gd`

```gdscript
class_name SequenceFrame
extends Resource
## One frame of a move sequence (the arcade WL n,img macro + ANI_ commands).
## `duration_ticks` plays at the frame; `anim_frame` indexes the move's SpriteFrames anim.
## Commands fire when the frame BEGINS.

## Hitbox lifecycle command codes (referenced everywhere as SequenceFrame.Command.*).
enum Command { NONE = 0, STARTATTACK = 1, ATTACK_ON = 2, ATTACK_OFF = 3 }

@export var duration_ticks: int = 4
@export var anim_frame: int = 0
@export_enum("NONE", "STARTATTACK", "ATTACK_ON", "ATTACK_OFF") var command: int = Command.NONE
## Attack box for ATTACK_ON frames (ANI_ATTACK_ON x,y,w,h; Z depth default 10).
@export var attack_box: Box3 = null
```

Then `scripts/combat/move_sequence.gd`:

```gdscript
class_name MoveSequence
extends Resource
## A move = an ordered list of SequenceFrames + the SpriteFrames anim to display + the
## attacker AMODE that selects the victim's reaction.

@export var id: String = ""
@export var anim_name: String = ""        # e.g. "mid_punch_front" (Doink SpriteFrames)
@export var attack_mode: int = AMode.PUNCH
@export var frames: Array[SequenceFrame] = []
## MODE_UNINT: while playing, new input is ignored until the sequence ends.
@export var uninterruptable: bool = true
## Some moves daze the victim (dizzy family) regardless of the base reaction.
@export var causes_dizzy: bool = false

func total_ticks() -> int:
	var t := 0
	for f in frames:
		t += f.duration_ticks
	return t
```

- [ ] **Step 2: Write the sequence builder** — `tools/build_doink_sequences.gd`

```gdscript
extends SceneTree
## Author the 2b strike sequences as .tres under res://assets/sequences/doink/.
## Run: godot --headless --path . -s tools/build_doink_sequences.gd
## (re-run whenever the move data below changes)

const OUT := "res://assets/sequences/doink"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_save(_punch())
	_save(_headbutt())
	_save(_kick())
	_save(_uppercut())
	_save(_big_boot())
	quit()

func _ab(ox, oy, oz, w, h, d) -> Box3:
	var b := Box3.new(); b.offset = Vector3(ox, oy, oz); b.size = Vector3(w, h, d); return b

func _frame(dur, img, cmd := 0, box: Box3 = null) -> SequenceFrame:
	var f := SequenceFrame.new()
	f.duration_ticks = dur; f.anim_frame = img; f.command = cmd; f.attack_box = box
	return f

# Doink #2 punch (DNKSEQ2.ASM:93-132): windup -> STARTATTACK -> ATTACK_ON 22,86,55,9 (2 active) -> OFF -> recovery.
func _punch() -> MoveSequence:
	var m := MoveSequence.new()
	m.id = "punch"; m.anim_name = "mid_punch_front"; m.attack_mode = AMode.PUNCH
	m.frames = [
		_frame(3, 0),                                   # windup
		_frame(2, 1, 1),                                # STARTATTACK
		_frame(2, 2, 2, _ab(22, 86, 0, 55, 9, 10)),     # ATTACK_ON (active)
		_frame(2, 3),                                   # active 2
		_frame(2, 3, 3),                                # ATTACK_OFF
		_frame(4, 0),                                   # recovery -> END (implicit at array end)
	]
	return m

func _headbutt() -> MoveSequence:
	var m := MoveSequence.new()
	m.id = "headbutt"; m.anim_name = "headbutt_front"; m.attack_mode = AMode.HDBUTT
	m.causes_dizzy = true                               # headbutt dazes
	m.frames = [
		_frame(3, 0), _frame(2, 1, 1),
		_frame(3, 2, 2, _ab(18, 92, 0, 40, 12, 10)),
		_frame(3, 2, 3), _frame(5, 0),
	]
	return m

func _kick() -> MoveSequence:
	var m := MoveSequence.new()
	m.id = "kick"; m.anim_name = "mid_kick_front"; m.attack_mode = AMode.KICK
	m.frames = [
		_frame(3, 0), _frame(2, 1, 1),
		_frame(2, 2, 2, _ab(26, 50, 0, 60, 14, 10)),
		_frame(2, 3), _frame(2, 3, 3), _frame(5, 0),
	]
	return m

func _uppercut() -> MoveSequence:
	var m := MoveSequence.new()
	m.id = "uppercut"; m.anim_name = "uppercut"; m.attack_mode = AMode.UPRCUT
	m.frames = [
		_frame(4, 0), _frame(2, 1, 1),
		_frame(3, 2, 2, _ab(20, 70, 0, 44, 30, 10)),
		_frame(3, 2, 3), _frame(6, 0),
	]
	return m

# Big boot only meaningful while RUNNING (DOINK.ASM:2310) -> knockdown.
func _big_boot() -> MoveSequence:
	var m := MoveSequence.new()
	m.id = "big_boot"; m.anim_name = "big_boot"; m.attack_mode = AMode.BIGBOOT
	m.frames = [
		_frame(3, 0), _frame(2, 1, 1),
		_frame(3, 2, 2, _ab(34, 60, 0, 70, 20, 10)),
		_frame(3, 2, 3), _frame(6, 0),
	]
	return m

func _save(m: MoveSequence) -> void:
	var err := ResourceSaver.save(m, OUT + "/" + m.id + ".tres")
	print(m.id, " (", m.total_ticks(), " ticks) -> ", error_string(err))
```

- [ ] **Step 3: Build the sequences**

```bash
godot --headless --path . --import
godot --headless --path . -s tools/build_doink_sequences.gd
ls assets/sequences/doink   # punch.tres headbutt.tres kick.tres uppercut.tres big_boot.tres
```
Expected: five `… (N ticks) -> OK` lines.

- [ ] **Step 4: Write a data-shape test** — append to `test/unit/test_sequence_player.gd` (file created here, player tests added in Task 5)

```gdscript
extends "res://addons/gut/test.gd"

func test_punch_sequence_loads_and_has_an_attack_window():
	var m: MoveSequence = load("res://assets/sequences/doink/punch.tres")
	assert_not_null(m, "punch.tres loads")
	assert_eq(m.attack_mode, AMode.PUNCH)
	var has_on := false
	var has_off := false
	for f in m.frames:
		if f.command == 2: has_on = true
		if f.command == 3: has_off = true
	assert_true(has_on and has_off, "has ATTACK_ON and ATTACK_OFF frames")

func test_headbutt_causes_dizzy():
	var m: MoveSequence = load("res://assets/sequences/doink/headbutt.tres")
	assert_true(m.causes_dizzy)
```

- [ ] **Step 5: Run, expect pass** (`-gselect=test_sequence_player.gd`).

- [ ] **Step 6: Commit**

```bash
git add scripts/combat/sequence_frame.gd scripts/combat/move_sequence.gd tools/build_doink_sequences.gd assets/sequences test/unit/test_sequence_player.gd
git commit -m "feat(combat): MoveSequence/SequenceFrame resources + Doink strike sequences"
```

---

## Task 5: SequencePlayer — steps frames, raises attack windows (TDD)

**Files:** Create `scripts/combat/sequence_player.gd`, extend `test/unit/test_sequence_player.gd`

The player is a plain `RefCounted` advanced by `advance(delta_seconds)` so it is deterministic and testable without the scene tree. Frame durations are arcade ticks → seconds via `ArcadeUnits.ticks_to_seconds`.

- [ ] **Step 1: Write the failing tests** — append to `test/unit/test_sequence_player.gd`

```gdscript
const FRAME := 1.0 / 60.0

func _two_frame_move() -> MoveSequence:
	# frame0: 2 ticks, ATTACK_ON; frame1: 2 ticks, ATTACK_OFF
	var m := MoveSequence.new()
	m.id = "t"; m.anim_name = "mid_punch_front"; m.attack_mode = AMode.PUNCH
	var box := Box3.new(); box.size = Vector3(10, 10, 10)
	var f0 := SequenceFrame.new(); f0.duration_ticks = 2; f0.command = SequenceFrame.Command.ATTACK_ON; f0.attack_box = box
	var f1 := SequenceFrame.new(); f1.duration_ticks = 2; f1.command = SequenceFrame.Command.ATTACK_OFF
	m.frames = [f0, f1]
	return m

func test_attack_goes_live_on_attack_on_frame():
	var sp := SequencePlayer.new()
	sp.play(_two_frame_move())
	sp.advance(FRAME)   # enters frame 0 (ATTACK_ON)
	assert_true(sp.attack_live, "attack box live on ATTACK_ON frame")
	assert_not_null(sp.active_attack_box)

func test_attack_dies_on_attack_off_frame():
	var sp := SequencePlayer.new()
	sp.play(_two_frame_move())
	# 2 ticks ~= 2/53 s ~= 0.0377s -> ~3 frames at 1/60 to leave frame 0
	for _i in range(4):
		sp.advance(FRAME)
	assert_false(sp.attack_live, "attack dead after ATTACK_OFF frame begins")

func test_sequence_finishes_after_total_duration():
	var sp := SequencePlayer.new()
	sp.play(_two_frame_move())   # 4 ticks total ~= 0.0755s
	var finished := false
	for _i in range(8):
		if sp.advance(FRAME):
			finished = true
	assert_true(finished, "advance() returns true on the frame it completes")
	assert_false(sp.is_playing())
```

- [ ] **Step 2: Run, expect fail** (`SequencePlayer` undefined).

- [ ] **Step 3: Implement** — `scripts/combat/sequence_player.gd`

```gdscript
class_name SequencePlayer
extends RefCounted
## Steps a MoveSequence over wall-clock time. Frame durations are arcade ticks,
## converted via ArcadeUnits.ticks_to_seconds (logic runs at 60 Hz, 1 frame != 1 tick).

var sequence: MoveSequence = null
var attack_live: bool = false
var active_attack_box: Box3 = null

var _index: int = -1
var _time_left: float = 0.0   # seconds remaining on the current frame

func play(seq: MoveSequence) -> void:
	sequence = seq
	_index = -1
	_time_left = 0.0
	attack_live = false
	active_attack_box = null

func is_playing() -> bool:
	return sequence != null

## Advance by `delta` seconds. Returns true on the step that finishes the sequence.
func advance(delta: float) -> bool:
	if sequence == null:
		return false
	_time_left -= delta
	# Enter the first frame, or any frames whose time elapsed this step.
	while _time_left <= 0.0:
		_index += 1
		if _index >= sequence.frames.size():
			_finish()
			return true
		var f: SequenceFrame = sequence.frames[_index]
		_apply_command(f)
		_time_left += ArcadeUnits.ticks_to_seconds(f.duration_ticks)
	return false

func current_frame() -> SequenceFrame:
	if sequence == null or _index < 0 or _index >= sequence.frames.size():
		return null
	return sequence.frames[_index]

func _apply_command(f: SequenceFrame) -> void:
	match f.command:
		SequenceFrame.Command.ATTACK_ON:
			attack_live = true
			active_attack_box = f.attack_box
		SequenceFrame.Command.ATTACK_OFF:
			attack_live = false
			active_attack_box = null
		_:
			pass

func _finish() -> void:
	sequence = null
	attack_live = false
	active_attack_box = null
	_index = -1
```

- [ ] **Step 4: Run, expect pass.** Expected: all `test_sequence_player.gd` tests pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/combat/sequence_player.gd test/unit/test_sequence_player.gd
git commit -m "feat(combat): SequencePlayer steps frames by tick->sec; raises attack windows"
```

---

## Task 6: Reaction families → behaviour (TDD)

**Files:** Create `scripts/combat/reaction.gd`, `test/unit/test_reaction.gd`

A reaction resolves to a `Dictionary` describing what the victim does: which anim to play, hitstun (ticks), knockback (px along hit side), the `Mode` to enter, and getup ticks. Anim names are the imported Doink reaction folders.

- [ ] **Step 1: Write the failing test** — `test/unit/test_reaction.gd`

```gdscript
extends "res://addons/gut/test.gd"

func test_head_hit_stays_standing_and_plays_facepunched():
	var r := Reaction.resolve(AMode.Family.HEAD_HIT, 1, false)  # side +1 (front)
	assert_eq(r.anim, "facepunched_front")
	assert_eq(r.mode, Fighter.Mode.NORMAL)
	assert_eq(r.getup_ticks, 0)

func test_knockdown_goes_onground_with_long_getup():
	var r := Reaction.resolve(AMode.Family.KNOCKDOWN, 1, false)
	assert_eq(r.mode, Fighter.Mode.ONGROUND)
	assert_eq(r.getup_ticks, 270)
	assert_eq(r.anim, "droped")

func test_dizzy_overrides_to_stuned():
	var r := Reaction.resolve(AMode.Family.HEAD_HIT, 1, true)   # causes_dizzy = true
	assert_eq(r.mode, Fighter.Mode.DIZZY)
	assert_eq(r.anim, "stuned")
	assert_eq(r.getup_ticks, 120)

func test_back_side_uses_back_anim():
	var r := Reaction.resolve(AMode.Family.HEAD_HIT, -1, false)
	assert_eq(r.anim, "facepunched_back")

func test_block_plays_defence():
	var r := Reaction.resolve(AMode.Family.BLOCK, 1, false)
	assert_eq(r.anim, "defence")
	assert_eq(r.mode, Fighter.Mode.BLOCK)
```

- [ ] **Step 2: Run, expect fail** (`Reaction` undefined).

- [ ] **Step 3: Implement** — `scripts/combat/reaction.gd`

```gdscript
class_name Reaction
## Maps a reaction family + hit side to the victim's visible/behavioural response.
## Anim names are the imported Doink reaction folders (assets/sprites/doink/*).
## `side` is +1 (hit from front) or -1 (from back) per Hitbox.hit_side.

## Resolve to { anim:String, mode:int (Fighter.Mode), hitstun_ticks:int,
##              knockback:float, getup_ticks:int }. `dizzy` overrides to the DIZZY family.
static func resolve(family: int, side: int, dizzy: bool) -> Dictionary:
	if dizzy:
		family = AMode.Family.DIZZY
	var back := side < 0
	match family:
		AMode.Family.HEAD_HIT:
			return _r("facepunched_back" if back else "facepunched_front",
				Fighter.Mode.NORMAL, 12, 8.0, 0)
		AMode.Family.BODY_HIT:
			return _r("shoved", Fighter.Mode.NORMAL, 12, 10.0, 0)
		AMode.Family.STAGGER:
			return _r("shoved", Fighter.Mode.NORMAL, 18, 14.0, 0)
		AMode.Family.FALL_BACK:
			return _r("droped", Fighter.Mode.ONGROUND, 0, 24.0,
				AMode.getup_ticks(AMode.Family.FALL_BACK))
		AMode.Family.KNOCKDOWN:
			return _r("droped", Fighter.Mode.ONGROUND, 0, 30.0,
				AMode.getup_ticks(AMode.Family.KNOCKDOWN))
		AMode.Family.ONGROUND:
			return _r("damage_lying", Fighter.Mode.ONGROUND, 0, 4.0, 60)
		AMode.Family.BLOCK:
			return _r("defence", Fighter.Mode.BLOCK, 6, 2.0, 0)
		AMode.Family.DIZZY:
			return _r("stuned", Fighter.Mode.DIZZY, 0, 6.0,
				AMode.getup_ticks(AMode.Family.DIZZY))
		_:
			return _r("shoved", Fighter.Mode.NORMAL, 12, 10.0, 0)

static func _r(anim: String, mode: int, hitstun: int, knockback: float, getup: int) -> Dictionary:
	return {
		"anim": anim, "mode": mode, "hitstun_ticks": hitstun,
		"knockback": knockback, "getup_ticks": getup,
	}
```

- [ ] **Step 4: Run, expect pass.** Expected: 5 pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/combat/reaction.gd test/unit/test_reaction.gd
git commit -m "feat(combat): reaction families -> anim/mode/hitstun/knockback/getup"
```

---

## Task 7: Fighter integration + AttackResolver (TDD)

**Files:** Modify `scripts/fighter.gd`; create `scripts/combat/attack_resolver.gd`, `test/unit/test_fighter_combat.gd`

`Fighter` gains: `health`, a `SequencePlayer`, a getup/dizzy/hitstun timer, methods `start_move(MoveSequence)`, `current_attack_box()`, `hurt_box()`, and `receive_hit(attacker, move)`. The `AttackResolver` (a `Node` in the scene) iterates the `"fighters"` group each physics tick, and for any fighter whose `SequencePlayer.attack_live`, tests its attack box against every other fighter's hurt box; on overlap (once per move per victim) it calls `victim.receive_hit(...)`.

- [ ] **Step 1: Write the failing integration test** — `test/unit/test_fighter_combat.gd`

```gdscript
extends "res://addons/gut/test.gd"

const FRAME := 1.0 / 60.0

func _fighter_at(x: float) -> Fighter:
	var f := Fighter.new()
	add_child_autofree(f)
	f.global_position = Vector2(x, 400)
	return f

func _punch() -> MoveSequence:
	return load("res://assets/sequences/doink/punch.tres")

func test_fighter_starts_at_full_health():
	assert_eq(_fighter_at(0).health, Damage.LIFE_MAX)

func test_starting_a_move_blocks_input():
	var f := _fighter_at(0)
	f.start_move(_punch())
	assert_false(Fighter.input_allowed(f.mode) and not f.is_attacking(),
		"while a uninterruptable move plays, movement input is suppressed")
	assert_true(f.is_attacking())

func test_punch_in_range_damages_victim():
	var attacker := _fighter_at(100)
	var victim := _fighter_at(140)            # within punch reach (offset 22 + width)
	var resolver := AttackResolver.new()
	add_child_autofree(resolver)
	attacker.start_move(_punch())
	# step until the punch's attack window has opened and resolver has matched it
	for _i in range(20):
		attacker._physics_process(FRAME)
		victim._physics_process(FRAME)
		resolver.resolve_tick()
	assert_lt(victim.health, Damage.LIFE_MAX, "victim took damage")

func test_punch_out_of_range_does_nothing():
	var attacker := _fighter_at(100)
	var victim := _fighter_at(400)            # far away
	var resolver := AttackResolver.new()
	add_child_autofree(resolver)
	attacker.start_move(_punch())
	for _i in range(20):
		attacker._physics_process(FRAME)
		victim._physics_process(FRAME)
		resolver.resolve_tick()
	assert_eq(victim.health, Damage.LIFE_MAX, "no hit out of range")

func test_a_single_swing_hits_only_once():
	var attacker := _fighter_at(100)
	var victim := _fighter_at(140)
	var resolver := AttackResolver.new()
	add_child_autofree(resolver)
	attacker.start_move(_punch())
	for _i in range(30):
		attacker._physics_process(FRAME)
		victim._physics_process(FRAME)
		resolver.resolve_tick()
	# punch base 8 -> 10 after offense mod; exactly one application
	assert_eq(victim.health, Damage.LIFE_MAX - 10, "one hit per swing, no multi-tick re-hits")

func test_knockdown_puts_victim_onground_then_gets_up():
	var attacker := _fighter_at(100)
	var victim := _fighter_at(140)
	victim.mode = Fighter.Mode.RUNNING        # so big boot is in-range; resolver hits hurt box
	var resolver := AttackResolver.new()
	add_child_autofree(resolver)
	attacker.start_move(load("res://assets/sequences/doink/big_boot.tres"))
	for _i in range(30):
		attacker._physics_process(FRAME)
		victim._physics_process(FRAME)
		resolver.resolve_tick()
	assert_eq(victim.mode, Fighter.Mode.ONGROUND, "knocked down")
```

- [ ] **Step 2: Run, expect fail** (`AttackResolver`/`Fighter.start_move`/`health` undefined).

- [ ] **Step 3: Implement the Fighter combat members** — edit `scripts/fighter.gd`

Add fields near the existing exports:

```gdscript
## Combat state.
var health: int = Damage.LIFE_MAX
var _player: SequencePlayer = SequencePlayer.new()
var _react_timer: float = 0.0     # seconds left in a reaction (hitstun/getup/dizzy)
var _react_recover_mode: int = Mode.NORMAL
var _last_damage_time: float = -999.0   # _sim_time of last hit taken; for the ⅔ repeat window
var _sim_time: float = 0.0               # accumulated sim-time (deterministic; NOT wall-clock)
var _hit_by_current_move: Array = []     # victims already hit by the swing in progress
```

Add `is_attacking()` and rewrite `_physics_process` so an active move suppresses walk input and advances the sequence; reactions tick down here too:

```gdscript
func is_attacking() -> bool:
	return _player.is_playing()

func _physics_process(delta: float) -> void:
	_sim_time += delta   # advance the deterministic clock in every phase

	# 1) Reaction countdown (hitstun / getup / dizzy): no control, no walk.
	if _react_timer > 0.0:
		_react_timer -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		global_position = MovementMath.clamp_to_floor(global_position, floor_min_y, floor_max_y)
		if _react_timer <= 0.0:
			mode = _react_recover_mode
		return

	# 2) Attacking: advance the sequence, hold position, no walk input.
	if _player.is_playing():
		velocity = Vector2.ZERO
		_player.advance(delta)
		if not _player.is_playing():
			_hit_by_current_move.clear()
		_play_sequence_anim()
		return

	# 3) Normal movement (Plan 2a feel layer).
	var dir: Vector2 = Vector2.ZERO
	if Fighter.input_allowed(mode):
		dir = get_input_direction()
		var target: Vector2 = MovementMath.walk_velocity(dir) * walk_speed_scale
		velocity = velocity.move_toward(target, walk_acceleration * delta)
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	_apply_separation()
	global_position = MovementMath.clamp_to_floor(global_position, floor_min_y, floor_max_y)
	_update_facing(dir)
	_update_animation(dir)
```

Add the combat API:

```gdscript
## Begin a move sequence (ignored while attacking-uninterruptable or in a reaction).
func start_move(move: MoveSequence) -> void:
	if _react_timer > 0.0:
		return
	if _player.is_playing() and _player.sequence.uninterruptable:
		return
	_player.play(move)
	_hit_by_current_move.clear()
	_play_sequence_anim()

## Facing as ±1 (front/right = +1). Derived from the sprite flip set by _update_facing.
func facing() -> float:
	return -1.0 if (sprite != null and sprite.flip_h) else 1.0

## The live attack box this tick, or null.
func current_attack_box() -> Box3:
	return _player.active_attack_box if _player.attack_live else null

func hurt_box() -> Box3:
	return Hitbox.hurt_box_for_mode(mode)

func already_hit(victim: Node) -> bool:
	return _hit_by_current_move.has(victim)

## Apply a landed hit from `attacker` using `move`. Called by AttackResolver.
func receive_hit(attacker: Fighter, move: MoveSequence) -> void:
	attacker._hit_by_current_move.append(self)
	var now := _sim_time   # per-fighter accumulated sim-time (advanced in _physics_process); NOT wall-clock, for determinism
	var repeat := (now - _last_damage_time) <= ArcadeUnits.ticks_to_seconds(Damage.REPEAT_WINDOW_TICKS)
	var blocked := mode == Mode.BLOCK
	var dmg := Damage.resolve(move.attack_mode, repeat, blocked)
	health = Damage.apply_health(health, dmg)
	_last_damage_time = now

	var side := Hitbox.hit_side(attacker.global_position, global_position)
	var family := AMode.Family.BLOCK if blocked else AMode.reaction_for(move.attack_mode)
	var r := Reaction.resolve(family, side, move.causes_dizzy and not blocked)
	_enter_reaction(r, side)

func _enter_reaction(r: Dictionary, side: int) -> void:
	# Cancel any move in progress; play the reaction anim; set timer & recover mode.
	_player.play(null)
	_hit_by_current_move.clear()               # a cancelled swing leaves no stale hit-list
	mode = r.mode
	global_position.x += side * r.knockback    # Hitbox.hit_side IS the push direction (away from attacker)
	_react_recover_mode = Mode.NORMAL
	_react_timer = ArcadeUnits.ticks_to_seconds(maxi(r.hitstun_ticks, r.getup_ticks))
	if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(r.anim):
		sprite.play(r.anim)

func _play_sequence_anim() -> void:
	if sprite == null or _player.sequence == null:
		return
	var anim: String = _player.sequence.anim_name
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
		sprite.play(anim)
```

> Note: `SequencePlayer.play(null)` must no-op cleanly — guard it: in `play()`, `if seq == null: sequence = null; attack_live = false; active_attack_box = null; return`.
> Add that guard to `sequence_player.gd` as part of this task and re-run Task 5's tests to confirm still green.

- [ ] **Step 4: Implement the resolver** — `scripts/combat/attack_resolver.gd`

```gdscript
class_name AttackResolver
extends Node
## Each physics tick, match every live attack box against every other fighter's hurt box.
## A given swing hits each victim at most once (Fighter tracks _hit_by_current_move).

func _physics_process(_delta: float) -> void:
	resolve_tick()

func resolve_tick() -> void:
	var fighters := get_tree().get_nodes_in_group("fighters")
	for attacker in fighters:
		var atk_box: Box3 = attacker.current_attack_box()
		if atk_box == null:
			continue
		for victim in fighters:
			if victim == attacker or attacker.already_hit(victim):
				continue
			# Eligibility filters (dead/teammate/pin/in-ring) arrive with those systems
			# in later plans; for 2b a live box hits any other fighter once.
			var hb: Box3 = victim.hurt_box()
			if Hitbox.boxes_overlap(atk_box, attacker.global_position, attacker.facing(), 0.0,
					hb, victim.global_position, victim.facing(), 0.0):
				victim.receive_hit(attacker, attacker._player.sequence)
```

- [ ] **Step 5: Run the integration tests, expect pass**

```bash
godot --headless --path . --import
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -gprefix=test_ -gsuffix=.gd -ginclude_subdirs -gselect=test_fighter_combat.gd -gexit
```
Expected: all `test_fighter_combat.gd` tests pass. If the punch-range test misses, nudge the victim x or the attack-box width to overlap (the resolver/geometry is the source of truth — adjust the **test fixture distance**, not the formula).

- [ ] **Step 6: Run the FULL suite (regression)**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -gprefix=test_ -gsuffix=.gd -ginclude_subdirs -gexit
```
Expected: all green (Plan 2a's 32 + the new combat tests).

- [ ] **Step 7: Commit**

```bash
git add scripts/fighter.gd scripts/combat/attack_resolver.gd scripts/combat/sequence_player.gd test/unit/test_fighter_combat.gd
git commit -m "feat(combat): Fighter health/hurt-box/sequence + AttackResolver hit application + reactions"
```

---

## Task 8: Wire player buttons + Sandbox; playtest; tag

**Files:** Modify `scripts/player.gd`, `scenes/Sandbox.tscn`

- [ ] **Step 1: Map attack actions** — confirm/add input actions

The per-player input map is generated by `tools/setup_input_map.gd`. Add punch/kick actions there (mirror the existing movement entries) for `p1_punch`, `p1_kick`, `p2_punch`, `p2_kick`, then re-run it:

```bash
godot --headless --path . -s tools/setup_input_map.gd
```
(Bind p1 to e.g. `J`/`K`, p2 to numpad — match the file's existing style. If `setup_input_map.gd` writes `project.godot`, verify the new actions appear under `[input]`.)

- [ ] **Step 2: Fire moves from input** — edit `scripts/player.gd`

```gdscript
const _PUNCH := preload("res://assets/sequences/doink/punch.tres")
const _HEADBUTT := preload("res://assets/sequences/doink/headbutt.tres")
const _KICK := preload("res://assets/sequences/doink/kick.tres")
const _BIG_BOOT := preload("res://assets/sequences/doink/big_boot.tres")

func _unhandled_input(_event: InputEvent) -> void:
	var p := _action_prefix()
	if Input.is_action_just_pressed(p + "punch"):
		# close -> headbutt, else punch (range gate is a 2c refinement; pick by nearest fighter)
		start_move(_HEADBUTT if _opponent_is_close() else _PUNCH)
	elif Input.is_action_just_pressed(p + "kick"):
		start_move(_BIG_BOOT if mode == Mode.RUNNING else _KICK)

func _opponent_is_close() -> bool:
	var nearest := 1e9
	for f in get_tree().get_nodes_in_group("fighters"):
		if f == self:
			continue
		nearest = minf(nearest, absf(f.global_position.x - global_position.x))
	return nearest <= 50.0   # arcade close gate ~50 (DOINK.ASM:1921)
```

- [ ] **Step 3: Add the resolver to the scene** — edit `scenes/Sandbox.tscn`

Add one `AttackResolver` node (script `res://scripts/combat/attack_resolver.gd`) as a child of the Sandbox root so `_physics_process` runs the per-tick match. (Edit the `.tscn` text: add a `[node name="AttackResolver" type="Node" parent="."]` with its `script` ext_resource, mirroring how other scripted nodes are declared in the file.)

- [ ] **Step 4: Build & run; verify Definition of Done by playing**

```bash
godot --headless --path . --import
godot --path .
```

- [ ] P1 presses punch near P2 → Doink throws the punch anim; P2 flinches (`facepunched`) and the life bar (if shown) / `health` drops by ~10.
- [ ] Punch at distance → whiffs, no damage.
- [ ] Headbutt up close → P2 goes dizzy (`stuned`) and can't act briefly.
- [ ] Kick → body reaction (`shoved`). Big boot while running → P2 knocked down (`droped` → stays down ~5 s → `get_up_front`).
- [ ] One swing = one hit (no machine-gun multi-hits while the box is live).
- [ ] No Godot errors about missing animations/sequences.

- [ ] **Step 5: Re-run the full suite (regression)**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -gprefix=test_ -gsuffix=.gd -ginclude_subdirs -gexit
```
Expected: all green.

- [ ] **Step 6: Commit & tag**

```bash
git add scripts/player.gd scenes/Sandbox.tscn project.godot tools/setup_input_map.gd
git commit -m "feat(combat): player attack buttons + Sandbox AttackResolver; playtest pass"
git tag sp0-plan2b-hit-detection
```

---

## Definition of Done (Plan 2b)

A Doink strike fires a data-driven `MoveSequence` whose `ATTACK_ON/OFF` window opens a 3D-AABB attack box; the per-tick `AttackResolver` lands it on an in-range victim exactly once, applies arcade damage (×1.348 offense, ⅔ repeat within 50 ticks, block → 1, health clamped to 163 with the lethal-fudge/KO rules), and the victim plays the reaction family selected by the attacker's `AMODE` — head/body hit (stand), fall-back, knockdown with a 270-tick getup, stagger, on-ground, and dizzy. GUT suite green; manual playtest confirms feel.

## Notes / deferred to later sub-plans

- **Range/relative-input move selection** (the full `action_table` + `JJXM` close/far dispatch, `FACE24` `_2_`/`_4_` variants): only a coarse close/far + running gate is wired here. Full table → 2c.
- **Motion-buffer & "smove" specials** (boxing glove, hammer, joybuzzer, grapples/throws + puppet `ANI_SUPERSLAVE2`): the puppet *victim* channel and grapple attach/reversal are a dedicated plan (2d).
- **Combo scaling** `(15 − hit#)`, `DAM_MULT`, drone/speed adjustments, friendly-fire 1px, and the combo-death deferral: 2d with the combo system.
- **Mash-to-recover getup** and per-AMODE×per-wrestler getup table: timer getup only here; mash + table → 2c.
- **Jump/height (Y axis)**: hurt/attack Y is present in the math but `height` is fixed 0; aerials/turnbuckle → 2c/2e.
- **Pin & KO death anim/state machine**: 2e.
- Per-move attack-box dims are best-effort from research (only the punch box is cited exactly); tune during playtest.
```
