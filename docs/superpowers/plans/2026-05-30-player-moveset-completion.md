# Player Moveset Completion (Ground Moves) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish Doink's ground move logic, matching the arcade dispatch — a per-opponent-mode (X,Z)-AND proximity model, the arcade button×direction×range×opponent-mode action table, and the verbatim secret-move motion patterns — and wire the remaining ground moves.

**Architecture:** Extend the existing pure-table + thin-`Player` dispatch. New pure `Proximity` helper; `MoveTable` gains a `GROUNDED` range; the move/motion tables are rebuilt from the arcade data (DNK.ASM). Each move is an isolated data unit (sequence + table entry + damage/reaction). No refactor of working dispatch.

**Tech Stack:** Godot 4.6 + GDScript, GUT tests. Build tools under `tools/` author the `.tres` data.

**Spec:** `docs/superpowers/specs/2026-05-30-player-moveset-completion-design.md`
**Arcade data (verbatim, extracted):** see "Arcade reference data" at the bottom — DNK.ASM action tables + secret-move patterns. Bit layout matches ours 1:1 (no conversion).

**Run all tests:**
```bash
GODOT=/home/pablin/.local/bin/godot
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit
```
**New `class_name` / rebuilt `.tres`:** after editing a build tool, regenerate then rebuild the class cache:
```bash
"$GODOT" --headless --path . -s tools/<tool>.gd      # regenerate the .tres
"$GODOT" --headless --path . --import                 # refresh class cache + .uid
```

---

## File Structure

- Create `scripts/combat/proximity.gd` (`class_name Proximity`) — pure (X,Z)-AND range test + arcade threshold constants.
- Create `test/unit/test_proximity.gd`.
- Modify `scripts/combat/move_table.gd` — add `Rng.GROUNDED`.
- Modify `scripts/player.gd` — `_current_range()` uses `Proximity` + GROUNDED.
- Modify `scripts/combat/amode.gd` — new attack modes + families + `reaction_for`.
- Modify `scripts/combat/damage_table.gd` — base damage for new modes.
- Modify `scripts/combat/reaction.gd` — families for new modes (reuse existing anims).
- Modify `tools/build_doink_sequences.gd` — author new strike + secret-move sequences.
- Modify `tools/build_doink_movetable.gd` — rebuild the full arcade action table.
- Modify `tools/build_doink_motiontable.gd` — exact arcade secret-move patterns + new specials.
- Modify/extend `test/unit/test_move_table.gd`, `test/unit/test_player_special_dispatch.gd`, `test/unit/test_motion_patterns.gd`.

Out of scope (deferred): aerial/running-flying moves (flying kick, flying clothesline, belly flop), turnbuckle moves, the arcade's PUNCH+KICK run-start (we keep the dedicated run key), Hair Pickup beyond its own gated task (Task 8).

---

## Task 1: `Proximity` helper

**Files:** Create `scripts/combat/proximity.gd`, `test/unit/test_proximity.gd`

- [ ] **Step 1: Write the failing test**

`test/unit/test_proximity.gd`:
```gdscript
extends "res://addons/gut/test.gd"

func test_within_when_both_axes_inside():
	# |dx| <= DX AND |dz| <= DZ  -> close
	assert_true(Proximity.is_within(Vector2(100, 400), Vector2(140, 430), 50, 45))

func test_not_within_when_x_exceeds():
	assert_false(Proximity.is_within(Vector2(100, 400), Vector2(160, 400), 50, 45))

func test_not_within_when_z_exceeds():
	assert_false(Proximity.is_within(Vector2(100, 400), Vector2(100, 460), 50, 45))

func test_boundary_is_inclusive():
	assert_true(Proximity.is_within(Vector2(0, 0), Vector2(50, 45), 50, 45))

func test_thresholds_are_the_arcade_values():
	assert_eq(Proximity.CLOSE_DX, 50.0)
	assert_eq(Proximity.CLOSE_DZ, 45.0)
	assert_eq(Proximity.GROUNDED_DX, 120.0)
	assert_eq(Proximity.GROUNDED_DZ, 120.0)
```

- [ ] **Step 2: Run it (red)**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_proximity.gd -gexit`
Expected: FAIL — `Proximity` not found.

- [ ] **Step 3: Implement**

`scripts/combat/proximity.gd`:
```gdscript
class_name Proximity
## Arcade proximity test (JJXM macro, DNK.ASM): the opponent is "close" when
## |Δx| <= DX AND |Δz| <= DZ (X = horizontal, Z = depth = screen Y). Thresholds are
## per attack/opponent-mode in the action table; these constants are the common ones.

