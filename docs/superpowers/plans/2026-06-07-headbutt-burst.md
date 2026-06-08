# Headbutt Burst + Slow Low-Punch Headbutt Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** At CLOSE range, Doink's high-punch drives a mash-to-extend headbutt burst (cap 4, only the burst-ending hit pops); the low-punch does a single slower, stronger, popping headbutt with no burst.

**Architecture:** A pure `BurstState` counter holds the chain logic; `Player` wires it to input and decides chain-vs-end at each burst hit's move-end boundary, applying a deferred ender-pop via a new `Fighter.pop_from_headbutt`. The pop (hop) is separated from the dizzy stun by a per-move `victim_pop` flag, and a per-move `damage_override` makes the single low-punch stronger. Both close headbutts reuse the existing `headbutt_front/back` art.

**Tech Stack:** Godot 4.6 / GDScript, GUT unit tests (headless).

**Spec:** `docs/superpowers/specs/2026-06-07-headbutt-burst-design.md`

**Conventions:**
- Run tests: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit`
- Run ONE test file: append `-gtest=res://test/unit/<file>.gd`
- A new `class_name` script needs the class cache rebuilt before the headless runner sees it: `godot --headless --path . --import`
- GUT tests extend `"res://addons/gut/test.gd"`.

---

### Task 1: `BurstState` pure counter

**Files:**
- Create: `scripts/combat/burst_state.gd`
- Test: `test/unit/test_burst_state.gd`

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_burst_state.gd`:

```gdscript
extends "res://addons/gut/test.gd"

func test_starts_inactive():
	var b := BurstState.new()
	assert_false(b.is_active())
	assert_eq(b.count, 0)

func test_start_sets_count_one():
	var b := BurstState.new()
	b.start()
	assert_true(b.is_active())
	assert_eq(b.count, 1)
	assert_false(b.continue_pressed)

func test_note_continue_enables_chain():
	var b := BurstState.new()
	b.start()
	assert_false(b.can_chain())
	b.note_continue()
	assert_true(b.can_chain())

func test_advance_increments_and_clears_continue():
	var b := BurstState.new()
	b.start()
	b.note_continue()
	b.advance()
	assert_eq(b.count, 2)
	assert_false(b.continue_pressed)
	assert_false(b.can_chain())

func test_caps_at_four():
	var b := BurstState.new()
	b.start()
	for i in range(3):
		b.note_continue()
		assert_true(b.can_chain())
		b.advance()
	assert_eq(b.count, 4)
	b.note_continue()                 # cannot buffer past the cap
	assert_false(b.continue_pressed)
	assert_false(b.can_chain())

func test_reset_clears():
	var b := BurstState.new()
	b.start()
	b.note_continue()
	b.advance()
	b.reset()
	assert_false(b.is_active())
	assert_eq(b.count, 0)
	assert_false(b.continue_pressed)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `godot --headless --path . --import` then
`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://test/unit/test_burst_state.gd -gexit`
Expected: FAIL / parse error — `BurstState` does not exist yet.

- [ ] **Step 3: Write the implementation**

Create `scripts/combat/burst_state.gd`:

```gdscript
class_name BurstState
## Pure mash-to-extend burst counter (Doink headbutt burst). No scene/engine deps so it is
## unit-testable in isolation. count 0 = idle. The owner calls start() on the first hit,
## note_continue() when the attack button is re-pressed during a hit, then at each hit's end
## uses can_chain()/advance() to continue or reset() to stop. Caps at MAX hits in a row.

const MAX := 4

var count: int = 0
var continue_pressed: bool = false

func is_active() -> bool:
	return count > 0

func start() -> void:
	count = 1
	continue_pressed = false

func note_continue() -> void:
	if count < MAX:
		continue_pressed = true

func can_chain() -> bool:
	return continue_pressed and count < MAX

func advance() -> void:
	count += 1
	continue_pressed = false

func reset() -> void:
	count = 0
	continue_pressed = false
```

