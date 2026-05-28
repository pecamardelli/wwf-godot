# SP-0 Plan 2d-2 — Grapple Victim Channel (throws + head-hold + reversals)

**Date:** 2026-05-28
**Status:** design approved → writing-plans
**Depends on:** Plan 2d-1 (motion buffer engine, shipped — merge `6c6da22`, tag `sp0-plan2d1-motion-buffer`).
**Source of truth:** WWF WrestleMania arcade (TMS34010 asm) at `/home/pablin/Games/wwf-wrestlemania/`.
Inherits the architecture of the original [Plan 2d design](2026-05-27-plan2d-grapples-design.md) (referred below as **2d §**) and the [arcade grapple/motion deep-dive](../research/2026-05-27-arcade-grapple-motion-buffer-deep-dive.md) (**RESEARCH §**).

## 1. Goal

Build the rest of the signature WWF grab mechanic on top of the shipped motion-buffer engine: one fighter grabs another and drives the victim's sprite + position from a single master sequence (arcade `ANI_SUPERSLAVE2`), through to damage, knockdown, the head-hold sub-state, follow-ups, and reversals.

Scope = pieces **B–G** of the 2d spec, plus two corrections to the shipped engine (§2). Full grapple system in one plan:
- **Throws:** hip toss (`PUNCH` + away,away), grab & fling (`SPUNCH` + away,away).
- **Head-hold:** neck grab (`SPUNCH` + toward,toward) → `HEADHOLD`/`HEADHELD`, with follow-ups piledriver, head slam, joybuzzer (hold `PUNCH` ≥100t then release).
- **Reversals** — emergent: the held wrestler runs the same follow-up retargeted at the captor.

**Non-goals** (unchanged from 2d §1.17): fling-out-of-ring & ring regions (throws just knock down); the *other* specials the engine enables (boxing glove, ear slap, hammer); multi-enemy AI; jump/height as a player-controlled Y axis; full predictive `LEAPATOPP` ballistic homing (windup-phase homing stand-in).

## 2. Corrections to the shipped engine

The 2d-1 handoff flagged the trigger-mask question for bit-confirmation against the arcade. Verified against `WRESTLE.ASM check_secret_moves` (`:4851`), `update_joystat` (`:4569`), `DOINK.ASM` grab tables (`:426`, `:504`, `:572`), and `GAME.EQU` (`:366-428`). Two corrections result; these are the only changes to already-shipped code.

### 2a. `MotionMatcher` faithful re-port

The shipped matcher inverted the arcade's mask polarity and diverged on noise handling. Re-port to match the asm 1:1:

- **Mask = bits to IGNORE.** Match test becomes `(entry & ~mask) == value` (arcade `andn a1,a8 ; cmp a0,a8`, `WRESTLE.ASM:4912-4915`).
- **Trigger / head check:** reject the move if `(head & ~mask₀) == 0` — the newest entry must carry at least one *significant* bit for the trigger step (arcade `andn a1,a14 ; jrz #next_table`, `:4894-4898`, comment "if the mask leaves nothing behind, then there's noise since the final (trigger) move, so blow it off"). Combined with the freshness gate (newest tick == current), this enforces "the trigger is the newest entry and is a real button down."
- **Unified step loop from step 0 / entry 0.** The arcade re-reads step 0's value in `#loop` and matches it against the head entry; restructure our matcher so step 0 is matched against entry 0 in the same loop (not a separate special-case value compare).
- **Noise-skip budget:** only entries that mask to **zero** (`(entry & ~mask) == 0`) count against the 8-entry skip budget (`SKIP_BUDGET`); an entry that has significant bits but `!= value` **fails the whole move** (arcade `dsjeq a3,#skip` only loops on the EQ/zero case, otherwise falls through to `cmp`/`#failed`, `:4904-4919`). Today *every* non-matching entry burns budget — that is the divergence being fixed.

### 2b. Trigger tolerates a held direction (the flagged decision)