# Standing opponent (PUNCH NORMAL): DNK.ASM punch JJXM 50,45.
const CLOSE_DX := 50.0
const CLOSE_DZ := 45.0
# Grounded opponent (PUNCH/KICK ONGROUND): DNK.ASM 120,120.
const GROUNDED_DX := 120.0
const GROUNDED_DZ := 120.0

## True when `b` is within (dx, dz) of `a` on both axes (x = .x, z = .y), inclusive.
static func is_within(a: Vector2, b: Vector2, dx: float, dz: float) -> bool:
	return absf(b.x - a.x) <= dx and absf(b.y - a.y) <= dz
```

- [ ] **Step 4: Run it (green)** — same command. Expected: PASS.

- [ ] **Step 5: Commit**
```bash
"$GODOT" --headless --path . --import
git add scripts/combat/proximity.gd scripts/combat/proximity.gd.uid test/unit/test_proximity.gd test/unit/test_proximity.gd.uid
git commit -m "feat(combat): Proximity helper (arcade (X,Z)-AND range test)"
```

---

## Task 2: `Rng.GROUNDED` + arcade `_current_range`

**Files:** Modify `scripts/combat/move_table.gd`, `scripts/player.gd`; Test `test/unit/test_player_special_dispatch.gd` (or a new `test/unit/test_player_range.gd`)

- [ ] **Step 1: Add the GROUNDED range value**

In `scripts/combat/move_table.gd`, change the `Rng` enum:
```gdscript
enum Rng { NORMAL, CLOSE, RUNNING, GROUNDED }
```

- [ ] **Step 2: Write the failing test**

Create `test/unit/test_player_range.gd`:
```gdscript
extends "res://addons/gut/test.gd"

func _player_at(x: float, y: float) -> Player:
	var p := Player.new()
	add_child_autofree(p)
	p.global_position = Vector2(x, y)
	p.side = Fighter.Side.PLAYER
	p.separation_radii = Vector2.ZERO
	return p

func _enemy_at(x: float, y: float, mode: int) -> Fighter:
	var f := Fighter.new()
	add_child_autofree(f)
	f.global_position = Vector2(x, y)
	f.side = Fighter.Side.ENEMY
	f.separation_radii = Vector2.ZERO
	f.mode = mode
	return f

func test_far_standing_opponent_is_normal_range():
	var p := _player_at(100, 400)
	var e := _enemy_at(300, 400, Fighter.Mode.NORMAL)
	p.target = e
	assert_eq(p._current_range(), MoveTable.Rng.NORMAL)

func test_close_standing_opponent_is_close_range():
	var p := _player_at(100, 400)
	var e := _enemy_at(130, 410, Fighter.Mode.NORMAL)  # dx30<=50, dz10<=45
	p.target = e
	assert_eq(p._current_range(), MoveTable.Rng.CLOSE)

func test_grounded_opponent_in_range_is_grounded():
	var p := _player_at(100, 400)
	var e := _enemy_at(200, 400, Fighter.Mode.ONGROUND)  # dx100<=120
	p.target = e
	assert_eq(p._current_range(), MoveTable.Rng.GROUNDED)

func test_grounded_opponent_far_is_normal():
	var p := _player_at(100, 400)
	var e := _enemy_at(300, 400, Fighter.Mode.ONGROUND)  # dx200>120
	p.target = e
	assert_eq(p._current_range(), MoveTable.Rng.NORMAL)

func test_running_is_running_range():
	var p := _player_at(100, 400)
	var e := _enemy_at(130, 400, Fighter.Mode.NORMAL)
	p.target = e
	p.mode = Fighter.Mode.RUNNING
	assert_eq(p._current_range(), MoveTable.Rng.RUNNING)
```

- [ ] **Step 3: Run it (red)**

Run: `"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_player_range.gd -gexit` (after `--import`).
Expected: FAIL — current `_current_range` uses `distance_to <= _CLOSE_GATE`, so the grounded/(X,Z) cases are wrong.

- [ ] **Step 4: Rewrite `_current_range`**

In `scripts/player.gd`, replace the whole `_current_range` function:
```gdscript
func _current_range() -> int:
	if mode == Mode.RUNNING:
		return MoveTable.Rng.RUNNING
	if target == null or not is_instance_valid(target):
		return MoveTable.Rng.NORMAL
	# A downed opponent within the grounded reach uses the grounded moves (stomp / elbow drop).
	if target.mode == Mode.ONGROUND:
		if Proximity.is_within(global_position, target.global_position, Proximity.GROUNDED_DX, Proximity.GROUNDED_DZ):
			return MoveTable.Rng.GROUNDED
		return MoveTable.Rng.NORMAL
	# Standing opponent: close vs far by the arcade (X,Z)-AND test.
	if Proximity.is_within(global_position, target.global_position, Proximity.CLOSE_DX, Proximity.CLOSE_DZ):
		return MoveTable.Rng.CLOSE
	return MoveTable.Rng.NORMAL
```
Then delete the now-unused `const _CLOSE_GATE := 50.0` line.