- [ ] **Step 4: Rebuild the class cache and run the test**

Run: `godot --headless --path . --import`
Then: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://test/unit/test_burst_state.gd -gexit`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add scripts/combat/burst_state.gd test/unit/test_burst_state.gd
git commit -m "Add BurstState: pure mash-to-extend burst counter"
```

---

### Task 2: `MoveSequence` gains `victim_pop` + `damage_override`

**Files:**
- Modify: `scripts/combat/move_sequence.gd`
- Test: `test/unit/test_move_sequence.gd`

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_move_sequence.gd`:

```gdscript
extends "res://addons/gut/test.gd"

func test_defaults():
	var m := MoveSequence.new()
	assert_false(m.victim_pop, "victim_pop defaults false")
	assert_eq(m.damage_override, 0, "damage_override defaults 0")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://test/unit/test_move_sequence.gd -gexit`
Expected: FAIL — `Invalid get index 'victim_pop'`.

- [ ] **Step 3: Add the fields**

In `scripts/combat/move_sequence.gd`, after the `causes_dizzy` export (the line
`@export var causes_dizzy: bool = false`), add:

```gdscript
## When this move's hit causes the dizzy reaction, ALSO apply the upward pop (hop). Separates a
## "dizzy stun" (burst intermediate, false) from a "dizzy + pop" (single headbutt / burst ender, true).
@export var victim_pop: bool = false
## Base damage to use instead of the attack_mode default (DamageTable.base) when > 0. Still runs
## through the offense scaling in Damage.resolve. Lets two same-amode moves differ in power.
@export var damage_override: int = 0
```

- [ ] **Step 4: Run the test**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://test/unit/test_move_sequence.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/combat/move_sequence.gd test/unit/test_move_sequence.gd
git commit -m "MoveSequence: add victim_pop and damage_override fields"
```

---

### Task 3: `Damage.resolve` honors a base override

**Files:**
- Modify: `scripts/combat/damage.gd:31-37` (the `resolve` function)
- Test: `test/unit/test_damage.gd`

- [ ] **Step 1: Write the failing test**

Append to `test/unit/test_damage.gd`:

```gdscript
func test_base_override_replaces_amode_base():
	# 17 * 345 / 256 = 22 (overrides HDBUTT's base of 12)
	assert_eq(Damage.resolve(AMode.HDBUTT, false, false, 17), 22)

func test_base_override_ignores_repeat_column():
	# override is a fixed base; repeat does NOT drop it to 2/3 -> still 22
	assert_eq(Damage.resolve(AMode.HDBUTT, true, false, 17), 22)

func test_base_override_still_blocked_is_one():
	assert_eq(Damage.resolve(AMode.HDBUTT, false, true, 17), 1)

func test_zero_override_uses_amode_base():
	# 12 * 345 / 256 = 16 (HDBUTT default, unchanged)
	assert_eq(Damage.resolve(AMode.HDBUTT, false, false, 0), 16)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://test/unit/test_damage.gd -gexit`
Expected: FAIL — `resolve()` takes 3 args, got 4.

- [ ] **Step 3: Add the optional parameter**

In `scripts/combat/damage.gd`, replace the `resolve` function:

```gdscript
## Damage a hit deals. `repeat` picks the ⅔ column; `blocked` overrides to 1px. `base_override`
## (> 0) replaces the attack_mode base (still offense-scaled, and not reduced by `repeat`).
static func resolve(amode: int, repeat: bool, blocked: bool, base_override: int = 0) -> int:
	if blocked:
		return BLOCK_DAMAGE
	var base_dmg: int
	if base_override > 0:
		base_dmg = base_override
	else:
		base_dmg = DamageTable.repeat(amode) if repeat else DamageTable.base(amode)
	return (base_dmg * (256 + OFFENSE_MOD)) / 256   # ×1.348, integer
```

