# Directional Facing, Walk, Turn-Around & Getup — Design

Date: 2026-05-30
Branch context: follows the grapple-victim-channel work.
Arcade source of truth: `/home/pablin/Games/wwf-wrestlemania` (TMS34010 asm). Match the
arcade logic; don't approximate. See research:
`docs/superpowers/research/2026-05-27-arcade-movement-state-dizzy-getup.md`.

## Goal

Three locomotion/animation features, all hanging off one new concept — a **2D facing**
(horizontal L/R × depth FRONT/BACK):

1. **Diagonal (and vertical, and back) walk** — pick the right walk animation variant
   from movement + facing. Today `fighter.gd` only ever plays `walk_horisontal_front`,
   `idle_front`, and `run`.
2. **Turn-around pivot** — an actual animated turn (the `rotate` clip) when facing changes,
   both horizontally (flip side) and vertically (front↔back), played while idle **and**
   walking.
3. **Full getup sequence** — knockdown → lie (countdown + mash) → rise (getup anim plays to
   completion) → control returns, with the getup variant chosen by how the wrestler fell.

The SpriteFrames (`assets/sprites/doink/doink_frames.tres`) already contains every clip
needed: `idle_front/back`, `walk_horisontal_front/back`, `walk_diagonal_front/back`,
`walk_vertical_front/back`, `rotate` (12 frames), `get_up_front`, `get_up_back`,
`get_up_back_2`, `damage_lying`, `rolling`, `run`.

## Architecture (Approach C — hybrid)

Pure, unit-testable helpers for the stateless decisions; thin stateful glue in `fighter.gd`.
Matches the existing `scripts/combat/` + `movement_math`/`relative_input` module pattern.

New pure units (with GUT tests, no node mocking):

- `scripts/facing.gd` (`class_name Facing`) — the 2D facing model + desired-facing rule.
- `scripts/rotate_planner.gd` (`class_name RotatePlanner`) — plan the `rotate` frame list
  between two facing states along the shorter arc.
- `scripts/anim_selector.gd` (`class_name AnimSelector`) — choose walk/idle animation name +
  flip from facing + movement.

Stateful glue stays in `fighter.gd`: the depth-facing field, the TURNING sub-state + frame
timer, and the getup two-phase timer.

## Component 1 — 2D facing + turn-around pivot

### Facing model

- Keep `_facing: float` (±1, horizontal). Add `_depth_facing: int` (FRONT = +1, BACK = −1).
- Combined state ∈ {FR, BR, BL, FL}. `Facing` exposes helpers to convert (h, d) ↔ a state
  enum and to compute the **desired** facing.

### Desired facing (per tick, only when in control / idle / walking)

- **Horizontal:** `sign(opponent.x − self.x)`.
- **Depth:** opponent on the near side of the screen → FRONT, far side → BACK. Near = larger
  Y in Godot screen space (floor band `floor_min_y`=far .. `floor_max_y`=near). So
  `opponent.y > self.y` → FRONT, else BACK. (Convention verified in playtest; flip the single
  comparison if it reads inverted.)
- **Exception — RUNNING:** facing comes from movement, not the opponent. Horizontal =
  `_run_dir_x`; depth = sign of vertical run input (run depth-drift). Running snaps facing
  (no pivot).

This replaces the current unconditional horizontal snap at `fighter.gd:106-107`. That snap
becomes: compute desired facing → request a turn (idle/walk) or snap (attack/grapple/react).

### Rotate clip mapping

`rotate` is a 12-frame full-circle turn. Using 0-indexed Godot frames (file `NN.png` →
frame `NN−1`):

| Segment | Frames (0-idx) | From your sprite numbers |
|---|---|---|
| FR → BR | `[2, 3, 4]` | 3,4,5 |
| BR → BL | `[5, 6, 7]` | 6,7,8 |
| BL → FL | `[8, 9, 10]` | 9,10,11 |
| FL → FR | `[11, 0, 1]` | 12,1,2 |

Settled anchor frames: FR = 1, BR = 4, BL = 7, FL = 10. Forward cycle order:
FR → BR → BL → FL → FR.

### RotatePlanner (pure)

`RotatePlanner.plan(from_state, to_state) -> Array[int]`:
- Walk the 4-cycle forward and backward; pick the shorter arc. Tie (opposite, 2 segments)
  → forward.
- Concatenate the per-segment frame lists; reverse each segment's frames when traversing
  backward. Result is the ordered frame list to play, ending on the destination anchor.
- `from == to` → empty list (no turn).

### TURNING sub-state (in `fighter.gd`)

- New `Mode.TURNING` (or a `_turning` bool flag + frame queue; flag is lighter and avoids
  touching `input_allowed`). Triggered when in control (idle or walking) and
  `desired_state != current_state`.