- [ ] **Step 5: Run it (green)** — same command. Expected: PASS. Then run the full suite; if any prior test relied on the old `_CLOSE_GATE` distance behavior (e.g. in `test_player_special_dispatch`), update its fighter positions so the intended range still resolves (close cases: keep dx≤50 AND dz≤45).

- [ ] **Step 6: Commit**
```bash
git add scripts/combat/move_table.gd scripts/player.gd test/unit/test_player_range.gd
git commit -m "feat(combat): GROUNDED range + arcade (X,Z)-AND proximity in _current_range"
```

---

## Task 3: New attack modes (damage + reaction)

The new ground moves need attack modes with damage + a reaction family. Reuse existing victim
reaction anims (HEAD_HIT/BODY_HIT/STAGGER/KNOCKDOWN/ONGROUND) — no new victim art.

**Files:** Modify `scripts/combat/amode.gd`, `scripts/combat/damage_table.gd`; Test `test/unit/test_amode.gd`, `test/unit/test_damage.gd`

- [ ] **Step 1: Write the failing test**

Append to `test/unit/test_amode.gd`:
```gdscript
func test_new_ground_modes_have_reaction_families():
	assert_eq(AMode.reaction_for(AMode.SLAP), AMode.Family.HEAD_HIT)
	assert_eq(AMode.reaction_for(AMode.SPINKICK), AMode.Family.STAGGER)
	assert_eq(AMode.reaction_for(AMode.EARSLAP), AMode.Family.HEAD_HIT)
	assert_eq(AMode.reaction_for(AMode.HAMMER), AMode.Family.KNOCKDOWN)
	assert_eq(AMode.reaction_for(AMode.BOXGLOVE), AMode.Family.KNOCKDOWN)
```
Append to `test/unit/test_damage.gd`:
```gdscript
func test_new_ground_modes_have_base_damage():
	assert_gt(DamageTable.base(AMode.SLAP), 0)
	assert_gt(DamageTable.base(AMode.SPINKICK), 0)
	assert_gt(DamageTable.base(AMode.EARSLAP), 0)
	assert_gt(DamageTable.base(AMode.HAMMER), 0)
	assert_gt(DamageTable.base(AMode.BOXGLOVE), 0)
```

- [ ] **Step 2: Run it (red)** — full suite or the two files. Expected: FAIL (unknown identifiers).

- [ ] **Step 3: Implement**

