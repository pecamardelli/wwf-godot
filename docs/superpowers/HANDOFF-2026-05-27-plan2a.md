# Morning handoff — Plan 2a (Combat Foundation)

**Branch:** `combat-foundation` (pushed to `github` and `gitlab`). NOT merged to `master` yet —
it's waiting on your playtest (below). **Tests: 27/27 green** (headless GUT).

## What got done overnight (Tasks 1–5 of Plan 2a)

Executed subagent-driven, each verified by re-running the full suite; a spec reviewer checked the
state-machine task and an Opus final review covered the whole branch (**APPROVED WITH NITS** — nits
addressed in commit `3daf814`).

| Commit | What |
|---|---|
| `8b40520` | `ArcadeUnits` — `TSEC=53`, 16.16→px/s conversions, derived walk/run speeds (verified exact) |
| `760b56b` | Arcade 8-way `walk_velocity` (non-normalized; diagonals intentionally faster), replaces `move_velocity` |
| `3c0ab73` | `Fighter.Mode` state machine; input gated to NORMAL/RUNNING — the real arcade stun mechanism |
| `307b81a` | Imported Doink's **full** animation library (83 move folders → PNG sequences) |
| `2ff25e2` | Built one `SpriteFrames` animation per move; wired `idle_front`/`walk_horisontal_front`; dropped stale subset folders |
| `3daf814` | Review polish: tick-vs-frame doc note + input-gating integration test |

## ⏳ The one thing left for you: Task 6 playtest

```bash
/media/pablin/DATOS/JUEGOS/Wrestlemania/Godot_v4.6.3-stable_linux.x86_64 \
  --path /media/pablin/DATOS/JUEGOS/Wrestlemania/wwfmania-godot
```
Make sure you're on the branch first: `git -C <repo> switch combat-foundation`.

Check:
- [ ] Walk *speed/feel* now matches the arcade (noticeably brisker than Plan 1; **diagonals slightly
      faster than cardinals — that's faithful, not a bug**).
- [ ] Walk/idle animations still play; facing flips; depth-sort + soft separation still good (regression).
- [ ] No errors in Godot output about missing animations.

If it feels right:
```bash
git -C <repo> switch master && git -C <repo> merge combat-foundation
git -C <repo> tag sp0-plan2a-combat-foundation
git -C <repo> push github master --tags && git -C <repo> push gitlab master --tags
```
(Or just tell me tomorrow and I'll do it.)

## Things worth knowing

- **Fidelity model:** speeds are arcade **wall-clock** (px/second, since `TSEC=53`), not per-frame.
  We run logic at Godot's 60 Hz, so **1 frame ≠ 1 arcade tick** — tick-denominated durations
  (knockdown, knockback, combo windows) must convert via `ArcadeUnits.ticks_to_seconds()`. Noted in code.
- **Stun = input-gating:** there's no dizzy flag; helpless `Mode`s simply don't read input
  (`Fighter.input_allowed`). Mirrors the arcade exactly. Nothing *enters* helpless modes yet — that's 2c.
- **Known stubs (intentional, for 2b):** `_update_animation` plays `walk_horisontal_front` for ANY
  direction (vertical/back walk anims exist but aren't selected yet); `RUN_SPEED`/`RUN_DEPTH_DRIFT`/
  `BACKWARD_MULT`/`OPP_DOWN_MULT` are staged constants, not yet wired (need facing-toward-target + buttons).
- All 83 Doink animations are in `assets/sprites/doink/<move>/` and addressable by name in
  `doink_frames.tres` (e.g. `mid_punch_front`, `big_boot`, `hip_toss`, `joybuzzer`, `stuned`, `get_up_front`).
- Combat reverse-engineering data lives in `docs/superpowers/research/` (damage values, collision/depth
  model, reaction families, the puppet-sequence format, the full Doink move table) — that's the spec for 2b–2e.

## Next up (when you're back)
**Plan 2b — Sequence ("puppet") engine + hit detection**: the data-driven move-sequence player
(frame durations + `STARTATTACK`/`ATTACK_ON`/`ATTACK_OFF`…), 3D-AABB attack-box vs hurt-box with the
depth model, damage application (×1.348, ⅔-repeat, block→1, health 163), and a couple of strikes
end-to-end. Say the word and I'll write it.
