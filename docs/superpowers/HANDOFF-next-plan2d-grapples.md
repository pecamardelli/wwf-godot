# Handoff → Plan 2d: Grapples / Throws

**State:** SP-0 plans 1, 2a, 2b, 2c are shipped to `master` (tags `sp0-plan1-foundation` … `sp0-plan2c-targeting-control`), pushed to `github` + `gitlab`. Working tree clean. ~111 GUT tests green:
```
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -gprefix=test_ -gsuffix=.gd -ginclude_subdirs -gexit
```

## Next plan: 2d — grapples / throws (the puppet "victim channel")

The signature WWF mechanic: one fighter grabs another and drives the victim's sprite **and** position from a single master sequence. Targets for Doink: hip toss, grab & fling, neck/head grab → piledriver / joybuzzer / head slam, plus reversals.

**Start with the `brainstorming` skill** (arcade is source of truth; GMS project is the change reference), then `writing-plans`, then subagent-driven execution — same workflow as 2a/2b/2c.

### Source material (read these in brainstorming)
- `docs/superpowers/research/2026-05-27-arcade-damage-collision-reactions.md` **§4 Grapples/throws** — `LEAPATOPP` homing, `ANI_ATTACK_ON AMODE_PUPPET*` + `ANI_WAITHITOPP` (wait for connect), `ANI_ATTACHZ` attach, `MODE_GHOST|MODE_KEEPATTACHED` (victim becomes a puppet), `ANI_SUPERSLAVE2` (attacker sequence drives victim frame-by-frame), throw outcome (`HIT_THE_MAT`, `ANI_DAMAGEOPP`, `ANI_SLAVEANIM #rollout`, `ANI_DETACH` → `MODE_ONGROUND`), head-hold + `DO_REVERSAL` (`IMMOBILIZE_TIME=15`).
- `docs/superpowers/research/2026-05-27-arcade-move-animation-system.md` **§4 Grapples** + **§3 Doink moveset** (hip toss PUNCH+away,away; neck grab SPUNCH+toward,toward; grab-fling SPUNCH+away,away; joybuzzer; piledriver) + **§2 motion buffer** (`check_secret_moves`, `wrest_joystat`) — the grab *inputs*.

### Building blocks already in place (2b/2c)
`scripts/combat/`: `SequenceFrame`/`MoveSequence`/`SequencePlayer` (puppet frame-driven playback — extend for the victim channel), `AMode`/`Damage`/`Hitbox`/`AttackResolver`, `Reaction`, `MoveTable`/`Targeting`/`RelativeInput`. `Fighter` has `Mode` (add grapple modes: HEADHOLD/HEADHELD/GRABBED), `target`, `flip_h_for` (note: reaction/defence/getup art is drawn facing LEFT). Grapple victim-anim folders are imported: `hip_tossed`, `piledrivered`, `bams_pildrivered`, `joy_buzzer`, `headlocked`, `headlocks`, `lifted`, `liftgrabbed`, `flinged`, `fling`, `faceslamed`, `neckbreakered`, etc.

### Open design questions for brainstorming
- How the attacker's sequence addresses the victim's frames (a parallel victim track in `MoveSequence`, or a paired victim sequence?).
- Grab trigger for 2d: a simple range+button gate first vs. wiring the motion buffer now (likely defer the full motion buffer).
- Reversal scope (include now or defer).
- Two `side`s only so far; grapples need attach/detach bookkeeping on both fighters.

Also still deferred: motion-buffer specials (dashes/charges), combo scaling, jump/height, enemy AI + waves, ring regions.
