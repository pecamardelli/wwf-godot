# Enemy + AI — First Fighting Opponent (Design)

**Date:** 2026-06-01
**Status:** Design locked, pending implementation plan
**Engine:** Godot 4.x · GDScript
**Slice pillar:** Advances SP-0 pillar 4 ("Multi-attacker AI") — see
`docs/superpowers/specs/2026-05-26-vertical-slice-design.md`.

---

## 1. Purpose & scope

The combat layer is deep and well-tested (strikes, grapples/throws, headhold, hair pickup,
knockdown/getup, depth movement, ~275 GUT tests), but it lives in `Sandbox.tscn` as one
`Player` versus a passive dummy. There is **no AI-driven opponent** — nothing fights back.

This feature delivers the keystone of the genre: **one AI-driven `Enemy` that genuinely
fights.** It approaches the player, selects **strikes and grapples** (full wrestler), defends
(block/reversal), reacts to being hit/grabbed/knocked down, gets up, and dies — and can be
beaten by the player, who is itself grab-able.

The enemy's behavior is defined by a **rich, data-driven `AIProfile`** (personality +
competence) layered with a **4-stance mood system**. The arcade's CPU/"drone" brain
(`DRONE.ASM`) is the behavioral reference for move-selection feel, timing, and the
crowd-difficulty scaling; the *moves themselves* are the existing arcade-faithful sequences.

### In scope
- `Enemy extends Fighter` driven by a pure `AIController` (Approach B — see §3).
- `AIProfile` resource (full personality surface, §4) with one shipped instance (`basic_doink`).
- 4-stance mood FSM: SPACING / PRESSING / KAMIKAZE / CALCULATOR (§5).
- Full-wrestler repertoire: strikes (MoveTable) **and** grapples/throws (the enemy initiates
  grabs; the player can be grabbed).
- Defense: stance- and skill-scaled block + grapple reversal.
- Crowd-difficulty **hook** (block/hold scaling by ally count) — wired and correct, but a no-op
  at the single-enemy count this feature ships.
- Demonstrated in `Sandbox.tscn`; verified by GUT (pure `decide()` unit tests + a headless
  integration test).

### Out of scope (later features)
Wave spawning · attack-token manager · multiple simultaneous enemies/crowds ·
`LevelController` / `Arena` · `CoopCamera` · visual `EnemyVariant` (scale / cloth-recolor /
voice pitch) · pit hazard.

---

## 2. Arcade reference (source of truth for feel)

From `/home/pablin/Games/wwf-wrestlemania/DRONE.ASM` (TMS34010), with `PLYR.EQU` / `GAME.EQU`:

- **Brain (`drone_main`):** per-frame, decrements a delay counter (`DRN_DELAY`); when it expires,
  runs block-detection then selects a new action. State + script-table hybrid.
- **Aggression as a mode (`DRN_MODE`, −3..+2):** random-walks between passive (hangs back, seeks
  distance) and aggressive (pursues) roughly every ~5.3 s. `drn_retreat` sets a far seek distance
  and loops until a 1-in-32 random break. **This is the primitive root of our named stances.**
- **Positioning:** 16-direction compass (`DRN_SEEKDIR` 0–15) × 5 distance bands
  (`DRN_SEEKDIST` 0–4) toward/away from the opponent.
- **Attack selection:** distance-gated per-character tables (short ≤100 px, medium 100–180 px,
  long >180 px, on `max(Xdist, 2×Zdist)`), random index within the band's pool, mode-matched
  (my-mode × his-mode).
- **Reaction cadence:** `DRN_DELAY` ~4–50 ticks per action; **minimum 15 ticks after a block**.
- **Block %** = `base(skill) + per-repeated-attack bonus − 32 × (extra teammates)`, random-rolled.
  Tables: `blkbase_t` (skill 0–5 → 10..75%), `blkatk_t` (repeat 0..5+ → +0..+50%).
- **Reversals:** on leaping/grapple attacks, chance ≈ `skill / 4`. Head-hold / reverse escape
  delays come from skill-indexed tables (`sklhhdly_t`, `sklhrdly_t`, 150→13 ticks) and **grow with
  extra teammates** (+22 ticks), with a 12% "skip delay" only in 1-on-1.
