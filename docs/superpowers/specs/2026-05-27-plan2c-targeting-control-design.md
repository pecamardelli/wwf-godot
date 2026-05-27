# SP-0 Plan 2c: Targeting, Facing, Run/Block & Move Dispatch — Design

**Status:** Design approved 2026-05-27. Next: implementation plan (superpowers:writing-plans).

## Goal

Complete the single fighter's **grounded control loop**, arcade-faithful: auto-target the right enemy → always face it → move / run / block relative to it → fire the right move from a *range × relative-direction × button* dispatch table → and close the knockdown loop with a getup (visual + mash-to-recover). This turns the inert `I` (run) / `K` (block) keys and the flat button→move dispatch from 2b into real mechanics.

## Sources of truth & references

- **Arcade source (authoritative for mechanics):** `/home/pablin/Games/wwf-wrestlemania` (TMS34010 asm). Key routines cited inline below.
- **GameMaker project (reference for the structure / user-intended shape):** `/media/pablin/DATOS/JUEGOS/Wrestlemania/wwf` (`WWF.yyp`).
- Builds on Plan 2b (tag `sp0-plan2b-hit-detection`) and the constants staged in `ArcadeUnits` during 2a.
- Combat research: `docs/superpowers/research/2026-05-27-arcade-move-animation-system.md` (Doink moveset, input→move mapping, FACE24) and `…-movement-state-dizzy-getup.md` (getup).

Principle: derive faithful behavior from the arcade source and cite `file:line`; consult the GameMaker project for user-requested changes/improvements.

## Architecture overview

New pure, unit-testable modules under `scripts/combat/`, plus integration on `Fighter` and `Player`:

- `Targeting` — biased nearest-opponent scoring (pure).
- `RelativeInput` — maps raw 8-way input to toward/away/up/down given facing (pure).
- `MoveTable` (+ a per-character data resource) — the range × relative-dir × button → `MoveSequence` lookup.
- `Fighter` gains: `side`, `target`, target recompute cadence, facing-toward-target, run/block modes, facing-aware walk multipliers, getup state.
- `Player` dispatches buttons through `MoveTable` using range + relative direction.
- A stationary enemy-side training dummy in the Sandbox for testing.

Axis mapping continues from 2b: **X = position.x (horizontal), Z = position.y (depth/floor band), Y = height (0 grounded)**.

## 1. Side / faction

`Fighter` gains `enum Side { PLAYER, ENEMY }` and `@export var side: int = Side.PLAYER`. Targeting considers only **opposite-side** fighters, so co-op players never target each other (arcade `calc_closest` skips same `PLYR_SIDE`, `WRESTLE.ASM:4127`).

## 2. Targeting (arcade `calc_closest`, `WRESTLE.ASM:4107-4210`)

Pure `Targeting.pick(self_fighter, candidates) -> Fighter` (or null). For each candidate that is opposite-side and not dead:

- **Base score** = true 3D distance `√(dx² + dz² + dy²)` (dx on X, dz on Z=depth, dy on Y=height).
- **Biases** (multiply/adjust the score; lower = more likely chosen):
  - **Downed ×2** — candidate in `ONGROUND` mode scores ×2 (deprioritize floored enemies).
  - **Last-hit −25%** — the candidate equal to `self.WHOIHIT` (the fighter this one most recently hit) scores ×0.75 (combat stickiness, prevents target flicker).
  - **INRING ×2** — *deferred*: no ring/arena regions exist yet; leave a hook + comment, do not implement scoring for it in 2c.
- Pick the lowest-scoring candidate; **prefer a live candidate over a dead one** (arcade `a11` alive flag).

**Recompute cadence** (`calc_closest2`, `WRESTLE.ASM:4107`): recompute immediately if the current target is dead/freed; otherwise only every 4th tick, staggered by an index so all fighters don't recompute the same tick. Store the result in `Fighter.target`. `Fighter` tracks `_who_i_hit` (set in `receive_hit`'s attacker bookkeeping) to feed the last-hit bias.

## 3. Facing + relative input

- **Facing:** each physics tick, if `target` exists, set `_facing` toward `target.global_position.x` (reuse the logic-side `_facing` field added in 2b; the sprite mirrors it). With no target, keep current facing. Because facing is now continuous, 2b's start-of-attack `_face_nearest_opponent` snap becomes redundant — fold it into the continuous logic (it can be removed once the target always drives facing). The arcade selects `_2_`/`_4_` animation variants from `FACING_DIR` via the `FACE24` macro (`MACROS.H:51`); we only need left/right flip for the front-facing clips now (`_2_`/`_4_` vertical variants are a later art task).
- **Relative input:** pure `RelativeInput.resolve(raw_dir: Vector2, facing: float) -> {toward, away, up, down}` — `toward` = input pointing at the target (arcade `J_TOWARD`; GMS `get_keys` forward/backward). Drives both movement multipliers and move dispatch.
- **Facing-aware walk multipliers** (staged in `ArcadeUnits` in 2a): apply `BACKWARD_MULT` 0.9 when moving away from the target, and `OPP_DOWN_MULT` 1.5 when the target is grounded. These compose with the existing `walk_speed_scale` / `depth_speed_scale` feel layer.