`update_joystat` stores each button-down edge as `button_bit | current_stick` (`:4619 or a8,a4`) — the held direction **is** present on the trigger entry. The grab trigger step uses `mask = J_ALL` (`DOINK.ASM:577,509,427`), and `J_ALL = 01111b | J_REAL_LR` (`GAME.EQU:380`) = exactly the joystick direction bits (facing-relative nibble + real screen L/R), **not** the button bits. So `(head & ~J_ALL) == B_PUNCH` strips all direction bits and compares the button only.

**Verdict: a held direction is ignored on the trigger frame.** "Hold away, away, press PUNCH while still holding away" fires the hip toss. The shipped `.tres` (requiring a neutral stick on the press frame) are wrong.

Authored steps after correction (newest-first, faithful to `DOINK.ASM`):
- **Trigger step:** `value = button bit` (`B_PUNCH`/`B_SPUNCH`), `mask = J_ALL`.
- **Directional steps:** `value = J_AWAY`/`J_TOWARD`, `mask = J_REAL_LR` (ignore real screen L/R; the facing-relative direction is significant).

Re-authors `tools/build_doink_motions.gd` + the three `.tres`, and rewrites `test/unit/test_motion_matcher.gd` / `test_motion_patterns.gd`. Adds the first end-to-end `feed_input → matcher` test (none exists today — handoff gap).

## 3. Special dispatch + motion registry (handoff note #3, now decided)

- **`MotionTable` Resource, parallel to the existing `MoveTable`.** Holds the ordered `MotionMove` list and maps each to its grapple `MoveSequence`. `Player` preloads it exactly like `_MOVES := preload("res://assets/movetables/doink.tres")`.
- **Dispatch in `player.gd`, inside/after `super(delta)`** (the buffer is fed unconditionally each frame, even while attacking/downed — 2d-1). Order per the arcade (specials before normals): **charge pre-check → motion scan → existing `MoveTable` lookup**.
- **Gate *dispatch* (not feeding)** with `Fighter.input_allowed(mode)` + `!is_attacking()`, the same gate `_unhandled_input` applies to normals.
- **Buffer hygiene:** `motion_buffer.clear()` after a grab fires and on round reset, so stale edges can't re-trigger (API exists, nothing calls it yet).
- *Rejected alternative:* hard-coding the motion list in a Doink-specific script — inconsistent with the data-driven `MoveTable`/`.tres` pattern.

## 4. Inherited architecture (unchanged from 2d §2, built on the corrected engine)

- **B. `SequenceFrame` / `MoveSequence` victim track** — new `Command`s `WAIT_HIT_OPP`, `SET_ATTACH`, `SLAVE_ANIM`, `SET_OPP_MODE`, `CLR_OPP_MODE`, `DAMAGE_OPP`, `DETACH`; new frame fields `victim_anim_frame`, `victim_offset:Vector3`, command payloads; `MoveSequence.is_grapple:bool`.
- **C. `SequencePlayer` grapple commands** (scene-agnostic) — `WAIT_HIT_OPP` hold + `notify_grab_connected()` clear + whiff timeout; exposes `pending_attach`/`pending_detach`/`slave_anim`/`victim_anim_frame`/`victim_offset`/`pending_opp_mode_*`/`pending_damage_opp`.
- **D. `Fighter` attach/detach + modes** — `GRABBING`, `GRABBED` (`GHOST|KEEPATTACHED` puppet), `HEADHOLD`, `HEADHELD`; refs `_grappling`/`_grappled_by`; per-tick puppet drive (slave anim + `victim_anim_frame` + `position = attacker.pos + victim_offset·facing`, floor-clamp unless GHOST); scaled puppet damage once on `DAMAGE_OPP` (`DAMAGE.EQU` ×1.35); `DETACH` → victim `ONGROUND`. Puppet `_physics_process` early-returns.
- **E. `AttackResolver` grab routing** — `is_grapple` live box overlap routes to `victim.receive_grab(attacker, move)` instead of `receive_hit`; eligibility refuses DEAD / `ONGROUND` / `HEADHELD`.
- **F. Head-hold sub-state, follow-ups & reversals** (`DOINK.ASM:685-832`) — neck-grab connect → `HEADHOLD`/`HEADHELD`, victim buffer cleared, 2s re-grab cooldown; both fighters poll the buffer for follow-ups; holder launches the follow-up grapple (victim `IMMOBILIZE_TIME=15`); held wrestler may reverse if own `IMMOBILIZE_TIME==0` (swap refs/modes, immobilize former captor 15t); auto-break after 3–4 cycles. `IMMOBILIZE_TIME` = generic per-tick stun that also gates buffer specials.
- **G. Authoring** — extend `tools/build_doink_sequences.gd` with grapple master sequences + victim tracks (tuned from `DNKSEQ2`/`DNKSEQ3` + imported victim sprite folders); the re-authored `build_doink_motions.gd`.