- **Skill (`DRN_SKILL`, 0–29):** the master competence knob; `≈ (difficulty − 2) × 2 + 8` plus
  ladder/streak/round adjustments, clamped 0–29.

**Crowd-difficulty rule (confirmed in source):** more teammates ⇒ each CPU blocks less and holds
longer ⇒ a mob is an easy pushover, while 1-on-1 it blocks almost everything and reverses fast.
Code comment: *"In multi-wrestler matches, delay longer on power moves from headhold or revs."*

The macro-structure (spawning, scrolling, crowds) is **genre convention**, not from the arcade.
We seed the per-enemy *feel* (skill, mode, delay, block/reversal, distance bands) from the source
and wrap it in a genre-appropriate stance layer.

---

## 3. Architecture (Approach B: pure decision core + thin body)

The AI does **not** synthesize keyboard input or motion-buffer patterns. It is a pure decision
function that returns a high-level intent; the `Enemy` applies that intent by calling the same
body methods the player ultimately calls. This was chosen over a "virtual input" approach because
the `AttackResolver` already resolves hits **and grabs** by box overlap for *any* fighter in the
`fighters` group (it is side-agnostic), so an AI-started grapple sequence connects identically to a
player's — no fragile motion-pattern synthesis required.

```
Enemy._physics_process(delta)                         [scripts/enemy.gd — stateful glue]
  1. build Perception { self_mode, self_health, target, distance_x/z,
                        target_attacking, ally_count, events }
  2. AIController.decide(perception, profile, ai_state) -> AIIntent      [PURE]
        (gated by ai_state.delay counter — only re-decides when it expires)
  3. apply AIIntent via SHARED body methods:
        move_dir  -> walk toward/away (existing Fighter movement)
        STRIKE    -> dispatch_strike(range, dir, button) = MoveTable.lookup + start_move
        GRAB      -> start_move(grapple_seq)
        BLOCK     -> enter Mode.BLOCK
        IDLE      -> hold
  4. super(delta)
              │
   AttackResolver (existing, unchanged): box overlap -> receive_hit / receive_grab,
   side-agnostic, so enemy grabs player and player grabs enemy identically.
```

### Units

| Unit | File | Kind | Responsibility |
|---|---|---|---|
| `AIProfile` | `resources/ai_profile.gd` | Resource | Personality + competence data (§4). Inspector-editable. |
| `AIIntent` | `scripts/combat/ai_intent.gd` | Plain data | `move_dir: Vector2`, `action: Action`, `button: int`, `move_id: String`, `want_run: bool`. |
| `AIController` | `scripts/combat/ai_controller.gd` | Pure helper | `decide(perception, profile, ai_state) -> AIIntent` + stance FSM. No scene-tree access; RNG injected. |
| `Enemy` | `scripts/enemy.gd` | `extends Fighter` | Perception build + intent application. Mirrors `Player` as the other `Fighter` subclass. |

### Shared dispatch (no forked combat logic)
`Player._dispatch_normal_move` currently inlines the strike path (`MoveTable.lookup(range, dir,
btn)` → `start_move`). Extract the table-lookup → sequence step into a shared helper (a static
function on `MoveTable`/a small dispatch helper, or a protected `Fighter` method) that **both**
`Player` and `Enemy` call, so strike resolution lives in exactly one place. `start_move`,
`receive_grab`, `current_attack_box`, `_player` (SequencePlayer) already live on `Fighter` — the
enemy inherits them; nothing new is needed for grabs to connect.

---

## 4. `AIProfile` — the personality surface

Resource fields (all inspector-editable; ranges noted):

