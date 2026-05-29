# Design — Headlock reach / grab / reverse (arcade-faithful neck grab)

**Date:** 2026-05-29
**Branch:** `sp0-plan2d2-grapple-victim-channel`
**Status:** approved design, pre-implementation

## Goal

Make the standing neck grab (`neck_grab`) match the arcade `dnk_3_head_hold_anim`
(`DNKSEQ3.ASM:1389-1474`, anim `D4GH3A`):

1. **Reach out** through the lead-in frames to a grab-window frame (the reach apex).
2. **On connect:** a tiny contact freeze, then puppet-drive the victim into the
   headlock pose, then enter `HEADHOLD`/`HEADHELD`.
3. **On whiff or block:** the reach animation **reverses** back to the start, then
   recovers to `NORMAL`. A *blocked* grab additionally gets a small backward recoil
   (arcade `#missedb` `ANI_SET_YVEL,30000h`); a clean miss (`#missed`) reverses with
   no recoil.

This is the same "don't drop frames / match the source exactly" discipline applied
to the hip toss (commit `6f1d808`).

## Arcade reference (source of truth)

`dnk_3_head_hold_anim`:
- Reach: `FR1`(2t) → `FR2`(2t) → `LEAPATOPP TGT_HEAD` → `FR3`(3t), then
  `ANI_ATTACK_ON,AMODE_PUPPET` + `ANI_WAITHITOPP,5,FR4` — the grab window sits at the
  **reach apex `FR4`**, held up to 5 ticks — then `ANI_ATTACK_OFF`.
- `#gothim` (connect): `clear_opp_counts`, `head_grab_time`, `ANI_ATTACHZ`,
  `MODE_KEEPATTACHED`, a 1-tick `SUPERSLAVE2` on `FR4` + `ANI_WAITHITGND` (the tiny
  freeze), then `SUPERSLAVE2` through `FR4→FR5→FR7→FR8` (`FR6` skipped) puppet-driving
  `#puppet_tbl 0-3`, then `ANI_SETPLYRMODE,MODE_HEADHOLD` + `ANI_SLAVEANIM,#headheld_tbl`.
- `#missed`: `CALL_MISSES`, then `FR4`(5t)→`FR3`(3t)→`FR2`(3t)→`FR1`(3t) — reach
  reversed — then `MODE_NORMAL`.
- `#missedb` (blocked): `ANI_SET_YVEL,30000h` (upward recoil), then the same
  `FR4→FR3→FR2→FR1` reverse, then `MODE_NORMAL`.

## Frame mapping onto our assets

`headlocks` standing portion = frames 0-6 (sprites 01-07); the held victim clip is
`headlocked` (8 frames). Aligning the arcade phases to our clip (and the user's
"reach to frame 5, hold at frame 7" in 1-based sprite numbers → 0-based indices):

| Phase | `headlocks` frame(s) | Command |
|---|---|---|
| Reach lead-in | 0, 1, 2, 3 | none (animation only) |
| Grab window (reach apex) | **4** (sprite 05) | `WAIT_HIT_OPP` (+ grab box) |
| Connected pull-in → hold | 5 … 6 (sprite 07 = hold pose) | `SET_ATTACH` then `SLAVE_ANIM` |
| Reverse (whiff/block) | 4 → 3 → 2 → 1 → 0 | replay reach backward |

The connected pull-in covers both clips so the `headlocked` victim plays **every**
frame: connected step count `= max(attacker_continuation_frames, victim_frames)`,
each clip resampled independently (the attacker may repeat a frame; the watched
victim never drops one). No `DAMAGE_OPP`/`DETACH` — follow-ups drive those.

## Components

### 1. `SequencePlayer` — reverse phase + block outcome
- Record `_grab_window_index` (the frame index when `WAIT_HIT_OPP` is entered).
- Add `blocked: bool` and `notify_grab_blocked()` (mirrors `notify_grab_connected`),
  which ends the wait and triggers the reverse phase.
- Replace the current "whiff → `_finish()`":
  - On `WAIT_HIT_OPP` timeout (whiff) **or** `notify_grab_blocked()` (block), **if**
    `_grab_window_index > 0`, enter a **reverse phase**: clear the live grab box
    (`attack_live = false`, `active_attack_box = null` — the reach is retracting, not
    attacking), then step the already-played reach frames from `_grab_window_index` down
    to `0` (reusing each frame's `anim_frame` + `duration_ticks`), then `_finish()`. Set
    `whiffed`/`blocked` accordingly.
  - If `_grab_window_index == 0` (throws — grab window at frame 0), keep the current
    immediate `_finish()` (no behavior change for hip toss / grab & fling).
- `current_frame()` returns the reversed frame during the reverse phase so the Fighter
  renders it with no extra wiring.

### 2. `AttackResolver` — block detection
- In `resolve_tick()`, when `move.is_grapple` and the boxes overlap: if the victim is
  guarding (`victim._is_guarding()`), call `attacker._player.notify_grab_blocked()`
  instead of `receive_grab()`. A clean miss = no overlap = the existing timeout path.
- `_can_be_grabbed()` is unchanged (a guarding, otherwise-eligible victim is "blocked,"
  not "grabbed").

### 3. `Fighter` — recoil on block
- The attacker already renders `current_frame().anim_frame`, so reversed frames display
  automatically; no change to `_play_sequence_anim`.
- When the player reports `blocked`, apply a brief **backward** recoil nudge to the
  attacker (away from the blocker). Our fighters are floor-clamped with no jump, so this
  is a short horizontal recoil rather than the arcade's literal vertical hop; magnitude
  tuned in playtest.

### 4. Builder `_neck_grab` (`tools/build_doink_sequences.gd`)
Re-author to the frame mapping above:
- Reach lead-in frames 0-3 (no grab command).
- `WAIT_HIT_OPP` at frame 4 with the grab box + whiff timeout.
- Connected pull-in: `SET_ATTACH` on the first connected step, then `SLAVE_ANIM`
  through the hold pose, step count `= max(continuation, headlocked_frames)` so no
  victim frame drops.
- Regenerate `.tres` via `godot --headless --path . -s tools/build_doink_sequences.gd`.

## Testing

Unit tests (GUT, `test/unit/`):
- **Reverse phase:** a grapple with grab window at index > 0 that whiffs steps the
  reach frames back to 0 (assert the played `anim_frame` sequence descends to 0), then
  finishes; `whiffed` is set.
- **Block:** a guarding victim under a grapple box routes to `notify_grab_blocked`
  (not `receive_grab`); the player enters the reverse phase and sets `blocked`.
- **No reverse for throws:** a grab window at index 0 still finishes immediately on
  whiff (hip toss unchanged).
- **Connect still drives the hold:** a connected neck grab reaches `HEADHOLD`/`HEADHELD`
  and the `neck_grab` sequence shows every `headlocked` victim frame (no drop).
- **Sequence shape:** `neck_grab` has the `WAIT_HIT_OPP` mid-clip (index 4) with a
  forward reach lead-in (frames 0-3 present, in order, no grab command).

## Out of scope / deferred
- Applying reverse-on-whiff to the throws (hip toss / grab & fling) — they keep the
  current immediate-end behavior; the engine supports it if wanted later.
- A literal vertical recoil hop (no jump system); a horizontal nudge stands in.
- The 2s re-grab "fake hold" cooldown (already deferred in plan 2d-2).
