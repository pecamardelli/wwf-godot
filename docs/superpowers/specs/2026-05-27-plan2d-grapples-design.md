# SP-0 Plan 2d — Grapples / Throws (the puppet "victim channel")

**Date:** 2026-05-27
**Status:** design approved, spec for review → writing-plans
**Depends on:** plans 2a/2b/2c (shipped). Source of truth: WWF WrestleMania arcade (TMS34010 asm). Deep-dive research with citations: [`docs/superpowers/research/2026-05-27-arcade-grapple-motion-buffer-deep-dive.md`](../research/2026-05-27-arcade-grapple-motion-buffer-deep-dive.md) (referred below as **RESEARCH §**).

## 1. Goal

Add the signature WWF mechanic: one fighter grabs another and drives the victim's **sprite and position** from a single master sequence (arcade `ANI_SUPERSLAVE2`), plus the faithful **motion buffer** (`check_secret_moves` / `wrest_joystat`) that the grab inputs require.

Scope (all shipping in this plan):
- **Motion buffer engine** — general arcade `{value,mask}`/`maxframes` matcher + charge-release pre-check.
- **Throws:** hip toss (`PUNCH` + away,away), grab & fling (`SPUNCH` + away,away).
- **Head-hold:** neck grab (`SPUNCH` + toward,toward) → `HEADHOLD`/`HEADHELD`, with follow-ups piledriver (toward,toward+`SPUNCH`), head slam (down,down+`SKICK`), joybuzzer (hold `PUNCH`≥100t release).
- **Reversals** — emergent: the held wrestler runs the same follow-up retargeted at the captor.

Non-goals (deferred, unchanged): fling-out-of-ring & ring regions (no ring yet → throws just knock down); authoring the *other* specials the new engine enables (boxing glove, ear slap, hammer); multi-enemy AI; jump/height (Y axis as a player-controlled dimension).

## 2. Architecture overview

Seven pieces. (A)–(C) are new/extended combat data+logic; (D)–(F) live on `Fighter`/`Player`/`AttackResolver`; (G) is authoring.

### A. `MotionBuffer` + `MotionMatcher` (new, `scripts/combat/`)
Faithful `wrest_joystat` (RESEARCH §A).
- **`MotionBuffer`** — per-fighter ring of **16** entries, each `{tick:int, code:int}`. `code` packs the joystick (facing-relative, b0–3: `UP=1,DOWN=2,AWAY=4,TOWARD=8`) | buttons (b4–8: `PUNCH,BLOCK,SPUNCH,KICK,SKICK`) | real screen L/R (b10–11). **Stored facing-relative** (flip at push, like the arcade `#xflip_table`). Pushes on **edges only**: a stick-change pushes one entry; each button-down pushes one entry (single button | current stick). `tick` is the fighter's sim tick (`_sim_time` → `ArcadeUnits`).
- **`MotionMove`** (Resource) — ordered `{value, mask}` steps + `maxframes`. Authored facing-relative.
- **`MotionMatcher`** — scans newest→oldest: head-noise check on the trigger step (`head & ~mask0 != 0` ⇒ reject), then each step matches `(entry.code & mask) == value` allowing up to **8** intervening entries of noise per step; succeeds iff a **freshness** check holds (newest entry tick == current tick) and `current_tick − last_matched_tick ≤ maxframes`.
- **Charge pre-check** — held-tick counters per button (increment while held, reset on release) + a release edge; joybuzzer fires on `PUNCH` release with held ≥100t. Runs **before** the pattern scan (arcade `#charge_buzz` first table entry) and short-circuits it.