| Field | Type | Meaning |
|---|---|---|
| `skill` | `int` 0–29 | Master competence. Scales block%, reversal chance, and reaction speed (arcade `DRN_SKILL`). |
| `aggression` | `float` 0–1 | Base bias toward pressing vs spacing (independent of transient stance). |
| `preferred_range` | `enum {CLOSE, MID, LONG}` | The distance band the fighter tries to hold when not committing. |
| `run_tendency` | `float` 0–1 | Likelihood to run/dash to close distance rather than walk. |
| `special_frequency` | `float` 0–1 | How often it reaches for grapples/specials vs basic strikes. |
| `limb_bias` | `float` 0–1 | Strike-family weighting: 0 = fists (punch family), 1 = legs (kick family). |
| `block_skill` | `float` 0–1 | Defense competence multiplier on the skill-derived block%. |
| `reversal_skill` | `float` 0–1 | Multiplier on the `skill/4` grapple-reversal chance. |
| `backoff_tendency` | `float` 0–1 | Propensity to retreat/space after exchanges or hits. |
| `patience` | `float` 0–1 | How long it idles/circles before committing to an action. |
| `reaction_delay` | `Vector2i` (min,max ticks) | Decision cadence; the "beatable" knob. Floor of 15 ticks applied after a block (arcade). |
| `stance_weights` | `Dictionary {Stance: float}` | Re-roll weights for the mood FSM — the core of personality range. |
| `stance_duration_scale` | `float` | Multiplier on the base ~5.3 s stance hold time. |
| `enabled_stances` | `Array[Stance]` | Which stances this fighter may enter (e.g. a berserker omits CALCULATOR). |

Personality emerges from data: a *berserker* weights KAMIKAZE/PRESSING high and disables
CALCULATOR; a *technician* lives in CALCULATOR/SPACING with high `block_skill`/`reversal_skill`;
a *kicker* sets `limb_bias` high; a *runner* sets `run_tendency` high. `preferred_range`,
`limb_bias`, and `run_tendency` all still apply *within* whatever stance is active.

**Shipped instance:** `resources/ai_profiles/basic_doink.tres` — low `skill`, PRESSING-heavy
`stance_weights`, KAMIKAZE disabled or low, modest `block_skill`, fists-leaning `limb_bias`,
`preferred_range = CLOSE`. A beatable but believable first opponent.

---

## 5. Stance (mood) system

A **stance is a temporary mood that modulates the profile's base knobs**: the profile says *who
the fighter is*, the stance says *what they are doing right now*. It is the named, richer
descendant of the arcade's `DRN_MODE`.

| Stance | Behavior | Modulation | Arcade root |
|---|---|---|---|
| **SPACING** (cool-down) | Backs off to `preferred_range`, circles/walks around "like a real fight," low attack rate, will block. | ↑ seek distance, ↓ attack rate, ↑ block bias | passive `DRN_MODE`<0 + `drn_retreat` |
| **PRESSING** (default) | Standard approach-and-attack at the arcade's normal cadence. | baseline | aggressive `DRN_MODE`≥0 |
| **KAMIKAZE** | Relentless rush, near-zero blocking, high special frequency — high-risk chaos. | ↓↓ block, ↑ attack rate, ↑ special freq, ↓ seek distance | extrapolated |
| **CALCULATOR** | Holds at range, blocks/reverses more, waits for an opening then punishes, baits. | ↑ block/reversal, ↑ patience, punish-on-whiff | high-skill block/reversal |

### Transitions (part of pure `decide()`)
- **Timed:** a stance holds for `stance_timer` (base ~5.3 s × `stance_duration_scale`, jittered),
  then re-rolls weighted by `profile.stance_weights` restricted to `enabled_stances`.
- **Event-driven early flips** (personality-weighted): took a big hit → SPACING or KAMIKAZE
  (by aggression); low health → CALCULATOR or KAMIKAZE; got mobbed (ally_count > 1) → SPACING.
- The active stance is read by every downstream step (positioning, action roll, defense) to shift
  its thresholds. Stance lives in `AIState` (`current_stance`, `stance_timer`); the FSM is a pure
  function of `(ai_state, profile, perception, injected_roll)`.

---

## 6. `AIController.decide()` pipeline (pure)

Runs only when `ai_state.delay` has expired (otherwise the prior intent / hold persists), giving
the arcade reaction cadence. Steps:

1. **Stance FSM** — advance/re-roll/early-flip `current_stance` (§5).
2. **Positioning** — compute `move_dir` toward/away to reach the stance-adjusted target distance
   (arcade 16-dir seek; SPACING applies the `drn_retreat`-style far hold with a random break).
   Set `want_run` from `run_tendency` when closing a large gap.
3. **Action roll** — by distance band (short ≤100 / mid ≤180 / long, in arcade units via
   `ArcadeUnits`), weighted pick among {strike, grapple, none}. `special_frequency` weights
   grapple; `limb_bias` weights punch- vs kick-family within strikes; stance scales attack rate.
   Output the chosen `STRIKE` (button + resolved range/dir) or `GRAB` (`move_id`).
