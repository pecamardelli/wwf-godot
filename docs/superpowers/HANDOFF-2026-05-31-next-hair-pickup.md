# Handoff → Next feature: Hair Pickup

**State (2026-05-31):** The player ground-moveset feature is **shipped to `master`** (merged + pushed
to `gitlab` and `github`), working tree clean, **252 GUT tests green**:
```
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit
```
(godot = `/home/pablin/.local/bin/godot`.) Branch `sp0-player-moveset-completion` was deleted after merge.

## Next feature: Hair Pickup

A grab on a **downed/stunned** foe: with the opponent ONGROUND, pressing **SPUNCH** while roughly
**x-aligned** with them grabs them by the hair and **lifts them into a hold / back to standing**
(victim anims `lifted` / `liftgrabbed` exist in the SpriteFrames). It is NOT a strike — it's a
**grapple interaction** (reuses the puppet/victim-channel system), so it gets its own
brainstorm → plan → subagent-driven build, same as the other features.

### Start here
1. **Invoke `superpowers:brainstorming`.** The arcade is the source of truth — **read the source
   first** (policy: see memory `genesis-version-user-is-source-of-truth`; the user grants specific
   Genesis overrides, otherwise match the asm).
2. Arcade research target (read before designing): Doink's SPUNCH-on-grounded handler
   `#spunch_lbowdrop` in `DNK.ASM` (the elbow-drop handler has a **hair-pickup sub-branch** gated
   by x-alignment to the downed foe's head). Find: the exact gate (x-alignment threshold + victim
   mode), the lift sequence/anim, and the resulting victim state (lifted → held standing? what
   mode? how is it released / what can the attacker do next?). Arcade tree:
   `/home/pablin/Games/wwf-wrestlemania` (DNK.ASM, DNKSEQ*.ASM). GMS reference:
   `/media/pablin/DATOS/JUEGOS/Wrestlemania/wwf/` (`scripts/Doink/`, `check_attack`).

### Open design questions for the brainstorm
- **Dispatch gate:** GROUNDED + SPUNCH currently maps to `elbow_drop` in the MoveTable. Hair pickup
  is ALSO GROUNDED + SPUNCH but requires x-alignment — so it needs a sub-branch/condition that
  pre-empts elbow_drop when aligned (the MoveTable is range×dir×button; x-alignment is an extra gate,
  likely handled in `Player._dispatch_normal_move` or a special-case, not the table).
- **Lift state machine:** victim ONGROUND → attached puppet (lift arc) → held-standing or a hold.
  Reuse the victim channel: `Fighter._drive_victim`, `receive_grab`, `_detach_victim`, modes
  HEADHOLD/HEADHELD/GRABBED. Decide the end state (a new hold? back to a stunned standing? then what).
- **Outcome/release:** what the attacker can do from the hold (follow-ups?), and how/when it releases.

### Building blocks already in place
- Grapple/victim-channel: `scripts/fighter.gd` (`_grappling`/`_grappled_by`, `_drive_victim`,
  `_hold_victim`, `_detach_victim`, `receive_grab`, HEADHOLD/HEADHELD, `_break_head_hold`),
  `scripts/player.gd` (`scan_specials`, `scan_headhold_followups`, `_launch_followup`).
- Dispatch: `Proximity` (X,Z-AND + GROUNDED thresholds), `MoveTable` (range×dir×btn, `Rng.GROUNDED`),
  `_current_range`/`_current_dir`/`_pressed_button` in `player.gd`.
- Move data tools: `tools/build_doink_sequences.gd` (`_strike`/`_throw`/`_grapple` recipes,
  `anim_name_back` for front/back), `tools/build_doink_movetable.gd`, `tools/build_doink_motiontable.gd`.
  Regenerate a `.tres` then `godot --headless --path . --import` (refreshes class cache + uids).
- Victim anim folders imported: `lifted`, `liftgrabbed` (+ the usual grapple ones).

### Workflow reminders
- brainstorm → `writing-plans` → `superpowers:subagent-driven-development` (fresh subagent per task,
  spec-compliance review then code-quality review, then `finishing-a-development-branch`).
- New `class_name` → run `--import` before the headless GUT runner sees it.
- Commit trailers: NO `Co-Authored-By` / "Generated with Claude Code" (user's global rule).
- Specs → `docs/superpowers/specs/`, plans → `docs/superpowers/plans/`.

### Also still deferred (not Hair Pickup)
- Aerials (flying kick, flying clothesline) + jump/Y-axis system; turnbuckle moves.
- Faithful **fling outcome** (helpless running, bounce off ropes) — needs the rope/running-stun state.
- Enemy AI + waves, ring/level regions, combo scaling.