In `scripts/combat/amode.gd`, extend the enum (append; keep existing order so saved `.tres` indices don't shift):
```gdscript
enum { PUNCH, HDBUTT, KICK, KNEE, UPRCUT, BIGBOOT, STOMP, LBDROP, SLAP, SPINKICK, EARSLAP, HAMMER, BOXGLOVE }
```
Add to the `_HIT_TABLE` dictionary (Doink ground reactions; tune families in playtest):
```gdscript
	SLAP: Family.HEAD_HIT,
	SPINKICK: Family.STAGGER,
	EARSLAP: Family.HEAD_HIT,
	HAMMER: Family.KNOCKDOWN,
	BOXGLOVE: Family.KNOCKDOWN,
```
In `scripts/combat/damage_table.gd`, add to `_BASE` (seeded from DAMAGE.EQU scale; tune in playtest):
```gdscript
	AMode.SLAP: 10,
	AMode.SPINKICK: 18,
	AMode.EARSLAP: 10,
	AMode.HAMMER: 22,
	AMode.BOXGLOVE: 25,
```

- [ ] **Step 4: Run it (green)** — Expected: PASS (both files + full suite).

- [ ] **Step 5: Commit**
```bash
git add scripts/combat/amode.gd scripts/combat/damage_table.gd test/unit/test_amode.gd test/unit/test_damage.gd
git commit -m "feat(combat): attack modes for slap/spin-kick/ear-slap/hammer/boxing-glove"
```

---

## Task 4: Author new strike sequences

Add five normal-strike sequences via the existing `_strike` recipe. Anim folders (front-facing;
the `_strike` helper walks the whole clip and `_sf.get_frame_count` gives the length):
knee→`close_kick_front`, stomp→`stomp_front_legdrop`, elbow_drop→`elbow_drop_front`,
slap→`slap_front`, spin_kick→`power_kick_front`.

**Files:** Modify `tools/build_doink_sequences.gd`; Test `test/unit/test_scenes.gd` or a new loader test

- [ ] **Step 1: Add the builder lines**

In `tools/build_doink_sequences.gd`, inside `_init()` after the existing `_save(_strike(...))`
block, add (frame_count from the SpriteFrames; `contact` seeded mid-clip, tune in playtest):
```gdscript
	_save(_strike("knee",      "close_kick_front",     AMode.KNEE,     _sf.get_frame_count("close_kick_front"),     2, _ab(24, 70, 0, 55, 40, 10)))
	_save(_strike("stomp",     "stomp_front_legdrop",  AMode.STOMP,    _sf.get_frame_count("stomp_front_legdrop"),  2, _ab(20, 110, 0, 60, 30, 10)))
	_save(_strike("elbow_drop","elbow_drop_front",     AMode.LBDROP,   _sf.get_frame_count("elbow_drop_front"),     2, _ab(20, 100, 0, 60, 36, 10)))
	_save(_strike("slap",      "slap_front",           AMode.SLAP,     _sf.get_frame_count("slap_front"),           2, _ab(22, 84, 0, 55, 12, 10), false, 2))
	_save(_strike("spin_kick", "power_kick_front",     AMode.SPINKICK, _sf.get_frame_count("power_kick_front"),     3, _ab(26, 60, 0, 80, 30, 10)))
```

- [ ] **Step 2: Regenerate + verify**

Run:
```bash
"$GODOT" --headless --path . -s tools/build_doink_sequences.gd
"$GODOT" --headless --path . --import
ls assets/sequences/doink/   # knee.tres, stomp.tres, elbow_drop.tres, slap.tres, spin_kick.tres present
```

- [ ] **Step 3: Write a loader test**

Append to `test/unit/test_scenes.gd` (or create `test/unit/test_sequences_present.gd`):
```gdscript
func test_new_doink_strike_sequences_load():
	for id in ["knee", "stomp", "elbow_drop", "slap", "spin_kick"]:
		var seq: MoveSequence = load("res://assets/sequences/doink/%s.tres" % id)
		assert_not_null(seq, "%s.tres loads" % id)
		assert_eq(seq.id, id)
		assert_gt(seq.frames.size(), 0, "%s has frames" % id)
```

- [ ] **Step 4: Run it (green)** — `-gtest=...test_scenes.gd` (after import). Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add tools/build_doink_sequences.gd assets/sequences/doink/knee.tres assets/sequences/doink/stomp.tres assets/sequences/doink/elbow_drop.tres assets/sequences/doink/slap.tres assets/sequences/doink/spin_kick.tres test/unit/test_scenes.gd
git add assets/sequences/doink/*.uid 2>/dev/null || true
git commit -m "feat(doink): author knee/stomp/elbow-drop/slap/spin-kick sequences"
```

---

## Task 5: Rebuild the arcade MoveTable (button × dir × range × opp-mode)

Rebuild `doink.tres` so normals dispatch exactly like the arcade action table (see "Arcade
reference data"). Key changes from today: PUNCH stays (far=punch, close=headbutt, GROUNDED=elbow
drop); KICK far=kick, close=knee, GROUNDED=stomp, RUNNING=big boot; SPUNCH far=slap, close+DOWN=
uppercut, GROUNDED=elbow drop; SKICK far=spin kick, close=knee, GROUNDED=stomp, RUNNING=big boot.

**Files:** Modify `tools/build_doink_movetable.gd`; Test `test/unit/test_move_table.gd`

- [ ] **Step 1: Rewrite the builder body**

In `tools/build_doink_movetable.gd`, replace the move loads + `t.add(...)` block with:
```gdscript
	var S := func(id: String) -> MoveSequence: return load(SEQ + id + ".tres")
	var punch := S.call("punch"); var headbutt := S.call("headbutt")
	var kick := S.call("kick"); var knee := S.call("knee"); var stomp := S.call("stomp")
	var uppercut := S.call("uppercut"); var slap := S.call("slap")
	var spin_kick := S.call("spin_kick"); var elbow := S.call("elbow_drop")
	var big_boot := S.call("big_boot")
	var R := MoveTable.Rng; var D := MoveTable.Dir; var B := MoveTable.Btn

	# PUNCH (low punch): far punch, close head butt, grounded elbow drop.
	t.add(R.NORMAL,   D.NEUTRAL, B.LOW_PUNCH, punch)
	t.add(R.CLOSE,    D.NEUTRAL, B.LOW_PUNCH, headbutt)
	t.add(R.GROUNDED, D.NEUTRAL, B.LOW_PUNCH, elbow)

	# KICK (low kick): far kick, close knee, grounded stomp, running big boot.
	t.add(R.NORMAL,   D.NEUTRAL, B.LOW_KICK, kick)
	t.add(R.CLOSE,    D.NEUTRAL, B.LOW_KICK, knee)
	t.add(R.GROUNDED, D.NEUTRAL, B.LOW_KICK, stomp)
	t.add(R.RUNNING,  D.NEUTRAL, B.LOW_KICK, big_boot)

	# SPUNCH (high punch): far slap; close NEUTRAL = slap-special (use slap), close+DOWN = uppercut;
	# grounded elbow drop; running big boot.
	t.add(R.NORMAL,   D.NEUTRAL, B.HIGH_PUNCH, slap)
	t.add(R.CLOSE,    D.NEUTRAL, B.HIGH_PUNCH, slap)
	t.add(R.CLOSE,    D.DOWN,    B.HIGH_PUNCH, uppercut)
	t.add(R.GROUNDED, D.NEUTRAL, B.HIGH_PUNCH, elbow)
	t.add(R.RUNNING,  D.NEUTRAL, B.HIGH_PUNCH, big_boot)

	# SKICK (high kick): far spin kick, close knee, grounded stomp, running big boot.
	t.add(R.NORMAL,   D.NEUTRAL, B.HIGH_KICK, spin_kick)
	t.add(R.CLOSE,    D.NEUTRAL, B.HIGH_KICK, knee)
	t.add(R.GROUNDED, D.NEUTRAL, B.HIGH_KICK, stomp)
	t.add(R.RUNNING,  D.NEUTRAL, B.HIGH_KICK, big_boot)
```
(`MoveTable.lookup` already falls back dir-specific → NEUTRAL, so close+DOWN HIGH_PUNCH resolves to
uppercut while close NEUTRAL HIGH_PUNCH resolves to slap.)

- [ ] **Step 2: Regenerate**
```bash
"$GODOT" --headless --path . -s tools/build_doink_movetable.gd
"$GODOT" --headless --path . --import
```

- [ ] **Step 3: Write/extend dispatch tests**

Replace the body of `test/unit/test_move_table.gd` (keep the `extends` line) with:
```gdscript
extends "res://addons/gut/test.gd"

const T := preload("res://assets/movetables/doink.tres")

func _id(rng: int, dir: int, btn: int) -> String:
	var s: MoveSequence = T.lookup(rng, dir, btn)
	return s.id if s != null else ""

func test_punch_by_range():
	assert_eq(_id(MoveTable.Rng.NORMAL,   MoveTable.Dir.NEUTRAL, MoveTable.Btn.LOW_PUNCH), "punch")
	assert_eq(_id(MoveTable.Rng.CLOSE,    MoveTable.Dir.NEUTRAL, MoveTable.Btn.LOW_PUNCH), "headbutt")
	assert_eq(_id(MoveTable.Rng.GROUNDED, MoveTable.Dir.NEUTRAL, MoveTable.Btn.LOW_PUNCH), "elbow_drop")

func test_kick_by_range():
	assert_eq(_id(MoveTable.Rng.NORMAL,   MoveTable.Dir.NEUTRAL, MoveTable.Btn.LOW_KICK), "kick")
	assert_eq(_id(MoveTable.Rng.CLOSE,    MoveTable.Dir.NEUTRAL, MoveTable.Btn.LOW_KICK), "knee")
	assert_eq(_id(MoveTable.Rng.GROUNDED, MoveTable.Dir.NEUTRAL, MoveTable.Btn.LOW_KICK), "stomp")
	assert_eq(_id(MoveTable.Rng.RUNNING,  MoveTable.Dir.NEUTRAL, MoveTable.Btn.LOW_KICK), "big_boot")

func test_super_punch_far_slap_close_down_uppercut():
	assert_eq(_id(MoveTable.Rng.NORMAL, MoveTable.Dir.NEUTRAL, MoveTable.Btn.HIGH_PUNCH), "slap")
	assert_eq(_id(MoveTable.Rng.CLOSE,  MoveTable.Dir.NEUTRAL, MoveTable.Btn.HIGH_PUNCH), "slap")
	assert_eq(_id(MoveTable.Rng.CLOSE,  MoveTable.Dir.DOWN,    MoveTable.Btn.HIGH_PUNCH), "uppercut")

func test_super_kick_far_spin_close_knee():
	assert_eq(_id(MoveTable.Rng.NORMAL,   MoveTable.Dir.NEUTRAL, MoveTable.Btn.HIGH_KICK), "spin_kick")
	assert_eq(_id(MoveTable.Rng.CLOSE,    MoveTable.Dir.NEUTRAL, MoveTable.Btn.HIGH_KICK), "knee")
	assert_eq(_id(MoveTable.Rng.GROUNDED, MoveTable.Dir.NEUTRAL, MoveTable.Btn.HIGH_KICK), "stomp")
```

- [ ] **Step 4: Run it (green)** — `-gtest=...test_move_table.gd`. Then the full suite — `test_player_special_dispatch`/`test_player` may assert old mappings (e.g. HIGH_PUNCH→uppercut at NORMAL, HIGH_KICK→big_boot at NORMAL). Update those expectations to the arcade mapping above (uppercut is now CLOSE+DOWN HIGH_PUNCH; big_boot is RUNNING only). Note each updated test in the commit.

- [ ] **Step 5: Commit**
```bash
git add tools/build_doink_movetable.gd assets/movetables/doink.tres test/unit/test_move_table.gd
git add test/unit/test_player*.gd 2>/dev/null || true
git commit -m "feat(doink): rebuild MoveTable to the arcade action table (button×dir×range×opp-mode)"
```

---

## Task 6: Secret moves — exact arcade patterns + new specials

Author the three new secret-move sequences (ear_slap→`clapper`, hammer→`happy_hammer`,
boxing_glove→`boxing_glove_smash_front`) and rebuild the MotionTable with the verbatim arcade
patterns, including the existing grabs realigned. The matcher already handles 16-entry, masked,
windowed, multi-step patterns (incl. boxing glove's 7 entries) — this is pure data.

**Files:** Modify `tools/build_doink_sequences.gd`, `tools/build_doink_motiontable.gd`; Test `test/unit/test_motion_patterns.gd`

- [ ] **Step 1: Author the three secret-move strike sequences**

In `tools/build_doink_sequences.gd` `_init()`, after the Task-4 strikes add:
```gdscript
	_save(_strike("ear_slap",     "clapper",                 AMode.EARSLAP,  _sf.get_frame_count("clapper"),                 2, _ab(20, 84, 0, 55, 14, 10), false, 2))
	_save(_strike("hammer",       "happy_hammer",            AMode.HAMMER,   _sf.get_frame_count("happy_hammer"),            3, _ab(24, 96, 0, 60, 40, 10)))
	_save(_strike("boxing_glove", "boxing_glove_smash_front",AMode.BOXGLOVE, _sf.get_frame_count("boxing_glove_smash_front"),3, _ab(28, 80, 0, 80, 30, 10)))
```
Regenerate: `"$GODOT" --headless --path . -s tools/build_doink_sequences.gd && "$GODOT" --headless --path . --import`

- [ ] **Step 2: Write the failing pattern tests**

Replace `test/unit/test_motion_patterns.gd` body (keep `extends`) with tests driving the real table
through `MotionMatcher`. The helper feeds a buffer the way `Player.feed_input` does (newest pushed
last). `J = MotionBuffer`:
```gdscript
extends "res://addons/gut/test.gd"

const MT := preload("res://assets/motions/doink_motions.tres")
const J := MotionBuffer

func _buf(seq: Array) -> MotionBuffer:
	# seq is oldest-first list of input codes; we push with increasing ticks.
	var b := MotionBuffer.new()
	var tick := 1
	for code in seq:
		b.push(code, tick); tick += 1
	return b

func _fires(move_id: String, seq: Array) -> bool:
	var b := _buf(seq)
	var tick: int = b.newest_tick()
	for m in MT.moves():
		if m.move_id == move_id:
			return MotionMatcher.matches(m, b, tick)
	return false

func test_hammer_skick_toward_toward():
	# arcade: B_SKICK, J_TOWARD, J_TOWARD within 32 ticks
	assert_true(_fires("hammer", [J.J_TOWARD, J.J_TOWARD, J.B_SKICK | J.J_TOWARD]))

func test_neck_grab_spunch_toward_toward():
	assert_true(_fires("neck_grab", [J.J_TOWARD, J.J_TOWARD, J.B_SPUNCH | J.J_TOWARD]))

func test_boxing_glove_seven_punches():
	var seq := []
	for i in range(7): seq.append(J.B_PUNCH)
	assert_true(_fires("boxing_glove", seq))

func test_boxing_glove_six_punches_does_not_fire():
	var seq := []
	for i in range(6): seq.append(J.B_PUNCH)
	assert_false(_fires("boxing_glove", seq))
```

- [ ] **Step 3: Run it (red)** — Expected: FAIL (hammer/boxing_glove not in table yet).

- [ ] **Step 4: Rebuild the MotionTable with exact arcade patterns**

First READ the current `tools/build_doink_motiontable.gd` to see how it authors the grab registry
(`assets/motions/doink_motions.tres` — the initiators hip_toss / grab_fling / neck_grab) and follow
its structure. The head-hold follow-ups (piledriver, head_slam) are SEPARATE files under
`assets/motions/doink/` loaded by `Player._FOLLOWUP_MOTIONS` — do NOT touch them here. EXTEND the
grab registry: realign the three existing initiators to the verbatim patterns below and ADD the
three new specials (hammer, ear_slap, boxing_glove). Patterns are NEWEST-FIRST (`values[0]` =
trigger); `mask` = bits to IGNORE. Use `MotionBuffer` constants. Add these entries:
```gdscript
	var J := MotionBuffer
	# Ignore-everything-but-the-button mask for repeated-button moves:
	var ALL_DIR := J.J_UP | J.J_DOWN | J.J_AWAY | J.J_TOWARD | J.J_REAL_LR

	# neck_grab: B_SPUNCH, then TOWARD, TOWARD ; 32-tick window.
	_add(t, "neck_grab", [J.B_SPUNCH | J.J_TOWARD, J.J_TOWARD, J.J_TOWARD],
		[ALL_DIR, ~J.J_TOWARD & 0xFFFF, ~J.J_TOWARD & 0xFFFF], 32, S.call("neck_grab"))
	# hammer: B_SKICK, TOWARD, TOWARD ; 32-tick window.
	_add(t, "hammer", [J.B_SKICK | J.J_TOWARD, J.J_TOWARD, J.J_TOWARD],
		[ALL_DIR, ~J.J_TOWARD & 0xFFFF, ~J.J_TOWARD & 0xFFFF], 32, S.call("hammer"))
	# hip_toss: B_PUNCH + AWAY (ignore real L/R + up/down) ; 10-tick window.
	_add(t, "hip_toss", [J.B_PUNCH | J.J_AWAY], [J.J_REAL_LR | J.J_UP | J.J_DOWN], 10, S.call("hip_toss"))
	# grab_fling: B_SPUNCH + AWAY ; 10-tick window.
	_add(t, "grab_fling", [J.B_SPUNCH | J.J_AWAY], [J.J_REAL_LR | J.J_UP | J.J_DOWN], 10, S.call("grab_fling"))
	# ear_slap: B_PUNCH, TOWARD, DOWN_TOWARD(=DOWN|TOWARD), DOWN ; 50-tick window.
	_add(t, "ear_slap", [J.B_PUNCH | J.J_TOWARD, J.J_TOWARD, J.J_DOWN | J.J_TOWARD, J.J_DOWN],
		[ALL_DIR, ~J.J_TOWARD & 0xFFFF, ~(J.J_DOWN | J.J_TOWARD) & 0xFFFF, ~J.J_DOWN & 0xFFFF], 50, S.call("ear_slap"))
	# boxing_glove: B_PUNCH x7, stick ignored ; 60-tick window.
	var bg_v := []; var bg_m := []
	for i in range(7): bg_v.append(J.B_PUNCH); bg_m.append(ALL_DIR)
	_add(t, "boxing_glove", bg_v, bg_m, 60, S.call("boxing_glove"))
```
Add helpers at the top of the tool:
```gdscript
const SEQ := "res://assets/sequences/doink/"
var S := func(id: String) -> MoveSequence: return load(SEQ + id + ".tres")

func _add(t: MotionTable, id: String, values: Array, masks: Array, max_ticks: int, seq: MoveSequence) -> void:
	var m := MotionMove.new()
	m.move_id = id
	m.values = PackedInt32Array(values)
	m.masks = PackedInt32Array(masks)
	m.max_ticks = max_ticks
	t.add(m, seq)
```
(Verify each `values[0]` trigger carries a button bit so the matcher's "significant head" check
passes. The `S`/`_add` helpers may already exist in the tool in another form — reuse the tool's
existing sequence-load + add pattern rather than duplicating.)

Regenerate: `"$GODOT" --headless --path . -s tools/build_doink_motiontable.gd && "$GODOT" --headless --path . --import`

- [ ] **Step 5: Run it (green)** — `-gtest=...test_motion_patterns.gd`, then the full suite (update any existing motion-pattern test that asserted the old encodings). Expected: PASS.

- [ ] **Step 6: Commit**
```bash
git add tools/build_doink_sequences.gd tools/build_doink_motiontable.gd assets/sequences/doink/ear_slap.tres assets/sequences/doink/hammer.tres assets/sequences/doink/boxing_glove.tres assets/motions/doink_motions.tres test/unit/test_motion_patterns.gd
git add assets/**/*.uid 2>/dev/null || true
git commit -m "feat(doink): exact arcade secret-move patterns + ear-slap/hammer/boxing-glove"
```

---

## Task 7: Manual playtest + dispatch integration

**Files:** none (verification)

- [ ] **Step 1: Full suite green**

Run the full suite. Expected: all pass. Fix any remaining timing/expectation fallout from the
table rebuild (see Task 5 Step 4).

- [ ] **Step 2: Sandbox playtest**

Run: `"$GODOT" --path . scenes/Sandbox.tscn`. Confirm, against the arcade mapping:
- PUNCH: far punch, close head butt, downed foe → elbow drop.
- KICK: far kick, close knee, downed foe → stomp, running → big boot.
- HIGH-PUNCH (SPUNCH): far slap, close+down uppercut, downed foe → elbow drop.
- HIGH-KICK (SKICK): far spin kick, close knee, downed foe → stomp.
- Secret moves: hip toss (PUNCH+away), grab&fling (SPUNCH+away), neck grab (SPUNCH+toward,toward),
  hammer (SKICK+toward,toward), ear slap (PUNCH+toward,down-toward,down), boxing glove (PUNCH×7),
  joybuzzer (PUNCH held in head-hold).
- Tune seeded damage / hitbox windows / `contact` indices that read wrong.

- [ ] **Step 3: Commit any tuning**
```bash
git add -A && git commit -m "tune(doink): playtest pass on the completed ground moveset"
```

---

## Task 8: Hair Pickup (include/decide)

Hair Pickup is a grab on a downed/stunned foe (grapple-like), arcade `#spunch_lbowdrop` hair branch
with an x-alignment check. **Decision point:** at this task, decide with the user whether to wire it
now (as a grounded grab that lifts the foe into a hold) or defer with the grapple system. If wiring:
SPUNCH on a GROUNDED, x-aligned foe → a pickup sequence (anim TBD from the lifted/liftgrabbed
folders). If deferring, document it in the spec's out-of-scope and skip. No code until decided.

---

## Arcade reference data (verbatim, from DNK.ASM / GAME.EQU)

**Bit layout = ours 1:1.** J_UP=1, J_DOWN=2, J_AWAY=4, J_TOWARD=8, B_PUNCH=0x10, B_BLOCK=0x20,
B_SPUNCH=0x40, B_KICK=0x80, B_SKICK=0x100. J_DOWN_TOWARD = J_DOWN|J_TOWARD = 0xA.

**Normal action table (button → opp-mode → DX,DZ → close/far):**
- PUNCH(1): NORMAL 50,45 → close head butt / far punch; ONGROUND 120,120 → close elbow drop / far punch.
- SPUNCH(4): NORMAL 85,55 → close special(+DOWN uppercut, else butts) / far slap; ONGROUND 136,112 → elbow drop; HEADHELD → piledriver; RUNNING → flying clothesline (DEFER).
- KICK(8): NORMAL 50,92 → close knee / far kick; ONGROUND 120,120 → close stomp / far kick; RUNNING/BOUNCING → big boot.
- SKICK(16): NORMAL 60,60 → far spin kick / close knee; ONGROUND 144,160 → stomp; RUNNING → big boot; ONTURNBKL → TB spin kick (DEFER).
- PUNCH+KICK(9): start run (we keep the dedicated run key — out of scope).

**Secret moves (newest-first {value; ignore-mask}; window):**
- charge_buzz: B_PUNCH held ≥100 ticks → joybuzzer (already wired via ChargeTracker in head-hold).
- ear_slap: B_PUNCH ; J_TOWARD ; J_DOWN_TOWARD ; J_DOWN — 50 ticks.
- grab_fling: B_SPUNCH|J_AWAY (ignore real L/R + up/down) — 10 ticks.
- hammer: B_SKICK ; J_TOWARD ; J_TOWARD — 32 ticks.
- hip_toss: B_PUNCH|J_AWAY (ignore real L/R + up/down) — 10 ticks.
- neck_grab: B_SPUNCH ; J_TOWARD ; J_TOWARD — 32 ticks (close <70px → head_hold2, else head_hold).
- boxing_glove: B_PUNCH ×7 (stick ignored) — 60 ticks.

---

## Self-Review Notes

- **Spec coverage:** proximity model = Task 1-2; button-to-move arcade alignment = Task 5;
  GROUNDED bucket = Task 2/5; boxing-glove repeat (data) = Task 6; directional (SPUNCH+DOWN uppercut)
  = Task 5; motion specials (hammer/ear-slap) = Task 6; new strikes = Task 3-4; Hair Pickup = Task 8.
  Dropped `Dir.UP` (unused). Aerials/turnbuckle/PUNCH+KICK-run explicitly out of scope.
- **Type consistency:** `MoveTable.Rng.GROUNDED`, `Proximity.is_within/CLOSE_DX/CLOSE_DZ/GROUNDED_DX/
  GROUNDED_DZ`, `AMode.{SLAP,SPINKICK,EARSLAP,HAMMER,BOXGLOVE}`, `MotionMove.values/masks/max_ticks`,
  `MotionBuffer.J_*/B_*` used consistently across tasks.
- **Anim folders** are interpretive (knee=close_kick, spin_kick=power_kick, ear_slap=clapper) — the
  implementer confirms each clip visually in the Task 7 playtest and swaps the `anim_name` if wrong.
