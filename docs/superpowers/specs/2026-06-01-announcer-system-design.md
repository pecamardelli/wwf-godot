# Announcer / Play-by-Play — Core Events (Design)

**Date:** 2026-06-01
**Status:** Design locked, pending implementation plan
**Engine:** Godot 4.x · GDScript
**Slice:** Sub-project 2 of the audio effort (combat SFX + Doink voice = sub-project 1, shipped).

---

## 1. Purpose & scope

The combat-sound engine (the `Sound` autoload, `SoundTable`/`SoundEntry`, positional SFX pool +
per-fighter voice) is live. This feature adds the **announcer / play-by-play commentary**: the
commentator reacts to notable in-match moments (big move, KO, near-KO) by playing a randomly
chosen line from a category pool, on a dedicated high-priority channel, gated so it comments on
*moments* rather than every punch. The whole subsystem is gated by a **config flag, enabled by
default**.

### In scope
- A dedicated **`Announcer`** subsystem (a Node child of the `Sound` autoload): a single global,
  non-positional `AudioStreamPlayer` on a new `Announcer` bus; highest priority.
- Three commentary categories driven by gameplay events: **IMPRESSIVE**, **KO**, **NEAR_KO** —
  each a random-line pool (`SoundEntry`), the arcade category→random-line model.
- **Cooldown + priority** gating (pure `AnnouncerPolicy`): one line at a time; off-cooldown to
  start a new line; a higher-priority event preempts a lesser line mid-sentence.
- **Config flag** `wwfmania/audio/announcer_enabled` (ProjectSettings, **default true**), editor-
  visible, runtime-settable; `announce()` is a no-op when false.
- Event hooks in `Fighter`: IMPRESSIVE on big connects (knockdown-family hits + grapple throws),
  KO on a fighter reaching 0 health, NEAR_KO on a knockdown while alive + below a low-health
  threshold.
- Generated `assets/audio/announcer_table.tres` + an import tool for the announcer WAV subset.
- GUT coverage of pure logic + the event→category wiring; headless-muted like the rest.

### Out of scope (later slices)
Per-wrestler announcer flavor (Doink/Bam/… intros, name calls, win lines) · match-start intro ·
low-health "danger" musical cue · combo/round/timer commentary · the other 7 wrestlers. The
category model is additive, so these drop in later.

---

## 2. Arcade reference (source of truth)

From `/home/pablin/Games/wwf-wrestlemania` — `SOUND.EQU`, `DCSSOUND.ASM`:

- **Priority classes** (`DCSSOUND.ASM:209-221`): every sound class has a numeric priority.
  `sp_anncer = 100<<8` is the highest — far above whoosh (8), attack grunt (12), react grunt (14),
  smack (16), wrestler speech (24), system (36-44). Announcer speech overrides/ducks lesser
  sounds and is never drowned out. **→ our Announcer channel runs at the top priority.**
- **Category → random line** (`table_sound`, `DCSSOUND.ASM:1327+`): a sound id OR'ed with `1000h`
  indexes `#random_sound_tables` — a category resolves to a *random* concrete line from a pool.
  The named pseudo-IDs `GIVE_CREDIT=-1`, `VERY_IMPRESSIVE=-2`, `IT_DOESNT_LOOK_GOOD=-4`,
  `R_IMPRESSIVE_MOVE=-5` are such categories. **→ our commentary categories are `SoundEntry`
  variant pools, reusing `pick_stream`.**
- **Named comment IDs** (`SOUND.EQU`): `THATS_GOTTA_HURT`, `WOW_0/1`, `UNBEELEVABLE_0/1/2`,
  `NICELY_DONE`, `DID_YOU_SEE_THAT`, `BOOMSHAKALAKA`, `WITH_AUTHORITY`, `MOST_IMPRESSIVE`, etc. —
  the concrete impressive-move lines.

The 294 `WWF Sources/Sounds/Comment_sound/Comment/*.wav` split into **generic** reaction/event
lines and **character-specific** lines (intros/names/wins/comebacks). This slice uses generic
lines only (the commentator is the same regardless of who fights); character flavor is later.

---

## 3. Approach (chosen: reuse the engine; add a focused Announcer node)

The Announcer reuses the shipped primitives — `SoundTable.resolve` + `SoundEntry` variant pools +
the headless self-mute — and adds only what's announcer-specific (a single non-positional channel,
a cooldown, the config flag, the priority gate). It lives in its own file so `sound_manager.gd`
stays lean; `Sound.announce(category, priority)` is the public entry point.

Rejected: **(B)** folding the announcer into `sound_manager.gd` — grows one file into two
responsibilities (in-world SFX/voice vs. global commentary). **(C)** a second autoload — the
`Sound` autoload is already the audio hub; a child Node keeps one front door and shares `muted`.

---

## 4. Components

### 4.1 Bus
Add an **`Announcer`** bus to `default_bus_layout.tres` (`Master → Announcer`), so commentary
volume is balanced independently. (`Master → SFX/Voice/Music/Announcer`.)

### 4.2 Categories (`scripts/audio/sound_category.gd`)
Add three constants above the existing voice/event range (e.g. 200+):
`ANNC_IMPRESSIVE`, `ANNC_KO`, `ANNC_NEAR_KO`. (Impacts are AMode 0-12; voice/event 100-103;
announcer 200-202 — no collisions.)

