# Jump / Vertical-Axis + Ground Aerials — Design Spec

**Date:** 2026-06-06
**Slice:** Height-axis physics subsystem + two ground-launched aerials (flying kick, flying clothesline).
**Fidelity policy:** Arcade is the source of truth. Constants below are derived directly from the
TMS34010 source (`/home/pablin/Games/wwf-wrestlemania`) with `file:line` citations.

---

## 1. Goal & Scope

Activate a third dimension — **height off the mat** — that the codebase was stubbed to eventually
hold (`Fighter.Mode.INAIR` declared but unused; `Box3` already carries a Y/height axis always passed
`0`). On top of it, ship the two ground-launched aerials that prove the subsystem out:

- **Flying kick** — homing jump kick (HIGH_KICK at range).
- **Flying clothesline** — forward-launched body check (HIGH_PUNCH).

### Non-goals (explicit)

- No free "press a button to jump" — the arcade has none (no standalone jump, no variable height,
  no mid-air steering). Vertical motion is **always launched by a move**.
- No turnbuckle / top-rope (its own larger slice — needs ring-corner detection, climb state, camera
  scroll).
- No Y-sort / depth-sort overhaul (pre-existing latent issue; height is purely visual and does not
  change depth sorting).
- The flying kick's **close (<60px) super-kick variant** (`#skick_special`) is out of scope — at
  close range the existing behavior is retained; only the ≥60px airborne branch is built here.

---

## 2. The Height-Axis Subsystem

A direct port of the arcade per-frame integrator `wrestler_veladd` (`WRESTLE2.ASM:2282`).

### New `Fighter` state
- `_height: float` — altitude in px above the mat (`0` = grounded). The render-up axis.
- `_vy: float` — vertical velocity, px/s (`+` = up).

### Per-frame integration (in `_physics_process`)
Runs whenever airborne (`_height > 0 or _vy != 0`, i.e. `Mode.INAIR`):

```
_vy -= GRAVITY * delta          # gravity pulls down  (WRESTLE2.ASM:2359-2376)
_vy  = max(_vy, MAX_FALL)        # terminal velocity clamp (MAX_YVEL)
_height += _vy * delta
if _height <= 0:                 # landing (WRESTLE2.ASM:2300-2325)
    _height = 0; _vy = 0
    <fire move's landing transition>
```