## 4. Run & Block

- **Run:** holding `p_run` (I) enters `RUNNING` mode and moves at `ArcadeUnits.RUN_SPEED` (331.25 px/s) with `RUN_DEPTH_DRIFT` (132.5) on the depth axis — both staged in 2a. Releasing returns to NORMAL. The running **attack slot** fires while RUNNING (big boot for Doink). *The run trigger is our dedicated `I` key — a deliberate control-scheme deviation from the arcade's PUNCH+KICK/turbo; the run motion/speed/attack behavior is arcade-derived.*
- **Block:** holding `p_block` (K) enters `BLOCK` mode — no movement, no attack initiation; incoming damage from the front resolves to 1px (the `blocked` path already exists in `Damage`/`Reaction` from 2b). Block only mitigates attacks from the facing side (arcade frontal block). Releasing returns to NORMAL.

Both modes integrate with the existing `Mode` state machine and `input_allowed` gating; helpless/reaction states still override.

## 5. Move dispatch (arcade `mode_table → action_table → JJXM`, `DOINK.ASM:1654/1845`)

A per-character `MoveTable` resource maps **range × relative-direction × button → MoveSequence**:

- **Range:** `RUNNING` (in run mode) → `CLOSE` (target within the close gate, arcade `CLOSEST_XDIST`/`ZDIST`) → `NORMAL` (otherwise). Close-gate thresholds taken from the arcade per-move ranges.
- **Relative direction:** neutral / toward / away / down (from `RelativeInput`).
- **Button:** low-punch / high-punch / low-kick / high-kick (the four wired keys; arcade `PUNCH`/`SPUNCH`/`KICK`/`SKICK` family).

Lookup order mirrors the GMS `check_attack`: running-attack first if RUNNING; else close-range (direction-specific, then default) if target is near; else normal-range (direction-specific, then default). Wire the **5 existing strikes** into their Doink slots per the arcade moveset table (research doc §3), e.g. low-punch far → punch / close → headbutt; high-punch → uppercut; low-kick → kick; running → big boot. Unfilled slots are simply absent → no move fires.

## 6. Getup (visual + mash-to-recover) — arcade `set_getup_time`, `GETUP.ASM:32-184`

When a knockdown reaction ends its down-time, play `get_up_front` / `get_up_back` (chosen by facing) before returning control, instead of snapping to idle. **Mash-to-recover:** pressing buttons/directions during the down-time reduces the remaining getup timer (arcade lets the player mash to get up faster), down to a floor. Knockdown `STAY_TIME` (270 ticks) and the per-reaction getup times come from 2b's `AMode.getup_ticks`.

## 7. Training dummy + testing

- **Dummy:** a stationary `side = ENEMY` `Fighter` placed in `Sandbox.tscn` (no AI, just stands and takes hits) so targeting, facing, ranges, run/block, and dispatch are exercisable immediately. Player1 stays `side = PLAYER`.
- **Unit tests (pure):** targeting scores + each bias (downed, last-hit) + alive-preference + recompute cadence; relative-input mapping across facings; `MoveTable` lookups for each range/direction/button slot; facing-aware multiplier selection; getup-timer mash reduction.
- **Integration tests:** target acquired/switched; faces target; run speed; block→1 damage from front; correct move fires per range/direction; knockdown → getup → control returns.
- **Playtest:** the feel (target feels right with two enemies, facing reads correctly, run/block/getup feel).

## 8. Deferred (later plans)

Motion-buffer specials (double-tap dashes, charge/secret moves), grapples/throws + puppet victim channel (2d), combo scaling, jump/height (Y), multi-enemy AI and waves (enemies plan), ring regions/`INRING` scoring, and the `_2_`/`_4_` vertical facing animation variants.

## Open items to pin during planning

- Exact close-gate distances per move (from arcade Doink ranges in the research table).
- Exact mash-reduction rate / getup floor (arcade `GETUP.ASM` specifics).
- Whether run uses acceleration (like the 2a walk feel layer) or snaps to run speed — default: reuse the feel-layer ease for consistency unless the arcade differs.