- [ ] **Step 4: Run the test**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://test/unit/test_damage.gd -gexit`
Expected: PASS (all, including the 4 new).

- [ ] **Step 5: Commit**

```bash
git add scripts/combat/damage.gd test/unit/test_damage.gd
git commit -m "Damage.resolve: optional base_override for per-move power"
```

---

### Task 4: `Reaction.resolve` gates the hop behind a `pop` flag

**Files:**
- Modify: `scripts/combat/reaction.gd:8-32`
- Test: `test/unit/test_reaction.gd`

- [ ] **Step 1: Update/extend the tests**

In `test/unit/test_reaction.gd`, REPLACE `test_headbutt_reaction_pops_up_and_is_anim_timed` with the
following two tests (keep every other test as-is):

```gdscript
func test_headbutt_pop_true_hops_and_is_anim_timed():
	# Dizzy + pop -> upward hop (arcade REACT1.ASM:1171 OBJ_YVEL 0x3C000), recover on clip end.
	var r := Reaction.resolve(AMode.Family.HEAD_HIT, 1, true, true)
	assert_eq(r.anim, "headbutted_salted")
	assert_eq(r.mode, Fighter.Mode.DIZZY)
	assert_true(r.anim_timed)
	assert_almost_eq(r.hop, ArcadeUnits.HDBUTT_HOP_YVEL, 0.01)

func test_headbutt_pop_false_is_dizzy_stun_no_hop():
	# Dizzy WITHOUT pop -> same dizzy stun + anim, but NO hop (burst intermediate hit).
	var r := Reaction.resolve(AMode.Family.HEAD_HIT, 1, true, false)
	assert_eq(r.anim, "headbutted_salted")
	assert_eq(r.mode, Fighter.Mode.DIZZY)
	assert_true(r.anim_timed)
	assert_eq(r.hop, 0.0)
```

Note: the existing `test_dizzy_overrides_to_headbutted` calls `resolve(..., 1, true)` (3 args) and does
NOT check hop — it still passes (pop defaults false).

- [ ] **Step 2: Run it to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://test/unit/test_reaction.gd -gexit`
Expected: FAIL — `resolve()` takes 3 args, got 4.

- [ ] **Step 3: Add the `pop` parameter and gate the hop**

In `scripts/combat/reaction.gd`, change the function signature line:

```gdscript
static func resolve(family: int, side: int, dizzy: bool, pop: bool = false) -> Dictionary:
```

and replace the `AMode.Family.DIZZY` branch body with:

```gdscript
		AMode.Family.DIZZY:
			# Headbutt: dizzy stun on `headbutted_salted`, recovery on clip-end (anim_timed). The
			# upward pop (arcade REACT1.ASM:1171 OBJ_YVEL 0x3c000) is applied ONLY when `pop` is
			# set — burst intermediates stun without it; the single headbutt / burst ender pop.
			var hop := ArcadeUnits.HDBUTT_HOP_YVEL if pop else 0.0
			return _r("headbutted_salted", Fighter.Mode.DIZZY, 0, 6.0,
				AMode.getup_ticks(AMode.Family.DIZZY), hop, true)
```

- [ ] **Step 4: Run the test**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://test/unit/test_reaction.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/combat/reaction.gd test/unit/test_reaction.gd
git commit -m "Reaction.resolve: gate the headbutt hop behind a pop flag"
```

---

### Task 5: `Fighter` — wire `victim_pop`/`damage_override` + add `pop_from_headbutt`

**Files:**
- Modify: `scripts/fighter.gd` (`receive_hit` damage + reaction lines; add `pop_from_headbutt`)
- Test: `test/unit/test_fighter_burst_pop.gd`

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_fighter_burst_pop.gd`:

