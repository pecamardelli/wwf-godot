# Player Moveset Completion (Ground Moves) — Design

Date: 2026-05-30

## Goal

Finish all of Doink's **ground** player-move logic, matching the arcade dispatch as closely as
we can. Aerial/jump moves and turnbuckle moves are **deferred** (they need a Y-axis/jump system
that doesn't exist yet); their anims are kept as future set-pieces.

Sources of truth: arcade asm `/home/pablin/Games/wwf-wrestlemania` (DNK.ASM, DOINK.ASM,
WRESTLE.ASM, JJXM.H, PLYR.EQU/GAME.EQU); GMS port `/media/pablin/DATOS/JUEGOS/Wrestlemania/wwf/`
(`scripts/Doink/`, `doink_get_attacks`, `check_attack`). This design is grounded in a close read
of those files (see the dispatch model below).

## Arcade dispatch model (what we match)

Per tick, in order (`move_doink` DNK.ASM:1320-1333):
1. **`check_secret_moves` FIRST** (WRESTLE.ASM:4851) — button-held charge checks, then pattern
   matching against a **16-entry input history** (`wrest_joystat`), each entry = `(tick<<16) |
   input`, with per-move **time windows** (10–60 ticks). Our `Player.scan_specials` +
   `scan_headhold_*` already run before normal dispatch — same order.
2. **Mode dispatch** (`mode_normal`/`mode_running`/`mode_onground`…). Helpless modes don't read input.
3. **Action table by `BUT_VAL_DOWN`** (button pressed THIS frame) → a handler.
4. **Proximity + opponent-state** via the **JJXM macro** (JJXM.H:12-28): `X ≤ DX AND Z ≤ DZ → close`,
   else far, with thresholds that **depend on the opponent's mode** (NORMAL `50/45`; ONGROUND
   `160/140`). Opponent-grounded selects grounded moves (stomp / elbow drop).

Charge = button held ≥ a threshold (joybuzzer: 100 ticks). Repeat = same button ×N within a
window (boxing glove: PUNCH ×7 within 60 ticks), expressed as a 7-entry motion pattern.

## Scope: Doink ground moveset (arcade-authoritative)

Button column uses the arcade's logical buttons (PUNCH, SPUNCH, KICK, SKICK, BLOCK). **Decision:
match the arcade button assignment exactly** (§ "Button reconciliation"), even where it changes
our 5 already-shipped mappings.

| Move | Button | Stick / charge / repeat | Proximity / opp-state | Kind |
|---|---|---|---|---|
| Punch | PUNCH | any | far (NORMAL) | normal |
| Head Butt | PUNCH | any | close (NORMAL) | normal |
| Kick | (per asm) | any | far | normal |
| Knee | (per asm) | any | close | normal |
| Stomp | (per asm) | any | opp ONGROUND | normal/grounded |
| Spin Kick | SPUNCH | any | far | normal |
| Elbow Drop | SPUNCH | any | opp ONGROUND (close) | normal/grounded |
| Super Stomp | SPUNCH | any | opp ONGROUND | normal/grounded |
| Slap-Butts | SPUNCH | DOWN | close | normal/directional |
| Uppercut | SPUNCH | DOWN | close | normal/directional |
| Hair Pickup | SPUNCH | any | opp ONGROUND, x-aligned | grapple-like (own task) |
| Hip Toss | PUNCH | AWAY,AWAY | close window | secret/grab (wired) |
| Grab & Fling | SPUNCH | AWAY,AWAY | close window | secret/grab (wired) |
| Neck Grab | SPUNCH | TOWARD,TOWARD | close window | secret/grab (wired) |
| Ear Slap | PUNCH | TOWARD, D-TOWARD, DOWN | ≤50-tick window | secret |
| Hammer | SKICK | TOWARD,TOWARD | ≤32-tick window | secret |
| Charge Buzz (joybuzzer) | PUNCH held ≥100 | — | head-hold | charge (wired) |
| Boxing Glove | PUNCH ×7 | any | ≤60-tick window, standing | repeat |
| Block | BLOCK | — | — | wired |

