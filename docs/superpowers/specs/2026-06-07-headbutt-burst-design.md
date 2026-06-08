# Headbutt burst + slow low-punch headbutt — design

**Date:** 2026-06-07
**Status:** approved (pending spec review)

## Goal

When Doink is at CLOSE range to a standing fighter, the **high-punch** button drives a
**burst of headbutts** — a mash-to-extend chain, capped at **4 in a row**. The burst's hits do
**not** pop the victim; the **hit that ENDS the burst** applies the upward pop (the headbutt hop
we already ship). Separately, the **low-punch** button at CLOSE range does the **same headbutt,
a bit slower and more powerful, as a single hit that pops** — it does NOT engage the burst.

Arcade source of truth: `dnk_4_combo_butt_anim` (DNKSEQ2.ASM:548-652) is a 4× `AMODE_HDBUTT`
combo; the close punch→headbutt routing is `DNK.ASM:1520-1584`. Per project convention the user's
requested behavior (mash-to-extend, pop only at the burst's end, no per-hit pop) overrides the
arcade's exact per-hit `ANI_SETOPPVELS` detail.

## Decisions (locked with the user)

1. **Trigger model:** mash-to-extend. Each high-punch press lands one headbutt; pressing again
   while the current hit plays chains the next, capped at 4.
2. **Buttons:** `high_punch` (close) = burst; `punch`/low-punch (close) = single slow/strong
   headbutt. (Today: `punch`→headbutt, `high_punch`→slap.)
3. **Pop timing:** whichever hit ENDS the burst pops (stop at 2 → 2nd pops; reach 4 → 4th pops).
   Intermediate hits land as a non-pop dizzy stun.
4. **Low-punch single:** pops (keeps today's `causes_dizzy` behavior), just slower + stronger.
5. **Implementation:** approach A — discrete chained moves + a pure `BurstState` + a deferred
   ender-pop decided at the move-end boundary (no timers).

## Current architecture (what we build on)

- Moves are `MoveSequence` resources (frames + `attack_mode` + `causes_dizzy`), played by
  `SequencePlayer`; `uninterruptable = true` by default, so no new move starts mid-move.
- Input → move via `MoveTable` keyed **(range × dir × button)**. `Player._dispatch_normal_move()`
  runs only when `input_allowed(mode) and not is_attacking()`; on the next press after a move ends,
  the table is looked up again. CLOSE+NEUTRAL+LOW_PUNCH→`headbutt`, CLOSE+NEUTRAL+HIGH_PUNCH→`slap`,
  CLOSE+DOWN+HIGH_PUNCH→`uppercut`.
- `Fighter.receive_hit()` resolves damage (`Damage.resolve(move.attack_mode, ...)`) and the victim
  reaction (`Reaction.resolve(family, hit_dir, move.causes_dizzy)` → `_enter_reaction`).
- The DIZZY reaction already plays `headbutted_salted`, recovers on clip-end (`anim_timed`), and
  applies the hop. A re-hit during a reaction restarts the clip + pop from frame 0 (shipped).
- No combo/chain/buffer system exists today.

## Design

### 1. Moves (reuse existing headbutt art — no new sprites)

- **`headbutt_burst`** (NEW) — the burst hit. `attack_mode = HDBUTT`, anim `headbutt_front/back`,
  fast (2 ticks/frame), short. `causes_dizzy = true`, `victim_pop = false` (dizzy stun, NO hop).
  Mapped to **CLOSE + NEUTRAL + HIGH_PUNCH** (replaces `slap` only in that cell).
- **`headbutt`** (RETUNED) — the single low-punch. Stays at **CLOSE + NEUTRAL + LOW_PUNCH**.
  Slower (3 ticks/frame), `damage_override` for more power, `causes_dizzy = true`,
  `victim_pop = true` (pops). Single hit, no burst.
- Unchanged: far `slap` (NORMAL+HIGH_PUNCH), `uppercut` (CLOSE+DOWN+HIGH_PUNCH), grounded elbow.

### 2. `MoveSequence` additions (`scripts/combat/move_sequence.gd`)

- `@export var victim_pop: bool = false` — when this move's hit causes the dizzy reaction, also
  apply the upward hop. (Separates "dizzy stun" from "dizzy + pop".)
- `@export var damage_override: int = 0` — base damage to use instead of `DamageTable.base(amode)`
  when > 0 (still runs through the offense scaling in `Damage.resolve`).

### 3. Reactions (`scripts/combat/reaction.gd`)

- `resolve(family, side, dizzy, pop := false)`. DIZZY branch always returns `headbutted_salted`,
  DIZZY mode, `anim_timed`, small knockback; **`hop = HDBUTT_HOP_YVEL` only when `pop` is true**,
  else `hop = 0`.
- `Fighter.receive_hit()` calls `Reaction.resolve(family, hit_dir, move.causes_dizzy, move.victim_pop)`.

So: burst intermediate (`victim_pop=false`) → dizzy stun, no hop; single low-punch
(`victim_pop=true`) → dizzy + hop. The re-hit restart keeps the victim in `headbutted_salted`
throughout a mashed burst (coherent headbutt look); knockback stays small so the victim doesn't
drift out of CLOSE mid-burst (tune in playtest).

### 4. `BurstState` (NEW pure class, `scripts/combat/burst_state.gd`)

Holds only the counting/decision logic so it is unit-testable in isolation:

```
const MAX := 4
var count: int = 0                 # burst hits started this chain (0 = idle)
var continue_pressed: bool = false # a high-punch press was buffered during the current hit

func is_active() -> bool   -> count > 0
func start()               -> count = 1; continue_pressed = false
func note_continue()       -> if count < MAX: continue_pressed = true
func resolve_end() -> bool -> # called at a burst hit's move-end:
                              #   if continue_pressed and count < MAX: count += 1; continue_pressed = false; return true (CHAIN)
                              #   else: return false (END)
func reset()               -> count = 0; continue_pressed = false
```

### 5. Burst wiring (`scripts/player.gd`)

State: a `BurstState` and the last burst victim reference.

- **Buffer continue:** every frame, if a burst is active and `high_punch` was just pressed,
  `burst.note_continue()`.
- **Start:** in dispatch, when the looked-up move is `headbutt_burst` and no burst is active,
  `burst.start()` then `start_move(headbutt_burst)`.
- **Chain-or-end (at move-end):** in the `input_allowed and not is_attacking()` block, BEFORE the
  generic dispatch, if `burst.is_active()`:
  - capture the victim from `_hit_by_current_move` (still holds the finished move's hits).
  - if the attacker is not in NORMAL (it got hit / interrupted) → `burst.reset()` (no pop).
  - else if `burst.resolve_end()` is true AND still close to a valid standing target →
    `start_move(headbutt_burst)` (chain).
  - else → END: if the victim is valid and alive, `victim.pop_from_headbutt(self)`; `burst.reset()`.

This consumes the frame (return after `super(delta)`) so it never collides with `_dispatch_normal_move`.
After the ender pop the victim is dizzy/airborne → not a CLOSE standing target → re-bursting is
naturally gated. A fresh burst may start afterward (the "4 in a row" cap is per chain).

### 6. `Fighter.pop_from_headbutt(attacker)` (`scripts/fighter.gd`)

Applies the ender pop without a strike: compute `hit_dir` = sign(self.x − attacker.x) (push away),
build `Reaction.resolve(AMode.Family.HEAD_HIT, +1, true, true)` (dizzy + pop), and call
`_enter_reaction(r, hit_dir)`. The shipped re-hit restart makes the transition from the last
intermediate stun smooth.

### 7. Damage (`scripts/combat/damage.gd`)

`resolve(amode, repeat, blocked, base_override := 0)` — when `base_override > 0`, use it as the
base instead of `DamageTable.base(amode)` (offense scaling unchanged). `receive_hit` passes
`move.damage_override`.

## Files touched

| File | Change |
|---|---|
| `scripts/combat/move_sequence.gd` | + `victim_pop`, + `damage_override` |
| `scripts/combat/reaction.gd` | `resolve(... , pop := false)`; hop gated by `pop` |
| `scripts/combat/burst_state.gd` | NEW pure class |
| `scripts/combat/damage.gd` | `resolve(... , base_override := 0)` |
| `scripts/fighter.gd` | `receive_hit` passes `victim_pop` + `damage_override`; new `pop_from_headbutt` |
| `scripts/player.gd` | burst wiring (buffer / start / chain-or-end / ender pop) |
| `tools/build_doink_sequences.gd` | add `headbutt_burst`; retune `headbutt` |
| `tools/build_doink_movetable.gd` | CLOSE+NEUTRAL+HIGH_PUNCH → `headbutt_burst` |
| `assets/sequences/doink/*.tres`, `assets/movetables/doink.tres` | regenerated by the builders |

Regen: run the two builder scripts headless, then `--import`.

## Testing

- **`test/unit/test_burst_state.gd`** (NEW): start→count 1; note_continue + resolve_end chains and
  caps at 4; resolve_end without a continue ends; reset clears. Pure logic, no scene.
- **`test/unit/test_reaction.gd`** (update): DIZZY + `pop=true` → hop > 0; DIZZY + `pop=false` →
  hop == 0; both still `anim_timed` + `headbutted_salted`.
- **Move table**: assert CLOSE+NEUTRAL+HIGH_PUNCH resolves to `headbutt_burst`, CLOSE+NEUTRAL+
  LOW_PUNCH to `headbutt`, NORMAL+HIGH_PUNCH still `slap`.
- **Damage**: `resolve` with `base_override` uses the override × offense scaling.
- Fighter-level `pop_from_headbutt` is exercised indirectly; a focused scene test is optional.
- Full GUT suite stays green.

## Out of scope (possible follow-ups)

- Recovery-cancel (approach C) for a snappier, less staccato burst rhythm — layer on later if
  playtest wants it.
- Per-hit `headbutted_salted` vs `facepunched` tuning, exact knockback/damage values — playtest.
- Bursts for non-Doink wrestlers (their close punch is a real punch, same mechanic, different art).