- On trigger: store the planned frame list, zero locomotion velocity, drive the `rotate`
  clip manually (paused sprite, set `frame` per tick on a fixed cadence — same technique as
  the headlock loop `_hold_victim`, cadence from `ArcadeUnits.ticks_to_seconds`). Cadence
  target ≈ arcade getup/rotate speed (4 ticks/frame) — tune in playtest.
- While turning: no walk movement, no new input-driven attacks interrupt the brief pivot
  (≤ ~3–9 frames). On the last frame: commit `_facing`/`_depth_facing` to the destination,
  clear the turning flag, resume normal idle/walk selection.
- Re-planning guard: only start a new turn when **settled** and `desired != current`. If the
  opponent keeps moving during a turn, re-evaluate after it completes (prevents turn thrash).
- **Snap (no pivot)** while attacking, grappling, head-holding, in a reaction, or running —
  these paths set facing directly as they do today.

## Component 2 — directional walk/idle animation selection

`AnimSelector` (pure) replaces the hardcoded names in `fighter.gd:_update_animation`.

- **Type** from movement input axes (the 8-way `dir` already computed):
  - x≠0, y=0 → `walk_horisontal`
  - x=0, y≠0 → `walk_vertical`
  - x≠0, y≠0 → `walk_diagonal`
  - none → `idle`
  - RUNNING → `run` (unchanged)
- **Suffix** `_front` / `_back` from `_depth_facing`.
- **flip_h** from `_facing` (horizontal), folded into the existing `flip_h_for` / `_LEFT_DRAWN`
  handling so left-drawn reaction art keeps working.

The `rotate` clip is driven only by the TURNING state, not by `AnimSelector`.

## Component 3 — full getup sequence

Today: a knockdown enters `Mode.ONGROUND` with `_react_timer`; when it expires the code plays
`get_up_*` and **immediately** sets `Mode.NORMAL` (`fighter.gd:114-121`). The rise has no
duration and the variant is picked by horizontal `_facing`. Two changes:

### Two-phase getup

1. **DOWN phase** — lying pose (`damage_lying`, or `rolling` for roll moves) held while
   `GETUP_TIME` (`_react_timer`) counts down. Mash-to-recover already shaves the timer
   (`mash_recover`, `_MASH_REDUCE`). Arcade: `ANI_GETUP` set GETUP_TIME, `mode_onground` is a
   `ret` (no control). No change in spirit; keep it.
2. **RISE phase** — when the DOWN timer hits 0, play the getup anim and **gate `Mode.NORMAL`
   on that animation completing** (arcade `ANI_GETUP_WAIT` → rise frames → `MODE_NORMAL`).
   Implement as a distinct rise timer = getup clip length, or watch the clip's
   `animation_finished`. No control during RISE (post-getup the arcade also adds a
   `DELAY_BUTNS=40` input lockout — out of scope here unless trivial to add).

### Getup variant by fall orientation

Set a `_fall_orientation` on the victim at knockdown time (in `_enter_reaction` /
`_detach_victim`), then pick the rise clip:

- **face-up** (lands on back, looking up — default for most knockdowns) → `get_up_front`
- **face-down / back-turned** → `get_up_back`
- **face-down from a slam/roll** (faceslam, flying clothesline, rolling, and similar) →
  `get_up_back_2`

The move→orientation mapping lives in the reaction config (`AMode`/`Reaction`), keyed by
attack family or move id. Arcade parallel: `#getup_tbl` defaults to `*_faceup_getup_anim`,
with explicit `*_facedown_getup_anim` selected when the fall set the face-down/up bits
(`REACT1.ASM`, `ADMSEQ2.ASM #choose_dir`). Exact move list to be confirmed against the art
during build; start set: flying clothesline + faceslam + any move whose reaction anim is
`rolling`.

## Testing

- `RotatePlanner.plan` — all 12 ordered (from,to) pairs: correct segment list, shorter-arc
  selection, reversal, empty on equal, tie → forward.
- `AnimSelector` — every (movement axes × depth facing) combo → correct name + flip; running
  and idle cases.
- `Facing` desired-facing — opponent in each quadrant → expected (h, d); running exception
  uses movement not opponent.
- Getup — fall orientation → correct clip; RISE gates NORMAL until the clip finishes; mash
  shortens DOWN only.
- Existing `test_fighter_control` / `test_fighter_combat` stay green (facing snap during
  attacks/reactions unchanged).

## Out of scope

- Post-getup `DELAY_BUTNS` input lockout and `SAFE_TIME` rise-invulnerability (unless trivial).
- Turn animations for non-Doink wrestlers (single-character project today).
- Run-state pivot (running snaps facing by design).
```
