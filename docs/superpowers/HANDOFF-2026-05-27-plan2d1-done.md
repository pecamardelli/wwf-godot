# Handoff — Plan 2d-1 (Motion Buffer Engine) SHIPPED

**Date:** 2026-05-27 (overnight autonomous run)
**State:** merged to `master` (merge commit `6c6da22`), tagged `sp0-plan2d1-motion-buffer`, pushed to `github` + `gitlab`. Working tree clean. **137/137 GUT tests green.**

## What shipped

The faithful arcade input "motion buffer" (`wrest_joystat` / `check_secret_moves`) — the input layer the grab moves need — built TDD via subagent-driven development (each task: implement → spec review → code-quality review → fix loop). All new units are scene-agnostic (`RefCounted`/`Resource`) and `class_name`-registered.

- `scripts/combat/motion_buffer.gd` — `MotionBuffer`: 16-entry ring of input **edges**, newest-first. Joystick stored **facing-relative** (toward/away) + real screen L/R. `encode_stick(dir, facing)`, `push(code, tick)`, accessors, `clear()`.
- `scripts/combat/motion_move.gd` — `MotionMove` (Resource): `{values, masks}` step list (newest-first) + `max_ticks` (arcade ticks).
- `scripts/combat/motion_matcher.gd` — `MotionMatcher.matches(move, buffer, current_tick)`: freshness gate; **trigger must BE the newest entry** (head-noise check + exact value check); per-step newest→oldest scan tolerating up to `SKIP_BUDGET` (8) intervening entries; arcade-tick→frame window.
- `scripts/combat/charge_tracker.gd` — `ChargeTracker`: per-button held-frame counts + release-edge duration (joybuzzer = PUNCH held ≥100 ticks then release). Fed each frame; **not yet wired to any move**.
- `scripts/arcade_units.gd` — added `LOGIC_FPS=60` + `ticks_to_frames()` (53 Hz arcade ticks → 60 Hz logic frames, round up).
- `scripts/player.gd` — `feed_input()` / `_buttons_held_mask()` / `_held()`; `_physics_process` override feeds the buffer + charge every frame from live `Input`, then calls `super(delta)`. **No special-move dispatch yet** (deliberately deferred to 2d-2).
- `tools/build_doink_motions.gd` + `assets/motions/doink/{hip_toss,grab_fling,neck_grab}.tres` — authored grab input patterns (hip toss = PUNCH+away,away; grab-fling = SPUNCH+away,away; neck grab = SPUNCH+toward,toward).

Tests: `test/unit/test_motion_buffer.gd`, `test_motion_matcher.gd`, `test_charge_tracker.gd`, `test_motion_buffer_feed.gd`, `test_motion_patterns.gd`.

## How to test
```
cd /media/pablin/DATOS/JUEGOS/Wrestlemania/wwfmania-godot
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -gprefix=test_ -gsuffix=.gd -ginclude_subdirs -gexit
```
Expect **137 passing**. (Run `godot --headless --path . --import` first if Godot complains about unresolved `class_name` globals.)

Nothing is player-visible yet — the buffer is fed but no move reads it. There is no manual playtest for 2d-1; it's an engine layer. Visible grapples arrive in **Plan 2d-2**.

## ⚠️ One thing to decide in 2d-2 (flagged by final review — IMPORTANT)
**The grab trigger currently requires a NEUTRAL stick on the button-press frame.** `feed_input` pushes a button-down as `bit | current_stick`, and the matcher's trigger mask (`ALL`) rejects any direction bits on the trigger entry. So "hold away + press PUNCH (still holding away)" does **not** fire — the player must tap away, away, release to neutral, then PUNCH. This is self-consistent across tool/matcher/tests and is a defensible reading of the arcade's `J_ALL` trigger mask, **but it was not bit-confirmed against `check_secret_moves`.**

Before wiring dispatch in 2d-2: **verify against the arcade** (`WRESTLE.ASM` `check_secret_moves` + the `DOINK.ASM` grab `{value,mask}` tables) whether the trigger tolerated a held direction. If it did, drop the direction bits from the `.tres` trigger masks (`tools/build_doink_motions.gd` `ALL` const) so a held-direction press still fires. There is currently **no end-to-end `feed_input`→matcher test** — that's the first real-input path 2d-2 will hit.

## Notes for Plan 2d-2 (grapple victim channel)
1. **Dispatch ordering:** read `motion_buffer` for specials **after** `feed_input` (i.e. inside/after `super(delta)`), and gate *dispatch* (not feeding) like `_unhandled_input` does for normals (`Fighter.input_allowed(mode)`, `is_attacking()`). The buffer is fed unconditionally even while attacking/downed.
2. **Specials before normals:** the arcade runs `check_secret_moves` before the normal `action_table`. Wire the special scan ahead of the existing `MoveTable` lookup in `player.gd`.
3. **Move registry:** `MotionMatcher.matches` is currently only called from tests. 2d-2 needs a per-frame scan over the authored `.tres` set (analogous to how Player preloads `assets/movetables/doink.tres`); decide where the motion list / special→MoveSequence mapping lives.
4. **Buffer hygiene:** consider `motion_buffer.clear()` after a grab fires / on round reset to avoid stale edges re-triggering (API exists, nothing calls it).
5. **Charge:** `charge` is fed but unused — ready for the joybuzzer (`released_after(B_PUNCH, 100)`).
6. The full 2d design (victim channel, attach/puppet/throw, head-hold, reversals) is specced in `docs/superpowers/specs/2026-05-27-plan2d-grapples-design.md`; arcade deep-dive with citations in `docs/superpowers/research/2026-05-27-arcade-grapple-motion-buffer-deep-dive.md`. Next: write Plan 2d-2 against this real buffer API, then subagent-driven execution.
