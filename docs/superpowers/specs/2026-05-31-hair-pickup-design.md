# Hair Pickup — design

**Date:** 2026-05-31
**Status:** approved (brainstorm) → ready for `writing-plans`
**Arcade source of truth:** `DNK.ASM:1709` `#spunch_lbowdrop`; `DNKSEQ3.ASM` `dnk_4_hair_pickup_anim` / `#headheld_tbl`.

## One-line

Grounded SPUNCH on a downed foe, when you stand at their **head** (`|dx| >= 32px` AND facing
opposite their lying-facing), grabs them by the hair and hauls them up into the **existing
head-hold** — instead of the default elbow drop.

## Arcade truth (the gate)

`#spunch_lbowdrop` is the grounded-SPUNCH handler. It defaults to **elbow drop**; hair pickup is
the special case that pre-empts it when BOTH hold:

- `|dx| >= 32px`. The asm `cmpi 20h,a1 / jrlt #no` jumps to elbow-drop when the X distance is
  *less than* `0x20` (32). So hair pickup is the **reaching** case, not the on-top case. (A
  research summary had this inverted; the asm is authoritative.)
- Attacker faces **opposite** the victim's lying-facing (`cmp a0,a14 / jrz #no` on the `M_FLIPH`
  bits) — i.e. the attacker is at the victim's **head**, not their feet.

Victim mode in the arcade dispatch is `ONGROUND` (4) or `DEAD` (9). We take **`ONGROUND` and
alive only** — in a beat-'em-up a defeated enemy is finished/despawned, not lying pinnable
(YAGNI: drop the `DEAD` branch).

The lift's terminal state in the arcade (`SETPLYRMODE,MODE_HEADHOLD` + `#headheld_tbl`) is the
**same** end-state `neck_grab` produces. Hair pickup is therefore an alternate *entrance* into
the head-hold already shipped — not a new hold.

## Decisions (from brainstorm)

1. **Gate fidelity: faithful arcade.** `|dx| >= 32` AND attacker faces opposite the victim's
   down-facing. Elbow drop stays the default for every grounded SPUNCH that fails the gate.
2. **Resulting hold: full reuse, identical to `neck_grab`.** Attacker follow-ups
   (piledriver / head_slam / joy_buzzer), the auto-break timer, AND victim reversal all apply
   unchanged — it is literally the same `HEADHOLD`/`HEADHELD` state.
3. **Dispatch location: the grounded-SPUNCH normal-move path** (`Player._dispatch_normal_move`),
   pre-empting `elbow_drop` — not a `MoveTable`/`MotionTable` entry (the gate is geometric, not a
   range×dir×button cell or a motion pattern). This matches the arcade, where hair pickup lives
   inside `#spunch_lbowdrop`, not the secret-move table.

## Architecture — three pieces, mostly reuse

### 1. Dispatch gate — `Player._dispatch_normal_move` + `HairPickup` helper

After the grounded+SPUNCH lookup resolves to `elbow_drop`, run a pure gate helper against the
downed target; if it passes, `start_move(hair_pickup)` instead. The grapple's existing
`_GRAPPLE_LEAP` step-in carries the attacker the last bit to the head.

New pure, unit-testable helper `scripts/combat/hair_pickup.gd` (mirrors `Proximity` /
`RelativeInput`):

```
HairPickup.gate(attacker_x, attacker_facing, victim_x, victim_facing, victim_mode) -> bool
# true iff  victim_mode == Fighter.Mode.ONGROUND
#           AND |attacker_x - victim_x| >= 32
#           AND attacker_facing is opposite the victim's head-side
```