```gdscript
extends "res://addons/gut/test.gd"

func _fighter_at(x: float, y: float, mode := Fighter.Mode.NORMAL) -> Fighter:
	var f := Fighter.new()
	add_child_autofree(f)
	f.global_position = Vector2(x, y)
	f.side = Fighter.Side.ENEMY
	f.separation_radii = Vector2.ZERO
	f.mode = mode
	return f

func _headbutt(pop: bool, dmg_override := 0) -> MoveSequence:
	var m := MoveSequence.new()
	m.id = "test_headbutt"
	m.attack_mode = AMode.HDBUTT
	m.causes_dizzy = true
	m.victim_pop = pop
	m.damage_override = dmg_override
	return m

func test_victim_pop_true_hops():
	var atk := _fighter_at(100, 400)
	var vic := _fighter_at(140, 400, Fighter.Mode.NORMAL)
	vic.receive_hit(atk, _headbutt(true))
	assert_eq(vic.mode, Fighter.Mode.DIZZY)
	assert_gt(vic._vy, 0.0)

func test_victim_pop_false_no_hop():
	var atk := _fighter_at(100, 400)
	var vic := _fighter_at(140, 400, Fighter.Mode.NORMAL)
	vic.receive_hit(atk, _headbutt(false))
	assert_eq(vic.mode, Fighter.Mode.DIZZY)
	assert_eq(vic._vy, 0.0)

func test_damage_override_hits_harder():
	var atk := _fighter_at(100, 400)
	var vic := _fighter_at(140, 400, Fighter.Mode.NORMAL)
	vic.health = 163
	vic.receive_hit(atk, _headbutt(false, 17))   # 17*345/256 = 22
	assert_eq(vic.health, 141)

func test_pop_from_headbutt_pops_and_pushes_away():
	var atk := _fighter_at(100, 400)
	var vic := _fighter_at(140, 400, Fighter.Mode.NORMAL)
	vic.pop_from_headbutt(atk)
	assert_eq(vic.mode, Fighter.Mode.DIZZY)
	assert_gt(vic._vy, 0.0)
	assert_gt(vic.global_position.x, 140.0)   # knocked away from the attacker (to the right)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://test/unit/test_fighter_burst_pop.gd -gexit`
Expected: FAIL — `pop_from_headbutt` not found; pop/override not applied.

- [ ] **Step 3: Wire `receive_hit` and add `pop_from_headbutt`**

In `scripts/fighter.gd`, inside `receive_hit`, change the damage line:

```gdscript
	var dmg := Damage.resolve(move.attack_mode, repeat, blocked, move.damage_override)
```

and change the reaction line (near the end of `receive_hit`):

```gdscript
	var r := Reaction.resolve(family, hit_dir, move.causes_dizzy, move.victim_pop)
```

Then add this new method immediately AFTER the `receive_hit` function (before `receive_grab`):

```gdscript
## Apply the headbutt pop to this victim with no strike landing — the burst chain (Player) pops
## whoever it last hit the moment the burst ends. Reuses the dizzy + hop reaction; the shipped
## re-hit restart makes the hand-off from the last intermediate stun smooth.
func pop_from_headbutt(attacker: Fighter) -> void:
	var hit_dir := Hitbox.hit_side(attacker.global_position, global_position)
	var r := Reaction.resolve(AMode.Family.HEAD_HIT, hit_dir, true, true)
	_enter_reaction(r, hit_dir)
```

- [ ] **Step 4: Run the test**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://test/unit/test_fighter_burst_pop.gd -gexit`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add scripts/fighter.gd test/unit/test_fighter_burst_pop.gd
git commit -m "Fighter: apply victim_pop/damage_override; add pop_from_headbutt"
```

---

### Task 6: Author `headbutt_burst` + retune `headbutt` sequences

**Files:**
- Modify: `tools/build_doink_sequences.gd:30` (the headbutt line)
- Generated: `assets/sequences/doink/headbutt.tres`, `assets/sequences/doink/headbutt_burst.tres`
- Test: `test/unit/test_move_sequence.gd`

- [ ] **Step 1: Write the failing test**

Append to `test/unit/test_move_sequence.gd`:

```gdscript
func test_headbutt_is_slow_strong_popping():
	var m: MoveSequence = load("res://assets/sequences/doink/headbutt.tres")
	assert_eq(m.attack_mode, AMode.HDBUTT)
	assert_true(m.causes_dizzy)
	assert_true(m.victim_pop, "single low-punch headbutt pops")
	assert_gt(m.damage_override, 12, "stronger than a default headbutt")