Exact button bits, stick masks (`J_TOWARD`/`J_AWAY`/`J_DOWN`/`J_DOWN_TOWARD`/`J_ALL`), thresholds,
and window lengths are read from the named asm tables during planning and encoded as **data** in
our move/motion tables — they are inputs to the build tools, not free-form requirements.

Already wired (verify against arcade, adjust): Punch, Head Butt, Uppercut(→ becomes SPUNCH+DOWN),
Kick, Big Boot(running/SPUNCH), Hip Toss, Grab & Fling, Neck Grab, Piledriver, Head Slam, Joybuzzer.

## Architecture

Extend the existing pure-table + thin-`Player` design; do not refactor working dispatch.

1. **Proximity model** (`scripts/combat/`): replace the single `_CLOSE_GATE` distance with a pure
   helper computing close/far from **(|Δx|, |Δz|) AND thresholds keyed by the opponent's mode**
   (NORMAL, ONGROUND, RUNNING…). Thresholds from JJXM. `Player._current_range()` uses it and
   returns the range bucket, including a **GROUNDED** bucket when the target is `ONGROUND`.
   - `MoveTable` gains the GROUNDED range value (it already supports range × dir × button with a
     NEUTRAL/range fallback). Directional entries (TOWARD/AWAY/DOWN) are pure data.
   - **Drop `Dir.UP`** — unused by Doink.
2. **Button reconciliation**: read the arcade bit definitions (PLYR.EQU/GAME.EQU) and map our
   input actions + `MoveTable.Btn` to the arcade's PUNCH/SPUNCH/KICK/SKICK semantics. Re-point the
   already-wired normal moves to their arcade buttons (e.g. Spin Kick on SPUNCH, Kick on its
   arcade button), updating `_pressed_button`, the input map, and the move-table builder. Note:
   this re-tunes the shipped button feel — intended.
3. **Boxing Glove (repeat)**: confirm `MotionMatcher`/`MotionBuffer` handle a 7-entry,
   `J_ALL`-masked, 60-tick pattern. If yes → pure data (a `boxing_glove` motion). If the matcher
   caps entries below 7 or can't express "same button ×N within window," extend it minimally (a
   small, unit-tested change) — prefer reusing the existing pattern mechanism over a new matcher.
4. **Per-move data unit** (the bulk): each move = a `MoveSequence` `.tres` (frames from the
   imported anim folders — elbow_drop, mid_kick, stomp, slap, power_kick, boxing_glove_smash,
   headbutt, uppercut, … — plus hitbox window + `attack_mode`), an `AMode` family + `Damage` entry
   + victim `Reaction`, and a `MoveTable`/`MotionTable` entry. Frame timing/hitboxes are seeded
   from arcade/GMS and tuned in playtest (the established workflow).
5. **Hair Pickup**: a grab on a grounded foe (grapple-like) — its own task; include/defer decided
   when reached. Not a blocker for the rest.

## Testing

- Pure units get GUT tests: the proximity helper (per-mode (X,Z)-AND buckets incl. GROUNDED),
  the button mapping, and the boxing-glove pattern match (7 within window; fewer/older = no match).
- Each wired move gets a dispatch test: given (button, stick, range/opp-mode) → the expected
  sequence fires (mirroring `test_move_table` / `test_player*`).
- Existing combat/grapple tests stay green; button-remap test updates are expected and called out.

## Out of scope

- Aerial/jump moves (Flying Kick, Flying Clothesline, Belly Flop) — need the Y-axis/jump system.
- Turnbuckle moves (TB Spin Kick, dive/buckle drops) — kept as future set-pieces (no ring).
- `Dir.UP` (unused by Doink).
- Enemy AI, waves, ring regions, combo scaling — separate features.
