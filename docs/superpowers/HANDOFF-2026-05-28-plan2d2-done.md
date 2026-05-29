# Handoff — Plan 2d-2 (Grapple Victim Channel) — code complete, playtest pending

**Date:** 2026-05-28
**Branch:** `sp0-plan2d2-grapple-victim-channel` (NOT yet merged to master)
**State:** All 18 implementation tasks done via subagent-driven development (each: implement → spec review → code-quality review → fix loop). **176/176 GUT tests green** headless. The interactive visual playtest (Task 19 final step) is STILL PENDING — a human must run the game and confirm feel/positioning.

## What shipped
The full WWF grab mechanic on the 2d-1 motion-buffer engine:
- **Matcher re-port** to faithful arcade mask semantics (mask = ignore-bits; held-direction trigger fires). `MotionTable` registry + special dispatch in `player.gd` (charge/motion scan before MoveTable).
- **Victim channel**: `SequenceFrame` grapple commands (WAIT_HIT_OPP/SET_ATTACH/SLAVE_ANIM/DAMAGE_OPP/DETACH/SET_OPP_MODE/CLR_OPP_MODE) + victim "slave" track; `SequencePlayer` WAIT_HIT_OPP hold + connect/whiff + one-shot intents; `Fighter` attach/puppet-drive/detach + grapple modes; `AttackResolver` grab routing + eligibility.
- **Throws**: hip toss (PUNCH+away,away), grab & fling (SPUNCH+away,away) — attach → puppet playback → pre-scaled DAMAGE_OPP → DETACH knockdown.
- **Head-hold**: neck grab (SPUNCH+toward,toward) → HEADHOLD/HEADHELD; follow-ups piledriver (toward,toward+SPUNCH), head slam (down,down+SKICK), joybuzzer (hold PUNCH≥100t release); reversals (held wrestler counters → role swap + captor immobilized); auto-break after ~3.4s.
- **Wiring**: Player1 in `scenes/Sandbox.tscn` has the `doink_motions.tres` registry.

## How to playtest (the pending human step)
```
godot --path .
```
Control Player1 (p1_* keys). Confirm, against the ENEMY Dummy/Player2:
- Hip toss / grab & fling fire and knock the victim down with damage.
- Neck grab enters the head hold; piledriver / head slam / joybuzzer follow-ups drive the victim through the slam.
- A reversal during the hold swaps roles; auto-break releases after a few seconds with no input.
- Victim sprite tracks the attacker through the arc without snapping. If offsets look off, tune `victim_offset`/`victim_anim_frame` in `tools/build_doink_sequences.gd` (`_throw`/`_followup`), regenerate (`-s tools/build_doink_sequences.gd`), re-run.

## Known deferred items / simplifications (NOT bugs)
- **Re-grab cooldown** (`_last_headhold_time`) is stamped on neck-grab but not yet enforced (the arcade "fake hold if re-grabbed within 2s" is not implemented).
- **Fling-out-of-ring** needs ring regions (deferred) — throws just knock down.
- **LEAPATOPP** predictive ballistic homing approximated by windup-phase positioning.
- **Victim per-frame offsets** are concrete starting values — tuned in the playtest.
- **grab_fling damage** reuses D_HIPTOSS (27) — no distinct D_GRABFLING in the arcade; confirm in playtest.

## Commits
```
ebf17eb feat(fighter): head-hold auto-break (release both fighters after the hold window)
ba53507 fix(player): guard reversal against a freed captor; document same-frame tie-break
25253e5 feat(player): head-hold reversal (held counters -> role swap + captor immobilized)
b088b6d fix(fighter): reset attacker GRABBING -> NORMAL when a grapple sequence ends (was soft-locking after every throw)
63519de feat(player): head-hold follow-up dispatch (piledriver/head-slam motions + joybuzzer charge); follow-ups drive the held victim without re-grab; hold pose
0df8534 fix(combat): keep head-hold follow-ups out of the main grab-initiator table (no scan-order trap)
4c16c1e feat(combat): author head-hold follow-up sequences + motions (piledriver, head slam, joybuzzer)
11cc9f8 feat(fighter): head-hold entry (HEADHOLD/HEADHELD) + IMMOBILIZE_TIME stun counter
d170d89 test(combat): end-to-end hip-toss grab flow (motion->dispatch->attach->damage->detach)
8aab9b6 feat(combat): author Doink MotionTable + neck-grab master sequence
4436dfa feat(combat): author hip toss + grab & fling master sequences with victim tracks
22e83a6 feat(combat): AttackResolver routes grapple boxes to receive_grab with eligibility
84b0735 fix(fighter): scope mid-sequence facing freeze to grapples (restore strike facing)
8869a13 feat(fighter): puppet drive (slave anim + position), DAMAGE_OPP (pre-scaled), DETACH knockdown
9fbcb7a feat(fighter): grapple modes (GRABBING/GRABBED/HEADHOLD/HEADHELD) + refs + receive_grab attach
1f33585 fix(combat): WAIT_HIT_OPP whiff resumes to recovery (no terminal stall / soft-lock)
951a5e7 feat(combat): SequencePlayer WAIT_HIT_OPP hold + connect/whiff + victim-track intents
14fd0ba feat(combat): MoveSequence.is_grapple flag
a9b3e9b feat(combat): SequenceFrame grapple commands + victim-track fields
7084783 feat(player): special-move dispatch (charge/motion scan before MoveTable) + buffer hygiene on fire
89fec40 feat(combat): MotionTable registry (ordered MotionMove -> grapple MoveSequence)
dbf310f fix(combat): re-author Doink motion .tres with arcade J_ALL/J_REAL_LR masks (held-direction trigger fires); fix MotionMove doc
087b92d fix(combat): re-port MotionMatcher to arcade mask semantics (mask=ignore-bits, shared zero-mask skip budget, held-direction trigger)
```

## Next
Run the playtest; tune offsets if needed; then merge to master (tag e.g. `sp0-plan2d2-grapple-victim-channel`).