## 5. Build sequencing (task groups for the plan)

Ordered so something is testable/playable as early as possible:

1. **Matcher re-port + trigger fix** (§2) — pure engine, TDD, no new gameplay.
2. **Dispatch + `MotionTable`** (§3) — a matched grab fires a `MoveSequence` (placeholder/whiff; no victim channel yet).
3. **Victim-track sequence data + `SequencePlayer` grapple commands** (B, C).
4. **`Fighter` attach/detach + puppet drive + modes** + **`AttackResolver` grab routing/eligibility** (D, E).
5. **Hip toss + grab & fling end-to-end** (attach → puppet → `DAMAGE_OPP` → `DETACH` knockdown). *First playable grab.*
6. **Neck grab → head-hold, follow-ups (piledriver / head-slam / joybuzzer), reversals** (F).
7. **Authoring pass + manual playtest** (G + §6).

## 6. Testing & completion bar

- Every group ships **GUT-green headless** against the 2d §4 matrix: motion buffer; matcher (valid match within window, stale/expired reject, out-of-order reject, 8-entry noise budget, freshness gate, charge ≥100t, **held-direction trigger fires**, faithful mask polarity); grab connect/eligibility (`WAIT_HIT_OPP` holds, whiff timeout, refuses DEAD/`ONGROUND`/`HEADHELD`); attach (binds modes+refs, puppet suppresses control/AI/separation); puppet playback (position == `attacker.pos + offset·facing`, GHOST skips floor clamp, shows `victim_anim_frame`); damage/detach (scaled damage once, `DETACH` → `ONGROUND`, refs cleared both sides); head-hold (buffered follow-up launches the right move, auto-break releases); reversal (counter in-window swaps roles + immobilizes captor 15t; immobilized held wrestler can't re-counter).
- **Final task: launch the real Godot game and hands-on playtest** — input each motion, confirm the three grabs fire, the victim puppets and positions correctly, damage + knockdown land, head-hold follow-ups and a reversal work. Catches feel / positioning / timing issues unit tests can't (matches how 2c tuned "playtest feel").

## 7. File plan

**New:** `assets/movetables/` motion registry (`MotionTable` resource + `.tres`); `test/unit/test_grapple.gd`, `test_motion_feed_dispatch.gd` (end-to-end feed→matcher→dispatch).
**Re-authored (engine correction):** `scripts/combat/motion_matcher.gd`; `tools/build_doink_motions.gd` + `assets/motions/doink/*.tres`; `test/unit/test_motion_matcher.gd`, `test_motion_patterns.gd`.
**Extended:** `scripts/combat/sequence_frame.gd`, `move_sequence.gd`, `sequence_player.gd`, `amode.gd` (PUPPET modes); `scripts/fighter.gd` (modes, attach/detach, puppet drive); `scripts/player.gd` (special dispatch + buffer hygiene); `scripts/combat/attack_resolver.gd` (grab routing); `tools/build_doink_sequences.gd`.

## 8. Open items / deliberate simplifications (unchanged from 2d §6)

- **`LEAPATOPP`** approximated by windup-phase homing toward the current target; full predictive ballistic leap can follow if the grab feels off in playtest.
- **Fling-out-of-ring** needs ring regions (deferred) → near-rope throw just knocks down.
- **Per-frame victim offsets** are authored (no part-offset metadata in the port); tuned against the arcade sequences + imported sprites in playtest.
- **`round_tickcount`** rate assumed 1/frame at 53 Hz; our buffer uses the per-fighter sim tick, consistent with `max_ticks` 32–60t ≈ 0.6–1.1 s.