func test_headbutt_burst_is_nonpop_dizzy():
	var m: MoveSequence = load("res://assets/sequences/doink/headbutt_burst.tres")
	assert_eq(m.attack_mode, AMode.HDBUTT)
	assert_true(m.causes_dizzy)
	assert_false(m.victim_pop, "burst hits do not pop; the ender pop is applied by the chain")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://test/unit/test_move_sequence.gd -gexit`
Expected: FAIL — `headbutt_burst.tres` missing; `headbutt` has no `victim_pop`/`damage_override` set.

- [ ] **Step 3: Author the moves in the builder**

In `tools/build_doink_sequences.gd`, REPLACE the existing headbutt line (line 30):

```gdscript
	_save(_strike("headbutt", "headbutt_front",  AMode.HDBUTT,  6, 3, _ab(18, 92, 0, 40, 12, 10), true, 2, "headbutt_back"))
```

with the retuned single headbutt PLUS the new burst hit:

```gdscript
	# Close LOW_PUNCH: single slower (3 ticks/frame), stronger (override 17 > 12) headbutt that POPS.
	var hb := _strike("headbutt", "headbutt_front", AMode.HDBUTT, 6, 3, _ab(18, 92, 0, 40, 12, 10), true, 3, "headbutt_back")
	hb.victim_pop = true
	hb.damage_override = 17
	_save(hb)
	# Close HIGH_PUNCH: fast (2 ticks/frame) burst hit. Dizzy STUN, NO pop (the burst chain applies
	# the ender pop). Reuses the same headbutt art; mapped CLOSE+NEUTRAL+HIGH_PUNCH in the move table.
	var hbb := _strike("headbutt_burst", "headbutt_front", AMode.HDBUTT, 6, 3, _ab(18, 92, 0, 40, 12, 10), true, 2, "headbutt_back")
	hbb.victim_pop = false
	_save(hbb)
```

- [ ] **Step 4: Regenerate the sequences, reimport, and run the test**

Run (in order):
```bash
godot --headless --path . -s tools/build_doink_sequences.gd
godot --headless --path . --import
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://test/unit/test_move_sequence.gd -gexit
```
Expected: builder prints `headbutt (...) -> OK` and `headbutt_burst (...) -> OK`; test PASSES.

- [ ] **Step 5: Commit**

```bash
git add tools/build_doink_sequences.gd assets/sequences/doink/headbutt.tres assets/sequences/doink/headbutt_burst.tres test/unit/test_move_sequence.gd
git commit -m "Sequences: retune headbutt (slow/strong/pop) + add headbutt_burst (fast/no-pop)"
```

---

### Task 7: Map CLOSE high-punch to the burst

**Files:**
- Modify: `tools/build_doink_movetable.gd` (load + the `CLOSE`/`HIGH_PUNCH` entry)
- Generated: `assets/movetables/doink.tres`
- Test: `test/unit/test_move_table.gd`

- [ ] **Step 1: Update the table test**

In `test/unit/test_move_table.gd`, REPLACE `test_super_punch_far_slap_close_down_uppercut` with:

```gdscript
func test_super_punch_far_slap_close_burst_down_uppercut():
	assert_eq(_id(MoveTable.Rng.NORMAL,   MoveTable.Dir.NEUTRAL, MoveTable.Btn.HIGH_PUNCH), "slap")
	assert_eq(_id(MoveTable.Rng.CLOSE,    MoveTable.Dir.NEUTRAL, MoveTable.Btn.HIGH_PUNCH), "headbutt_burst")
	assert_eq(_id(MoveTable.Rng.CLOSE,    MoveTable.Dir.DOWN,    MoveTable.Btn.HIGH_PUNCH), "uppercut")
	assert_eq(_id(MoveTable.Rng.GROUNDED, MoveTable.Dir.NEUTRAL, MoveTable.Btn.HIGH_PUNCH), "elbow_drop")
	assert_eq(_id(MoveTable.Rng.RUNNING,  MoveTable.Dir.NEUTRAL, MoveTable.Btn.HIGH_PUNCH), "flying_clothesline")

func test_low_punch_close_is_single_headbutt():
	assert_eq(_id(MoveTable.Rng.CLOSE, MoveTable.Dir.NEUTRAL, MoveTable.Btn.LOW_PUNCH), "headbutt")
```

- [ ] **Step 2: Run it to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://test/unit/test_move_table.gd -gexit`
Expected: FAIL — CLOSE+NEUTRAL+HIGH_PUNCH is still `slap`.

- [ ] **Step 3: Point the close high-punch cell at the burst**

In `tools/build_doink_movetable.gd`, add a loader next to the other `load(...)` lines (after the
`var slap := ...` line):

```gdscript
	var headbutt_burst: MoveSequence = load(SEQ + "headbutt_burst.tres")
```

Then REPLACE this line:

```gdscript
	t.add(R.CLOSE,    D.NEUTRAL, B.HIGH_PUNCH, slap)
```

with:

```gdscript
	t.add(R.CLOSE,    D.NEUTRAL, B.HIGH_PUNCH, headbutt_burst)   # close high-punch = headbutt burst
```

(Leave `NORMAL+HIGH_PUNCH = slap` and `CLOSE+DOWN+HIGH_PUNCH = uppercut` unchanged.)

- [ ] **Step 4: Regenerate the table, reimport, and run the test**

Run (in order):
```bash
godot --headless --path . -s tools/build_doink_movetable.gd
godot --headless --path . --import
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://test/unit/test_move_table.gd -gexit
```
Expected: builder prints `doink movetable -> OK`; test PASSES.

- [ ] **Step 5: Commit**

```bash
git add tools/build_doink_movetable.gd assets/movetables/doink.tres test/unit/test_move_table.gd
git commit -m "MoveTable: close high-punch -> headbutt burst"
```

---

### Task 8: Player burst wiring (start / buffer / chain-or-end + ender pop)

**Files:**
- Modify: `scripts/player.gd` (constants, state, `_physics_process`, `_dispatch_normal_move`; add helpers)
- Test: `test/unit/test_player_burst.gd`

- [ ] **Step 1: Write the failing test**

Create `test/unit/test_player_burst.gd`:

```gdscript
extends "res://addons/gut/test.gd"

const BURST := preload("res://assets/sequences/doink/headbutt_burst.tres")

func _player_at(x: float, y: float) -> Player:
	var p := Player.new()
	add_child_autofree(p)
	p.global_position = Vector2(x, y)
	p.side = Fighter.Side.PLAYER
	p.separation_radii = Vector2.ZERO
	return p

func _enemy_at(x: float, y: float) -> Fighter:
	var e := Fighter.new()
	add_child_autofree(e)
	e.global_position = Vector2(x, y)
	e.side = Fighter.Side.ENEMY
	e.separation_radii = Vector2.ZERO
	e.mode = Fighter.Mode.NORMAL
	return e

# Drive a single burst hit, then end its move so the chain decision can run.
func _land_one_burst_hit(p: Player, e: Fighter) -> void:
	p.start_move(BURST)
	e.receive_hit(p, BURST)      # appends e to p._hit_by_current_move; e enters dizzy (no pop)
	p._player.play(null)         # simulate the burst hit's sequence finishing (not is_attacking)

func test_chain_continues_when_buffered_and_close():
	var p := _player_at(100, 400)
	var e := _enemy_at(130, 410)   # CLOSE
	p.target = e
	p._burst.start()               # count 1
	_land_one_burst_hit(p, e)
	p._burst.note_continue()       # player re-pressed during the hit
	assert_true(p._service_burst_end(true))
	assert_true(p.is_attacking(), "started the next burst hit")
	assert_eq(p._burst.count, 2)

func test_burst_ends_and_pops_when_not_buffered():
	var p := _player_at(100, 400)
	var e := _enemy_at(130, 410)
	p.target = e
	p._burst.start()
	_land_one_burst_hit(p, e)
	assert_eq(e._vy, 0.0, "intermediate hit did not pop")
	assert_true(p._service_burst_end(true))      # no continue buffered
	assert_false(p.is_attacking(), "no chain")
	assert_eq(p._burst.count, 0, "burst reset")
	assert_gt(e._vy, 0.0, "ender popped the victim")

func test_cap_at_four_forces_end_and_pop():
	var p := _player_at(100, 400)
	var e := _enemy_at(130, 410)
	p.target = e
	p._burst.count = 4             # at the cap
	_land_one_burst_hit(p, e)
	p._burst.note_continue()       # ignored at the cap
	assert_true(p._service_burst_end(true))
	assert_false(p.is_attacking())
	assert_eq(p._burst.count, 0)
	assert_gt(e._vy, 0.0)

func test_out_of_range_ends_with_pop():
	var p := _player_at(100, 400)
	var e := _enemy_at(130, 410)
	p.target = e
	p._burst.start()
	_land_one_burst_hit(p, e)
	p._burst.note_continue()
	assert_true(p._service_burst_end(false))     # close = false -> cannot chain
	assert_false(p.is_attacking())
	assert_eq(p._burst.count, 0)
	assert_gt(e._vy, 0.0)
```

- [ ] **Step 2: Run it to verify it fails**

Run: `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://test/unit/test_player_burst.gd -gexit`
Expected: FAIL — `_burst` / `_service_burst_end` not found.

- [ ] **Step 3: Add the burst constant + state**

In `scripts/player.gd`, after the existing `const _FLYING_KICK := ...` line, add:

```gdscript
const _HEADBUTT_BURST := preload("res://assets/sequences/doink/headbutt_burst.tres")
```

and after the `@export var player_index: int = 0` line, add:

```gdscript
## Mash-to-extend headbutt burst (CLOSE + high-punch). See BurstState + _service_burst_end.
var _burst := BurstState.new()
```

- [ ] **Step 4: Add the chain-or-end decision helper**

In `scripts/player.gd`, add these two methods (place them right before `_dispatch_normal_move`):

```gdscript
## True only while a fresh burst hit could still connect: a valid, standing, CLOSE target.
func _burst_close_to_target() -> bool:
	return target != null and is_instance_valid(target) and target.mode == Mode.NORMAL \
		and _current_range() == MoveTable.Rng.CLOSE

## Called once a burst hit's move has ended (not is_attacking()). Either chains the next hit
## (buffered re-press, under the cap, still close) or ENDS the burst — popping whoever the last
## hit landed on. Returns true when it consumed the frame (always, while a burst is active).
func _service_burst_end(close: bool) -> bool:
	var victim: Fighter = null
	if not _hit_by_current_move.is_empty():
		var v: Variant = _hit_by_current_move.back()
		if v is Fighter:
			victim = v
	var victim_ok := victim != null and is_instance_valid(victim) and not victim.is_dead()
	if close and victim_ok and _burst.can_chain():
		_burst.advance()
		start_move(_HEADBUTT_BURST)
		return true
	if victim_ok:
		victim.pop_from_headbutt(self)
	_burst.reset()
	return true
```

- [ ] **Step 5: Start the burst on the first close high-punch**