**Head-side mapping:** the design assumes the victim's head points in its `_facing` direction
(so "attacker faces opposite victim_facing" ⟺ "attacker stands on the head side, facing the
foe"). The plan's first task verifies this against the `damage_lying` art and flips the
comparison sign if the art says otherwise.

### 2. The `hair_pickup` sequence — `tools/build_doink_sequences.gd`

A new `_hair_pickup()` recipe, a **sibling of `_neck_grab()`**: same reach → grab-window →
puppet pull-in → settle shape; `is_grapple = true`, `uninterruptable = true`,
`reverse_reach_on_whiff = true`. Produces `assets/sequences/doink/hair_pickup.tres`.

**Clip wiring** (from the real `doink_frames.tres` anim list):

- **Victim** rises through `lifted` → `liftgrabbed` → `headlocked`, driven by `slave_anim` +
  `victim_anim_frame` per frame exactly as `neck_grab` drives `headlocked`. The clip then
  dissolves straight into the held-struggle `headlocked` the static hold already loops.
- **Attacker** reuses **`headlocks`**. There is no dedicated attacker "hair-pickup" clip in the
  SpriteFrames — `lifted`/`liftgrabbed` are victim poses (past-tense, matching the
  `hip_tossed`/`piledrivered` victim-naming convention). `headlocks` ends on frame 6, the exact
  pose `_hold_victim`/the HEADHOLD branch sustains, so the entrance is visually continuous with
  the hold it produces. The plan's first task inspects the frames to confirm; if one of those
  clips is actually attacker-side, swap it there.

**Frame structure** (mirrors `_neck_grab`):

1. **Reach lead-in** — `headlocks` frames 0..3, no victim attached yet.
2. **Grab window** — `WAIT_HIT_OPP` + `_grab_box()` at the reach apex, `wait_hit_max_ticks = 16`,
   reaching down at the downed foe.
3. **Connected lift pull-in** — resample so the victim's `lifted` + `liftgrabbed` + `headlocked`
   clips play **every frame** (the existing `n >= max(both clips)` rule prevents lift-frame
   drops), with `victim_offset.y` **ramping up from the floor to standing head-hold height** —
   the lift arc. This is the one structural difference from `neck_grab`, whose pull-in is flat
   `y = 0`. Arc magnitude seeded from the source and tuned in playtest, same as the throws. The
   final victim X must match `Fighter._HEADHOLD_VICTIM_X` (the hold continuation), like
   `neck_grab`'s `NECK_HOLD_VICTIM_X`.

No `DAMAGE_OPP` / `DETACH` in the sequence — like `neck_grab`, the head-hold follow-ups own
damage and release.

### 3. The lift state machine — `Fighter.receive_grab` + existing victim channel

**Connect (`receive_grab`):** extend the `neck_grab` branch to also fire for
`move.id == "hair_pickup"` (both enter the head hold). Because the victim is **downed, not
standing**, two additions:

- Cancel the victim's getup state, not just `_react_timer`: **also clear `_getup_rising` /
  `_getup_rise_time`** (today `receive_grab` only zeroes `_react_timer`; a victim mid-RISE would
  otherwise keep playing the getup clip under the lift).
- Set victim → `HEADHELD`, attacker → `HEADHOLD`, arm the break timer
  (`_set_headhold_break_ticks(180)`), stamp the `_last_headhold_time` re-grab cooldown — identical
  to `neck_grab`.

**Lift (existing `_drive_victim`):** a `HEADHELD` victim skips its own `_physics_process`
(`fighter.gd:128`) ⇒ position is fully master-controlled and **not floor-clamped**, so the rising
`victim_offset.y` lifts it off the mat with no new GHOST plumbing. `_drive_victim` already sets
victim facing, position, and slave frame each tick.

**Settle (existing):** the sequence ends with `mode == HEADHOLD` ⇒ the "Attacking" branch's
no-detach guard (`fighter.gd:191`) leaves the victim attached ⇒ next tick the `HEADHOLD` branch
runs `_hold_victim` (the `headlocked` static struggle loop). From there piledriver / head_slam /
joy_buzzer / auto-break / reversal are untouched existing code.

**Verified enabler:** `Hitbox.hurt_box_for_mode(ONGROUND)` already returns a valid box, so the
grab window connects on a downed foe — no hurtbox change needed.

## Testing

**Pure gate unit tests** — `test/unit/test_hair_pickup.gd`, table-driven, no scene:

- `|dx| < 32` → false (elbow drop wins; the `jrlt #no` case).
- `|dx| >= 32`, attacker at head (opposite facing) → true.
- `|dx| >= 32`, attacker at feet (same facing) → false.
- victim not `ONGROUND` (NORMAL / HEADHELD / dead) → false.
- boundary at exactly 32px → true (arcade `jrlt` rejects strictly `< 32`, so `>= 32` passes).

**Integration tests** — scene-based, the style already used for grapples:

- Grounded SPUNCH + gate pass dispatches `hair_pickup`, not `elbow_drop`; gate fail still
  dispatches `elbow_drop`.
- After the lift sequence completes: attacker `HEADHOLD`, victim `HEADHELD`, victim attached,
  break timer armed — the same state `neck_grab` asserts.
- Victim mid-getup (`_getup_rising == true`) is cleanly cancelled by the grab.
- Reuse smoke-check: a follow-up (e.g. `head_slam`) fires from a hair-pickup hold.

**Target:** all GUT green (252 today + the new tests).

## Tooling / regeneration (per CLAUDE.md)

1. Add `_hair_pickup()` to `build_doink_sequences.gd`, run
   `godot --headless --path . -s tools/build_doink_sequences.gd` → writes `hair_pickup.tres`.
2. `godot --headless --path . --import` → refreshes class cache + uids (new `class_name
   HairPickup`).
3. Headless GUT run, all green.

## Out of scope

- The arcade `DEAD`-mode pickup branch (no pinnable corpses in a beat-'em-up).
- Any new follow-up or hold variant — hair pickup reuses the `neck_grab` head-hold verbatim.
- A dedicated attacker lift clip — `headlocks` is reused unless the frame inspection says
  otherwise.

## Reuse map (what is free)

| Concern | Source | New work? |
|---|---|---|
| Head-hold end state (`HEADHOLD`/`HEADHELD`) | `receive_grab`, `_hold_victim` | extend `move.id` branch only |
| Follow-ups (piledriver/head_slam/joy_buzzer) | `Player.scan_headhold_followups` | none |
| Victim reversal | `Player.scan_headhold_reversal` | none |
| Auto-break + release stagger | `_break_head_hold`, `_release_with_stagger` | none |
| Victim puppet drive + lift arc | `_drive_victim` (master-controlled, unclamped) | none |
| Grab connect on a downed foe | `hurt_box_for_mode(ONGROUND)` | none (verified) |
| Step-in to the head | `_GRAPPLE_LEAP` | none |
| Dispatch gate | — | new `HairPickup` helper + `_dispatch_normal_move` hook |
| Lift sequence | `_neck_grab` recipe | new `_hair_pickup` recipe |
| Getup cancellation under grab | `receive_grab` | clear `_getup_rising`/`_getup_rise_time` |