### 4.3 Announcer table (`assets/audio/announcer_table.tres`, built by a tool)
A `SoundTable` with `default` only, mapping each category → a `SoundEntry` (bus `&"Announcer"`,
the category's variant pool). Pools from real generic WAVs:
- **ANNC_IMPRESSIVE** (~12): `Awersome`, `Awersome 2`, `Boom shakalaka`, `Did you see that`,
  `Did you see that 2`, `Unbelievable`, `Unbelievable 2`, `Wow`, `Wow 2`, `Most impressive`,
  `Ka-boom`, `Look at this`, `I can't believe`, `Nice execution`.
- **ANNC_KO** (4): `And stay down`, `Game over`, `We have a winner`, `And all`.
- **ANNC_NEAR_KO** (3): `Can he get up in time`, `Get up!`, `Doink It don't look good`.

### 4.4 AnnouncerPolicy (`scripts/audio/announcer_policy.gd`, pure)
`static func should_play(cooldown_remaining: float, busy: bool, current_priority: int,
new_priority: int) -> bool`: returns true when **idle and off cooldown**, OR when
`new_priority > current_priority` (preempt a lesser in-progress line regardless of cooldown).
A new line of equal/lower priority while busy, or any line still on cooldown, is dropped.

### 4.5 Announcer (`scripts/audio/announcer.gd`, Node)
Owned by `Sound` (added as a child in `_ready`). Holds: the announcer `AudioStreamPlayer` (bus
`&"Announcer"`), the loaded `announcer_table`, `cooldown_seconds` (≈3.5), a `_cooldown_left`
timer ticked in `_process`, the current line's priority, the `enabled` flag (from ProjectSettings),
and `muted` (shared from `Sound`). `play(category, priority)`:
1. no-op if `not enabled` or `muted` (record the seam regardless, like the SFX/voice paths);
2. consult `AnnouncerPolicy.should_play(...)`; drop if false;
3. resolve the category → `SoundEntry`, `pick_stream`, play on the channel, set
   `_cooldown_left = cooldown_seconds`, record current priority + `Sound.last_announced` seam.

Priorities: **KO (3) > IMPRESSIVE (2) > NEAR_KO (1)**.

### 4.6 Config flag
At `Sound` startup, ensure `wwfmania/audio/announcer_enabled` exists (if absent,
`ProjectSettings.set_setting(..., true)` + `add_property_info` so it is editor-visible as a BOOL —
no project-file save needed at runtime), then read its current value into `Announcer.enabled`.
Runtime-settable via the same property for a future options menu. When false, `Sound.announce()`
no-ops.

### 4.7 `Sound` autoload front door
`func announce(category: int, priority: int) -> void` forwards to the `Announcer` child. Add the
`last_announced` test seam (`{category, priority}`).

---

## 5. Event hooks (`scripts/fighter.gd`)

- **IMPRESSIVE** — a *big* connect only, so it never fires on plain strikes:
  - in `receive_hit`, when the reaction family is `KNOCKDOWN`: `Sound.announce(ANNC_IMPRESSIVE, 2)`;
  - on a grapple throw slam (`_drive_victim` DAMAGE_OPP and/or `_detach_victim`):
    `Sound.announce(ANNC_IMPRESSIVE, 2)`.
- **KO** — when a hit/throw brings the victim to 0 health (`is_dead()` becomes true on this blow):
  `Sound.announce(ANNC_KO, 3)`. This is checked at the damage-apply sites (`receive_hit`,
  `_drive_victim` DAMAGE_OPP).
- **NEAR_KO** — on a knockdown while still alive and `health <= LOW_HEALTH_THRESHOLD`
  (= 30% of `Damage.LIFE_MAX`, a `Fighter` constant): `Sound.announce(ANNC_NEAR_KO, 1)`. Fires at
  the knockdown reaction, gated by the threshold so it doesn't fire on every knockdown.

Cooldown + priority collapse rapid sequences to the most important line (e.g. a KO blow that is
also a knockdown plays the KO line, not the impressive line).

---

## 6. Testing (GUT, headless)

- **`AnnouncerPolicy.should_play`** (pure): idle+off-cooldown → true; idle+on-cooldown → false;
  busy+higher → true (preempt); busy+equal/lower → false; on-cooldown+higher → true (preempt
  ignores cooldown).
- **Announcer resolution & gating**: category → expected pool resolved; `enabled=false` → no-op
  (seam not set / explicit flag); cooldown blocks a second immediate line of equal priority; a KO
  preempts an in-progress impressive line.
- **Config flag**: `wwfmania/audio/announcer_enabled` exists, defaults true, and toggling it flips
  `Announcer.enabled`.
- **Fighter wiring**: a knockdown hit fires `ANNC_IMPRESSIVE`; a lethal blow fires `ANNC_KO`; a
  low-health knockdown fires `ANNC_NEAR_KO` — asserted via `Sound.last_announced`.
- Headless-muted (the Announcer respects the same self-mute), so no real playback / leaked
  resources in the test run.

---

## 7. Architecture fit

- New pure unit `AnnouncerPolicy` joins the `scripts/audio/` helpers; the stateful `Announcer`
  Node is owned by the `Sound` autoload (one audio front door). `sound_manager.gd` gains only the
  `announce()` forwarder, the `last_announced` seam, the ProjectSettings registration, and the
  child wiring — it does not absorb announcer logic.
- `Fighter` gains a few `Sound.announce(...)` calls at existing damage/knockdown sites and one
  `LOW_HEALTH_THRESHOLD` constant; no combat-logic restructuring.
- Reuses `SoundTable`/`SoundEntry`/`pick_stream`/the headless mute — no duplication.

---

## 8. Audio effort decomposition (context)

1. Combat SFX + Doink voice — shipped.
2. **Announcer system** ← *this spec*.
3. Music + menu/event audio.
4. Per-wrestler voice + announcer flavor (other 7 wrestlers; pure data).