Mid-air **input is locked** (faithful — arcade allows no mid-air directional change of Y-velocity;
only the launching move's scripted X/Z velocity applies). `input_allowed()` already excludes
`INAIR`, so no change needed there.

### Constants (in `ArcadeUnits`, derived from arcade hex)

The arcade stores velocities as 16.16 fixed-point **px/tick** and integrates once per tick
(`TICKS_PER_SECOND = 53`). The existing `vel_to_px_per_sec(hex) = (hex / 65536) * 53` already bakes
the tick rate; gravity (an acceleration, px/tick²) scales by `53²`.

| Name | Arcade | Source | Derived |
|------|--------|--------|---------|
| `GRAVITY` | `0x08000`/tick² (0.5 px/tick²) | `GAME.EQU:436` | `0.5 * 53² ≈ 1404.5 px/s²` |
| `MAX_FALL` | `MAX_YVEL = -0x1000000` | `WRESTLE2.ASM:2280` | `-(0x1000000/65536)*53 ≈ -13568 px/s` |
| `FLYKICK_YVEL` | `0x90000` (9.0 px/tick) | `DNKSEQ2.ASM:902` | `≈ 477 px/s` up |
| `CLINE_YVEL` | `0x64000` (6.25 px/tick) | `DNKSEQ2.ASM:2401` | `≈ 331 px/s` up |
| `CLINE_XVEL` | `0x5c000` (5.75 px/tick) | `DNKSEQ2.ASM:2402` | `≈ 305 px/s` forward |

Exact numbers are pinned by the conversion helpers; the table shows the intended magnitudes.
Integration uses real `delta` (Godot 60 Hz), matching the established `ArcadeUnits` pattern.

---

## 3. Launch Model — New Sequence Commands

Aerials do not author their arc frame-by-frame; they **set a launch velocity** and let §2 fly them.
Two new `SequenceFrame.Command` values + handlers in `sequence_player.gd` / `fighter.gd`:

- **`SET_LAUNCH`** — sets `_vy` (and optional face-relative `_vx`) on that frame, enters `INAIR`.
  The arcade `ANI_SET_YVEL` / `ANI_SET_XVEL,…,AM_FACE_REL` (clothesline, `DNKSEQ2.ASM:2401-2402`).
- **`LEAP_AT_OPP`** — the homing variant (`ANI_LEAPATOPP`, macro `MACROS.H` /
  `ANIM.EQU:156`). Computes the X/Z velocity needed to arrive at the current target (`+` offset) in
  `N` ticks, **clamped** to per-axis caps (`hiX`, `hiZ`), and sets `_vy = hiYvel`. Parameters mirror
  the macro: `(ticks, range_max, hiX, hiZ, hiYvel, target, Xoff, Yoff, Zoff)`. This is what makes the
  flying kick *track* the opponent.

Landing is detected by §2 (the `ANI_WAITHITGND` equivalent), **not authored**. The frame after
touchdown runs the move's recovery tail.

---

## 4. The Two Aerials (source-accurate)

### 4.1 Flying kick — HIGH_KICK, homing

**Arcade:** `#super_kick` handler (`DNK.ASM:1848`). Dispatch by target distance:
- `NORMAL`, target **DX≥60 and DZ≥60** → jumping kick (`#skick_kick` → `dnk_2_spin_kick_anim`).
- `NORMAL`, **<60** → close super (`#skick_special`) — *out of scope; current behavior retained.*

**Sequence** `dnk_2_spin_kick_anim` (`DNKSEQ2.ASM:888`):
- `ANI_STARTATTACK,AT_SPINKIK,15` (attack arms at frame 15).
- `LEAPATOPP 11,999,50,50,90000h,TGT_HEAD,79,87,-30` (`:902`) — 11-tick homing leap, Yvel `0x90000`,
  X/Z caps 50, targets head.
- `ANI_ATTACK_ON, AMODE_SPINKICK,46,76,42,42` (`:909`) — box offset (46,76) size (42×42).
- **On hit** (`:914-916`): `ANI_SLIDE_BACK 30h,-70000h` then `ANI_SET_YVEL,50000h` — small recoil hop.
- **On whiff** (`:918-921`): `ANI_ZEROVELS`, `ANI_SET_YVEL,30000h`, `ANI_SET_XVEL,30000h,AM_HIT_REL`
  — recovery hop, then lands.

**Godot mapping:** refines the existing `NORMAL + HIGH_KICK → spin_kick` MoveTable slot. A pure gate
helper (same pattern as `HairPickup.gate`) returns the airborne flying-kick sequence when a valid
target sits at **DX≥60 AND DZ≥60** (lower bound only; arcade `range_max=999` ≈ unbounded above);
otherwise the current (grounded) behavior stands. Authored via a new `_aerial` recipe in
`build_doink_sequences.gd` using `LEAP_AT_OPP`.

### 4.2 Flying clothesline — HIGH_PUNCH, forward launch

**Arcade:** `#super_punch` handler (`DNK.ASM:2073`; button bit-flag `4` = high punch,
`DNK.ASM:2045`). `#punch_clothesline` fires from `NORMAL, RUNNING, INAIR, ATTACHED, BOUNCING,
ONTURNBKL, …` (`DNK.ASM:2090-2101`); `ONGROUND<176` → belly flop, else elbow drop.

**Sequence** `dnk_fly_cline_anim` (`DNKSEQ2.ASM:2387`):
- `ANI_SET_YVEL,64000h`, `ANI_SET_XVEL,5c000h,AM_FACE_REL` (`:2401-2402`) — fixed upward + forward.
- `ANI_ATTACK_ON, AMODE_CLINE,25,6,23,37` (`:2405`).
- `ANI_WAITHITGND` (`:2413`); **whiff** → `MODE_ONGROUND` slide + getup (`:2427`).

**Godot mapping:** `RUNNING + HIGH_PUNCH → flying_clothesline` (the reserved slot, corrected from low
to high punch). Uses `SET_LAUNCH` (Yvel + forward Xvel). New `.tres` via `_aerial` recipe.

### ⚠️ Fidelity deltas to confirm at spec review

Both correct existing/assumed mappings — calling out because they change current combat:
1. **Clothesline is HIGH_PUNCH, not low punch.** The MoveTable comment reserving *low* running-punch
   was a misattribution. To match source: HIGH_PUNCH. **Decision:** implement on `RUNNING+HIGH_PUNCH`.
   The arcade ALSO fires it from `NORMAL` high-punch (today that slot is `slap`). Broadening to
   NORMAL would replace the standing slap — **deferred/flagged**, not done in this slice unless you
   want full fidelity now.
2. **Flying kick is the existing `spin_kick` (HIGH_KICK) made airborne + range-gated (≥60).** The
   `<60` close-super variant is retained-as-is, not built here.

---

## 5. Hit Detection in the Air

`Box3` already has the Y axis (`box3.gd:3` — "X = position.x, Y = height off ground, Z = depth"). The
work is **plumbing real `_height`** through (today hard-coded `0.0`):

- `attack_resolver` passes `attacker._height` / `victim._height` into `boxes_overlap`
  (`attack_resolver.gd:54-55`).
- New `INAIR` case in `hitbox.gd:hurt_box_for_mode` — an airborne torso volume.
- **On connect:** target takes the aerial's damage/reaction (knockdown).
- **On whiff:** attacker lands into a brief vulnerable recovery (faithful — spin-kick recovery hop;
  clothesline ground slide). Modeled via the move's landing tail (§3).
- **Co-op safety:** an aerial resolves only against the current target, so no friendly-fire surprises.

---

## 6. Rendering Altitude

- **Sprite lift:** offset the `AnimatedSprite2D` up the screen by `_height` (added on top of its baked
  `-50` offset). Applied in the existing `_refresh_flip()` / render-offset path.
- **Depth/draw order unchanged:** height is purely visual; sorting still keys off `global_position.y`
  (depth). No y-sort work in this slice.
- **Ground shadow (one new visual node):** a shadow at `global_position` that stays on the mat
  (optionally shrinks/fades slightly with `_height`) so the leap reads clearly. Approved in design.

---

## 7. Testing

Following `test_fighter_movement.gd` / `test_hitbox.gd` patterns (stub fighters, drive
`_physics_process`, assert state):

- **Physics:** launch → apex → land; gravity integration matches derived constant; landing clamps
  `_height`/`_vy` to 0; `MAX_FALL` terminal clamp.
- **Homing math:** `LEAP_AT_OPP` arrives at target (+offset) in N ticks; X/Z caps respected.
- **Dispatch:** `RUNNING+HIGH_PUNCH` → clothesline; `NORMAL+HIGH_KICK` at DX/DZ≥60 → flying kick,
  else current grounded behavior.
- **Air hit detection:** airborne attacker connects at non-zero height; whiff → recovery; target
  knockdown reaction.
- **Mode transitions:** `NORMAL → INAIR → NORMAL/recovery`.

---

## 8. Architecture Summary (units & boundaries)

| Unit | Responsibility | Depends on |
|------|----------------|-----------|
| `ArcadeUnits` (extend) | Gravity/launch constants, hex→px/s derivations | — |
| `Fighter` (extend) | `_height`/`_vy` state, gravity integration, landing, INAIR branch | ArcadeUnits |
| `SequenceFrame` / `sequence_player` (extend) | `SET_LAUNCH`, `LEAP_AT_OPP` commands | Fighter |
| Flying-kick gate helper (new) | ≥60px leap-range gate → swap spin_kick for airborne variant | Fighter, Targeting |
| `hitbox` / `attack_resolver` (extend) | INAIR hurt box; pass real `_height` to overlap | Box3 |
| Shadow node + render lift (new) | Visual altitude (sprite up by `_height`, shadow on mat) | Fighter |
| `build_doink_sequences` `_aerial` recipe (new) | Author flying-kick / clothesline `.tres` | — |

Each unit is independently testable; the height subsystem is the shared core, and the two moves are
thin authored data + a dispatch gate on top.