In `scripts/player.gd`, in `_dispatch_normal_move`, REPLACE this block:

```gdscript
	if seq != null:
		start_move(seq)
	elif mode == Mode.RUNNING:
		mode = Mode.NORMAL   # an attack press with no running variant still ends the run
```

with:

```gdscript
	if seq != null:
		if seq.id == "headbutt_burst" and not _burst.is_active():
			_burst.start()   # first hit of a fresh burst chain
		start_move(seq)
	elif mode == Mode.RUNNING:
		mode = Mode.NORMAL   # an attack press with no running variant still ends the run
```

- [ ] **Step 6: Buffer continues + service the chain in `_physics_process`**

In `scripts/player.gd`, in `_physics_process`, find this line near the top (right after the
`feed_input(...)` call):

```gdscript
	feed_input(get_input_direction(), _buttons_held_mask(), facing())
```

Immediately AFTER it, add:

```gdscript
	# Headbutt burst: a re-press during a hit buffers the next; a fresh reaction on US ends it.
	if _burst.is_active():
		if not Fighter.input_allowed(mode) or _react_timer > 0.0:
			_burst.reset()                                   # we got hit/knocked -> burst broken
		elif _pressed(_action_prefix() + "high_punch"):
			_burst.note_continue()
```

Then find the normal-dispatch block:

```gdscript
	if Fighter.input_allowed(mode) and not is_attacking():
		if scan_specials():
			super(delta)
			return
		_dispatch_normal_move()
	super(delta)
```

and REPLACE it with (adds the chain-service before specials/dispatch):

```gdscript
	if Fighter.input_allowed(mode) and not is_attacking() and _react_timer <= 0.0:
		if _burst.is_active():
			if _service_burst_end(_burst_close_to_target()):
				super(delta)
				return
		if scan_specials():
			super(delta)
			return
		_dispatch_normal_move()
	super(delta)
```

- [ ] **Step 7: Reimport and run the burst test**

Run:
```bash
godot --headless --path . --import
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gtest=res://test/unit/test_player_burst.gd -gexit
```
Expected: PASS (4 tests).

- [ ] **Step 8: Commit**

```bash
git add scripts/player.gd test/unit/test_player_burst.gd
git commit -m "Player: wire headbutt burst (start/buffer/chain-or-end + ender pop)"
```

---

### Task 9: Full-suite verification

**Files:** none (verification only)

- [ ] **Step 1: Reimport and run the entire suite**

Run:
```bash
godot --headless --path . --import
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit
```
Expected: `All tests passed!` with the total count increased by the new tests (BurstState 6, move_sequence 3, damage +4, fighter_burst_pop 4, player_burst 4, plus the updated reaction/move_table assertions). No failures.

- [ ] **Step 2: If anything fails, fix it before proceeding**

Re-run the specific failing file with `-gtest=res://test/unit/<file>.gd` and resolve. Do not
proceed with a red suite.

- [ ] **Step 3: Commit (only if Step 2 required changes)**

```bash
git add -A
git commit -m "Headbutt burst: fix follow-ups from full-suite run"
```

---

## Manual playtest checklist (after the suite is green)

Not automated — verify in the running game (`/run` or the project's launch skill):

- [ ] Close + high-punch, single press → one headbutt, victim pops at its end.
- [ ] Close + high-punch mashed → up to 4 headbutts in a row; only the final one pops.
- [ ] Stop mashing at 2–3 → the last delivered headbutt pops (burst ends).
- [ ] Close + low-punch → one slower, stronger headbutt that pops; mashing it does NOT chain.
- [ ] Far high-punch still does `slap`; close + DOWN + high-punch still does `uppercut`.
- [ ] Tuning notes (adjust in `build_doink_sequences.gd` and re-run the builder): burst hit speed
      (ticks/frame), single headbutt `damage_override`, DIZZY knockback if the victim drifts out
      of CLOSE mid-burst.
```