4. **Defense override** — if the target is attacking and in range: block when
   `roll < base_block(skill, block_skill) + repeat_bonus − 32 × (ally_count − 1)`; on a grapple
   threat, reverse when `roll < (skill/4) × reversal_skill`. Defense pre-empts the action roll.
5. **Set next delay** — `randi_range(reaction_delay.x, reaction_delay.y)`, floored to 15 after a
   block (arcade).

All randomness flows through an **injected roll source** (seed or an array of rolls) so unit tests
are deterministic. Ported arcade tables/thresholds become named constants with source citations.

**Crowd-scaling hook:** the **block** term `− 32 × (ally_count − 1)` is implemented now (in
`block_chance`, with `ally_count` plumbed through perception). At this feature's single-enemy
count `ally_count == 1` it is an exact no-op; it activates automatically when a future feature
spawns multiple enemies. The sibling arcade term — the `+22`-tick **hold/reversal-delay** scaling
per extra teammate — is **deferred to the multi-enemy feature** (it has no effect at one enemy and
the reversal-delay path is not yet ally-count-aware); it will be implemented and tested there.

---

## 7. `Enemy` integration

- `class_name Enemy extends Fighter`; `side = Fighter.Side.ENEMY`; joins the `fighters` group so
  `AttackResolver` sees it.
- `@export var profile: AIProfile` and an internal `AIState` + `AIController`.
- `_physics_process(delta)`: build `Perception` (reuse `_update_target` and the existing distance
  helpers; `ally_count` = count of living same-side fighters engaging the shared target — 1 here),
  call `decide()` honoring `ai_state.delay`, apply the `AIIntent`, then `super(delta)`.
- **Grabs need no special handling:** `start_move(grapple_seq)` + walking into range lets
  `AttackResolver` call `victim.receive_grab(...)`. The player, being a `Fighter`, is already
  grab-able and already exposes `receive_grab`/`_drive_victim`.
- `Sandbox.tscn` gains an `Enemy` instance (basic_doink profile) opposite the player for the
  playtest/integration target.

---

## 8. Testing (GUT)

**Pure unit tests** (`AIController`, deterministic via injected rolls):
- Stance FSM: timed re-roll honors `stance_weights`/`enabled_stances`; event flips fire on big
  hit / low health / mobbed.
- Positioning: produces toward/away `move_dir` to reach the stance-adjusted distance; SPACING
  backs off.
- Action roll: distance band selects from the right pool; `limb_bias` skews punch vs kick;
  `special_frequency` skews toward grapples.
- Defense: block roll uses `base(skill)+repeat−32×(allies−1)`; reversal uses `skill/4 ×
  reversal_skill`; crowd term verified by varying `ally_count`.
- Reaction cadence: no re-decision while `delay > 0`; 15-tick floor after a block.

**Resource test:** `basic_doink.tres` loads; fields within expected ranges.

**Integration test** (headless scene, `fighters` group + `AttackResolver`):
- Enemy approaches a dummy target and lands a strike (target health drops).
- Enemy performs a grab on the player (player enters a grabbed mode via `receive_grab`).
- Enemy takes a hit → knockdown → getup; dies at 0 health.

Run headless:
`godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit`
New `class_name`s require `godot --headless --path . --import` before the runner sees them.

---

## 9. Open tuning items (playtest, not unit-testable)

- `basic_doink` numbers (skill, stance weights, reaction delay) tuned by feel for "beatable but
  believable."
- Stance hold duration / jitter and the back-off distance for SPACING to read as "circling like a
  real fight."
- Distance-band thresholds in our world units (seeded from arcade px via `ArcadeUnits`, then tuned).

---

## 10. Risks & notes

- **Shared dispatch extraction** touches `Player`; keep the player's behavior identical (regression
  guarded by the existing player tests) — the extraction is mechanical.
- **Grab feel for an AI initiator** — the enemy must reach grapple range and commit; tune the
  approach so grabs don't whiff. The connection mechanism itself is proven (resolver is
  side-agnostic).
- **Determinism** — every random decision must route through the injected roll source, or the unit
  tests become flaky. This is a hard rule for `AIController`.
- **Crowd hook is inert now** — verified by test at `ally_count = 1` (no-op) and `> 1` (penalty
  applied), so the future multi-enemy feature inherits correct behavior for free.
