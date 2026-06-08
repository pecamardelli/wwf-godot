# Fighter KO / death state — design

**Date:** 2026-06-08
**Status:** approved (pending spec review)

## Goal

A fighter whose health reaches 0 must be **defeated**, not linger as a standing idle husk. On
defeat it collapses, lies for a beat, fades out, and is removed. While defeated it is **fully
inert** — it cannot be hit, grabbed, targeted, or act. Players and enemies behave the same for now.

This closes the reported bug: after several hip tosses an opponent dropped to 0 HP but kept
standing in `NORMAL`. `_can_be_grabbed` refuses any `is_dead()` victim (so grabs whiffed) while
the strike path has no dead-check (so hits still landed) — "I can hit them but can't grab them."
The root cause is the absence of any death/KO state; this spec adds it.

## Decisions (locked with the user)

1. **On defeat:** fall, lie briefly, **fade out** once on the ground, then remove (`queue_free`).
2. **Interactions:** fully inert — no hits, grabs, targeting, or actions.
3. **Player vs enemy:** identical for now. Lives / respawn / game-over are a separate future
   system (none exists; the project is at the sandbox stage).
4. **Extensible cause:** `die()` is cause-agnostic. A future "fall in a hole" pit death just calls
   `victim.die()` — keep it in mind, don't build it now.
5. **Approach:** a dedicated `DEAD` mode + a single idempotent `die()` + a Tween for the fade.

## Current state (what we build on)

- `Fighter.mode` enum: `NORMAL, RUNNING, INAIR, ONGROUND, BLOCK, DIZZY, GRABBING, GRABBED,
  HEADHOLD, HEADHELD`. `input_allowed(m)` is true only for `NORMAL`/`RUNNING`.
- `is_dead()` is `health <= 0`. `health` defaults to `Damage.LIFE_MAX` (163).
- `AttackResolver._closest_overlapping` picks the closest overlapping fighter for an attack box;
  `_can_be_grabbed` already refuses `is_dead()` victims; the strike path does not.
- Knockdown reaction uses `droped` → `damage_lying`, ONGROUND, then a getup rise back to NORMAL.
- Targeting (`targeting.gd`, `Fighter._update_target`) already treats `is_dead()` as not-a-target.
- Hip toss damage (27) is applied via `apply_health` in `_drive_victim` at `DAMAGE_OPP`; the victim
  is released to ONGROUND in `_detach_victim`. Strike damage is applied in `receive_hit`.
- No death/KO handling exists anywhere (only a KO *announcer* line in `receive_hit`).

## Design

### 1. State

- Add `DEAD` to the `Mode` enum.
- `is_dead()` returns `mode == Mode.DEAD or health <= 0` — covers HP-zero now and future
  state-driven deaths (pits) that may not zero HP.
- `input_allowed(DEAD)` stays false (DEAD is not NORMAL/RUNNING). No change needed.

### 2. `Fighter.die()` (the single defeat entry)

Idempotent — returns immediately if `mode == Mode.DEAD`. Steps:

1. **Release grapple, both directions:**
   - If `_grappling != null` (I'm holding a victim): clear `vic._grappled_by`, set the victim to a
     safe state (`vic.mode = NORMAL` if the victim isn't itself dead), clear `_grappling`.
   - If `_grappled_by != null` (a captor holds me): clear `captor._grappling`; if the captor is
     `GRABBING`/`HEADHOLD`, set it back to `NORMAL`; clear `_grappled_by`.
2. **Cancel action:** `_player.play(null)`, `_hit_by_current_move.clear()`, zero `_react_timer`,
   `_getup_rising`, `_getup_rise_time`, `_vy`, `_height`, `velocity`.
3. **Enter DEAD:** `mode = Mode.DEAD`; `_fall_orientation = Fall.FACE_UP`; play the collapse
   animation (`droped`, which settles to its lying frame) when present, then `_refresh_flip()`.
4. **Fade timeline (Tween):** `create_tween()` → `tween_interval(ticks_to_seconds(_DEATH_LIE_TICKS))`
   → `tween_property(self, "modulate:a", 0.0, _DEATH_FADE_SECONDS)` → `tween_callback(queue_free)`.
   `modulate` on the `CharacterBody2D` propagates to the sprite child, so the whole fighter fades.

Constants (tunable): `_DEATH_LIE_TICKS` (~time on the ground before fading) and
`_DEATH_FADE_SECONDS` (~0.5 s). Seed in playtest.

### 3. Triggers

- **Strike kill** — in `receive_hit`, after `health = Damage.apply_health(...)`: if `is_dead()`,
  call `die()` and skip the normal reaction (the killing blow collapses them). The existing
  `is_dead()` KO announce still fires.
- **Throw kill** — in `_detach_victim`: if `vic.is_dead()`, call `vic.die()` instead of the
  ONGROUND/getup setup, so the throw plays out and the victim collapses + fades on landing.

### 4. Fully inert

- **One chokepoint:** `AttackResolver._closest_overlapping` skips any `victim.is_dead()`, so no
  attack box — strike or grab — ever selects a defeated fighter. (`_can_be_grabbed`'s dead-check
  stays as defense in depth.)
- `_physics_process` returns early when `mode == Mode.DEAD` (no movement, no separation, no AI),
  alongside the existing `GRABBED`/`HEADHELD` early-return. The collapse sprite + fade Tween run
  independently of the physics step.
- `Player._physics_process` and `Enemy._physics_process` skip their input/AI when `mode == DEAD`.
- Separation already ignores `is_dead()` others, so bodies are walked over while they fade.

### 5. Players = enemies (for now)

A defeated player collapses, fades, and is freed exactly like an enemy. **Known limitation:**
there is no respawn/game-over, so a freed player is simply gone — acceptable in the sandbox and
explicitly deferred to the future lives system.

## Files touched

| File | Change |
|---|---|
| `scripts/fighter.gd` | `DEAD` mode; `is_dead()`; `die()` + grapple-release helper; two triggers; `_physics_process` DEAD guard |
| `scripts/combat/attack_resolver.gd` | `_closest_overlapping` skips `is_dead()` victims |
| `scripts/player.gd` | skip input when `mode == DEAD` |
| `scripts/enemy.gd` | skip AI when `mode == DEAD` |

## Testing

- **Strike kill:** a hit that drops HP to 0 → victim `mode == DEAD`, `is_dead()` true.
- **Throw kill:** `_detach_victim` on a 0-HP victim → `die()` (DEAD), not ONGROUND/getup.
- **Inert:** a `DEAD` fighter is never returned by `_closest_overlapping` (so neither strikes nor
  grabs select it); `_can_be_grabbed` false.
- **Grapple release:** `die()` while holding a victim clears both `_grappling`/`_grappled_by` and
  frees the victim; `die()` while held releases the captor.
- **Idempotent:** calling `die()` twice is a no-op the second time (no double Tween).
- **Non-lethal:** damage that leaves HP > 0 does not trigger `die()`.
- Fade/`queue_free` timing is visual — covered by a Tween, verified in playtest, not unit-tested.
- Full GUT suite stays green.

## Out of scope (future)

- Player lives / respawn / game-over.
- Enemy waves / arena spawn management.
- Pit / hole deaths (a trigger that calls `die()`) — `die()` is built cause-agnostic to support it.
- A dedicated death/KO animation (reuse the `droped` knockdown collapse; `pin_down` art is
  available if a distinct defeated pose is wanted later).