### B. `SequenceFrame` / `MoveSequence` extensions (victim track)
Faithful `ANI_SLAVEANIM`/`SUPERSLAVE2` (RESEARCH §B.6) realized as authored per-frame data (we have no part-offset metadata, so the offset is authored — the faithful stand-in for the arcade's per-frame computed `ATTACH_XOFF/YOFF`).
- New `Command`s: `WAIT_HIT_OPP`, `SET_ATTACH`, `SLAVE_ANIM`, `SET_OPP_MODE`, `CLR_OPP_MODE`, `DAMAGE_OPP`, `DETACH`.
- New `SequenceFrame` fields: `victim_anim_frame:int`, `victim_offset:Vector3` (victim pos relative to attacker; x mirrored by attacker facing), and command payloads: `slave_anim:String` (for `SLAVE_ANIM`), `opp_mode_bit:int` (for `SET/CLR_OPP_MODE`, e.g. GHOST), `victim_amode:int`/`victim_dizzy:bool` (for `DAMAGE_OPP`), `wait_hit_max_ticks:int` (for `WAIT_HIT_OPP`).
- `MoveSequence` gains `is_grapple:bool` so dispatch/AttackResolver know to route the connect to attach rather than damage.

### C. `SequencePlayer` extensions (scene-agnostic, RefCounted)
Recognizes the grapple commands and **exposes** state for `Fighter` to apply (same split as today: it surfaces `attack_live`/`active_attack_box`, `AttackResolver`/`Fighter` act):
- `wait_hit` hold: when entering a `WAIT_HIT_OPP` frame, `advance()` **stops advancing** (counting down `wait_hit_max_ticks`); a `notify_grab_connected()` clears the hold (mirrors collision zeroing `ANICNT`); timeout → flag a whiff and resume to recovery.
- Exposes: `pending_attach`, `pending_detach`, current `slave_anim`, `victim_anim_frame`, `victim_offset`, `pending_opp_mode_set`/`_clr`, `pending_damage_opp` (amode/dizzy).

### D. `Fighter` — attach/detach lifecycle + new modes
- New `Mode`s: `GRABBING` (attacker mid-throw; uninterruptable, drives victim), `GRABBED` (victim puppet = `MODE_GHOST|KEEPATTACHED`: no control, no AI, no separation, position driven), `HEADHOLD` (attacker holding), `HEADHELD` (victim held).
- Refs: `_grappling: Fighter` (victim I drive), `_grappled_by: Fighter` (attacker driving me).
- `input_allowed()` stays NORMAL/RUNNING only (grabbed/holding/held read no movement input; HEADHOLD/HEADHELD read **buffer** follow-ups, handled separately).
- Each tick while `_grappling` is set: apply victim slave anim + `victim_anim_frame`, set `victim.global_position = global_position + victim_offset` (x·facing), clamp to floor **unless** victim has the GHOST bit set; on `DAMAGE_OPP` apply pre-scaled puppet damage once (`DAMAGE.EQU` ×1.35 — D_HIPTOSS 27, D_PILEDRIVER 33, …) and arm the post-detach reaction; on `DETACH` release victim → `ONGROUND` (existing getup/mash) and clear both refs.
- Puppet victim's `_physics_process` early-returns (driven externally).

### E. `AttackResolver` — grab routing
When a live box belongs to a grapple move (`is_grapple`), an overlap routes to `victim.receive_grab(attacker, move)` (→ attach + `attacker._player.notify_grab_connected()`) instead of `receive_hit`. Eligibility refuses victims that are DEAD / `ONGROUND` / `HEADHELD` (RESEARCH §A.4, §B.3).

### F. Head-hold sub-state, follow-ups & reversals (`DOINK.ASM:685-832`, RESEARCH §B.8)
- Neck-grab connect → attacker `HEADHOLD`, victim `HEADHELD`, victim's buffer cleared (`clear_opp_counts`), 2-second re-grab cooldown stamped.
- While in the hold, **both** fighters poll their buffer for the follow-up patterns. The handler branches on the inputter's mode:
  - `HEADHOLD` (holder) → start the follow-up master grapple seq (piledriver/head slam/buzzer) with the victim still attached; set victim `IMMOBILIZE_TIME=15`.
  - `HEADHELD` (held) → **reversal**: only if own `IMMOBILIZE_TIME==0` and not about-to-die; swap refs/modes, retarget onto the former captor, set the captor's `IMMOBILIZE_TIME=15`, run the same throw on him.
- Held loop auto-breaks after 3–4 cycles (the arcade `head_held_brk`) → release to NORMAL.
- `IMMOBILIZE_TIME` is a generic per-tick stun counter that also gates motion-buffer specials (so you can't instantly re-counter).

### G. Authoring tools
- Extend `tools/build_doink_sequences.gd`: author grapple master sequences (hip toss, grab & fling, neck grab + head-hold follow-ups) with victim tracks. Per-frame `victim_offset`/`victim_anim_frame` tuned from `DNKSEQ2`/`DNKSEQ3` and the imported victim sprite folders (`hip_tossed`, `piledrivered`, `joy_buzzer`, `headlocked`, `lifted`, `flinged`, …).
- New `tools/build_doink_motions.gd`: author the `{value,mask}`/`maxframes` `MotionMove` resources for the grab + follow-up patterns (values from RESEARCH §A.4, §B.8).
- Wire special dispatch into `player.gd` (specials checked before the `MoveTable` lookup).

## 3. Data flow (one grab, end to end)

1. Input edges push into `MotionBuffer` each tick.
2. On an attack-button press, `player.gd` runs the **charge pre-check**, then `MotionMatcher` over the special patterns; a match yields a grapple `MoveSequence`. No match → existing `MoveTable` lookup.
3. `start_move(grapple_seq)`: windup frames, then `ATTACK_ON` (an `AMODE_PUPPET*` reach box) on a `WAIT_HIT_OPP` frame. `LEAPATOPP`-style homing is approximated by closing distance toward the target during windup (kept simple; arcade sets a ballistic velocity — see §6).
4. `SequencePlayer` **holds** the wait frame. `AttackResolver` sees the grapple box overlap a hurt box → `receive_grab` (eligibility ok) → binds refs/modes, `notify_grab_connected()`. No connect within `wait_hit_max_ticks` → whiff → recovery.
5. **Puppet playback:** each tick the attacker writes the victim's slave anim frame + position from the master sequence; victim is a pure puppet (GHOST during the airborne arc skips the floor clamp).
6. **`DAMAGE_OPP`** at the slam frame applies scaled puppet damage once (+ screen-shake/SFX hook = `HIT_THE_MAT`).
7. **`DETACH`:** victim → `ONGROUND` (knockdown, existing getup/mash); refs cleared.
8. **Head-hold branch:** neck grab attaches into `HEADHOLD`/`HEADHELD` and stays; both poll the buffer for follow-ups; holder throws, held wrestler may reverse (§2.F).

## 4. Testing (GUT, headless — keep the ~111 existing tests green)
- **MotionBuffer:** push/eviction at capacity; encoding (joy | button | real-LR); pushes only on edges; facing-relative storage.
- **MotionMatcher:** matches a valid motion within `maxframes`; rejects stale/expired; rejects out-of-order; honors the 8-entry per-step noise budget; freshness gate; charge-release threshold (≥100t).
- **Grab connect/eligibility:** `WAIT_HIT_OPP` holds until overlap; whiff after `wait_hit_max_ticks`; refuses DEAD/`ONGROUND`/`HEADHELD`.
- **Attach:** binds both modes + refs; victim becomes puppet (control/AI/separation suppressed).
- **Puppet playback:** victim position == `attacker.pos + offset·facing` each tick (GHOST skips floor clamp); victim shows slave anim's `victim_anim_frame`.
- **Damage/detach:** `DAMAGE_OPP` applies scaled puppet damage exactly once; `DETACH` → victim `ONGROUND`, refs cleared on both.
- **Head-hold:** a buffered follow-up launches the right move; auto-break releases the hold.
- **Reversal:** held wrestler's counter inside the window swaps roles + immobilizes the captor 15t; an immobilized held wrestler can't re-counter.

## 5. File plan
**New:** `scripts/combat/motion_buffer.gd`, `scripts/combat/motion_move.gd`, `scripts/combat/motion_matcher.gd`; `tools/build_doink_motions.gd`; grapple sequence + motion `.tres` under `assets/sequences/doink/` + `assets/motions/doink/`; new `test/unit/test_motion_buffer.gd`, `test_motion_matcher.gd`, `test_grapple.gd`.
**Extended:** `scripts/combat/sequence_frame.gd`, `move_sequence.gd`, `sequence_player.gd`, `amode.gd` (PUPPET modes); `scripts/fighter.gd` (modes, attach/detach, puppet drive); `scripts/player.gd` (buffer feed + special dispatch); `scripts/combat/attack_resolver.gd` (grab routing); `tools/build_doink_sequences.gd`, `build_doink_movetable.gd`.

## 6. Open items / deliberate simplifications
- **`LEAPATOPP`** sets a ballistic velocity to a *predicted* target spot (RESEARCH §B.2). 2d approximates with windup-phase homing toward the current target; full predictive leap can follow if the grab feels off in playtest.
- **Fling-out-of-ring** needs ring regions (deferred) → a near-rope throw just knocks down for now.
- **Per-frame victim offsets** are authored (no part-offset metadata in the port); tuned against the arcade sequences + imported sprites in playtest.
- **`round_tickcount`** increment rate assumed 1/frame at 53 Hz (RESEARCH "Uncertain"); our buffer uses the per-fighter sim tick, consistent with `maxframes` 32–60t ≈ 0.6–1.1 s.
