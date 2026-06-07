# Per-Move Sound Mapping — Design Spec

**Date:** 2026-06-07
**Goal:** Replace the coarse, family-keyed combat-sound model with a per-move, JSON-driven model that
fires four buckets — **swing / hit / attack / pain** — with weighted variant selection and
probabilistic (sometimes-silent) voices. Authored by editing `sound_mapping.json` and re-running a
build tool.

**Fidelity note:** The arcade `MASTER_SOUND_TABLE` already uses this exact 4-column per-move structure
(`whsh / grunt / smak / ouch`, `DCSSOUND.ASM:1075`). Two deliberate divergences from the arcade,
chosen by the user (Genesis-flavored restraint — the user grants specific Genesis-style overrides):
- **Weighted** variant selection (`precedence`) instead of the arcade's uniform random (`RNDRNG0`).
- **Probabilistic** voices (`probability`) — voices do NOT play on every hit (the arcade always plays
  them; the Genesis version is channel-limited; we want the restraint by design).

---

## 1. Scope

- New, **isolated** per-move sound model that runs **alongside** the current `SoundTable`. The current
  table is untouched and still serves body-drops, the announcer, and every move NOT in the JSON.
- The JSON ships with two moves mapped (`punch`, `headbutt`); the system is general — more moves are
  added by editing the JSON.
- **Non-goals:** no change to the announcer, body-drop, or per-frame `ANI_SOUND` paths; no channel
  preemption/priority system (the arcade's separate `sp_*` priority axis is out of scope); no runtime
  JSON parsing (build-time only).

---

## 2. Source data: `sound_mapping.json`

The JSON is moved into the repo at `tools/sound_mapping.json` (version-controlled). Shape, keyed by
**move id**:

```json
{
  "punch": {                          // move id (was "mid_punch" in the draft; renamed to the id)
    "swing": [ {"file": "swing4.wav", "precedence": 50}, ... ],   // universal whoosh pool
    "hit":   [ {"file": "punch2.wav", "precedence": 50}, ... ],   // universal impact pool
    "attack": { "doink": [ {"file": "Doink attack 8.wav", "probability": 0.18}, ... ] },
    "pain":   { "doink": [ {"file": "Doink pain 8.wav",  "probability": 0.2 }, ... ] }
  },
  "headbutt": { ... }
}
```

- **`swing` / `hit`**: universal arrays (not per-wrestler). `precedence` = a relative selection weight.
- **`attack` / `pain`**: keyed by the **performing wrestler** (`attack` = that wrestler's effort grunt;
  `pain` = the victim cry elicited by that wrestler's move — keyed by attacker for now since the cast is
  effectively all Doink). `probability` = per-variant chance.
- Filenames are a **normalized** form (lowercase, no spaces): `swing4.wav` resolves to the real source
  file `Swing 4.wav`, `punch2.wav` → `Punch2.wav`.
- The draft `mid_punch` key is renamed to `punch` to match the move id (option (a)).

---

## 3. Semantics

### 3.1 Weighted selection (swing, hit) — `chance_gated = false`
Exactly one variant plays per event. Variant `i` is chosen with probability `weight[i] / sum(weights)`.
Example: swing `50/50/30` → swing7 plays `30/130 ≈ 23%` of swings.

### 3.2 Chance selection (attack, pain) — `chance_gated = true`
Voices are sometimes silent. Let `S = sum(probabilities)`:
- With probability `min(S, 1)`, **a** voice plays; otherwise **silence**.
- Given a voice plays, variant `i` is chosen with probability `prob[i] / S`.

Operationally, one uniform roll `u ∈ [0, 1)`:
- Walk a cumulative sum of the probabilities. The first variant whose cumulative bound exceeds `u`
  is chosen. If `u >= S`, the result is **silence** (index `-1`).

Example: headbutt `pain` sums to `0.85` → 85% a pain voice, 15% nothing; within the 85%, weighted by
each entry. `attack` for `punch` sums to `0.54` → effort grunt a bit over half the time.

> Edge cases: empty pool → silence. `S > 1` (future data) → clamps to always-play (silence band
> vanishes). `S = 0` → always silent.

---

## 4. Data model (new resources, `scripts/audio/`)

### 4.1 `SoundPool` (Resource)
```
streams: Array[AudioStream]    # the variant WAVs
weights: Array[float]          # parallel to streams: precedence (swing/hit) OR probability (attack/pain)
chance_gated: bool             # false = weighted-always-pick; true = probability-with-silence
bus: StringName                # &"SFX" (swing/hit) or &"Voice" (attack/pain)
volume_db: float = 0.0
pitch_jitter: float = 0.0
priority: int = 0              # voice-channel interrupt priority (reuses existing VoicePolicy)
```
- Static, pure selector: `SoundPool.pick_index(weights: Array, rng: RandomNumberGenerator, chance_gated: bool) -> int`
  (returns `-1` for silence). This is the unit-tested heart.
- Instance helper: `pick_stream(rng) -> AudioStream` (null on silence/empty), wrapping `pick_index`.

### 4.2 `MoveSounds` (Resource)
```
swing: SoundPool = null
hit: SoundPool = null
attack: Dictionary = {}    # wrestler_id (StringName) -> SoundPool
pain: Dictionary = {}      # wrestler_id (StringName) -> SoundPool
```

### 4.3 `MoveSoundTable` (Resource)
```
moves: Dictionary = {}     # move_id (String) -> MoveSounds
resolve(move_id: String) -> MoveSounds   # null if unmapped
```
Saved to `assets/audio/move_sound_table.tres`.

---

## 5. Firing & timing (`Fighter` + `Sound` autoload)

The `Sound` autoload gains a loaded `MoveSoundTable` (`move_table`) and two entry points:

- `play_move_swing(attacker, move)` — at the swing **windup**.
- `play_move_hit(attacker, victim, move)` — at **contact**.

`Fighter` calls them only when `Sound.move_table.resolve(move.id) != null` (a mapped move). Otherwise
it keeps today's behavior (`play_impact(attack_mode)` + `PAIN`).

**Windup** (where today there is no swing/effort): in `start_move()` for a striking move, if mapped:
- play `swing` pool → SFX (always one, weighted).
- play `attack[attacker.wrestler_id]` pool → Voice (may be silent).

**Contact** (`fighter.gd` hit resolution, ~`receive_hit`/the impact site that currently calls
`play_impact` + `PAIN`): if the move is mapped:
- play `hit` pool → SFX at the victim position (always one, weighted).
- play `pain[attacker.wrestler_id]` pool → Voice on the victim (may be silent).
- **suppress** the legacy `play_impact(attack_mode)` + `play_category(PAIN)` for this move (no double-play).

Playback reuses the existing `SoundManager` infrastructure (round-robin SFX pool, per-fighter Voice
channel with `VoicePolicy` priority). `Sound` exposes the seeded `rng` already used by `pick_stream`.

> Swing fires on every swing of a mapped move, **including a whiff** (it is the whoosh, not the
> impact). Hit/pain fire only when contact actually lands.

---

## 6. Build pipeline

`tools/build_sound_mapping.gd` (SceneTree tool):
1. Parse `tools/sound_mapping.json`.
2. For every `{file}`, **fuzzy-resolve** against the source tree
   `/media/pablin/DATOS/JUEGOS/Wrestlemania/WWF Sources/Sounds` by normalizing both sides
   (lowercase, strip spaces/underscores) and recursive search. **Hard error + non-zero exit** on any
   unresolved or ambiguous (multiple-match) filename, listing the offenders.
3. Copy each resolved WAV into the project (`assets/audio/sfx/` for swing/hit, `assets/audio/voice/<wid>/`
   for attack/pain), dedup by content path, and load as `AudioStream`.
4. Build `MoveSounds` per move (`swing`/`hit` → weighted `SoundPool` on `&"SFX"`; `attack`/`pain` →
   chance-gated `SoundPool` on `&"Voice"` per wrestler), assemble `MoveSoundTable`, and
   `ResourceSaver.save` to `assets/audio/move_sound_table.tres` — preserving the `.tres` uid via the
   `Uid.preserve_or_mint`/`stamp` helper (`tools/uid_preserve.gd`).
5. Print a per-move summary (variant counts, sum-of-probabilities per voice pool) for sanity.

Re-run: `godot --headless --path . -s tools/build_sound_mapping.gd` then `--import`.

---

## 7. Architecture summary

| Unit | Responsibility | Depends on |
|------|----------------|-----------|
| `SoundPool` (+ static `pick_index`) | Variant pools + weighted/chance selection | RandomNumberGenerator |
| `MoveSounds` | The 4 buckets for one move | SoundPool |
| `MoveSoundTable` | move_id → MoveSounds + resolve | MoveSounds |
| `Sound` (extend) | Load table; `play_move_swing`/`play_move_hit` | SoundManager, MoveSoundTable |
| `Fighter` (wire) | Call swing@windup, hit@contact for mapped moves; suppress legacy | Sound |
| `tools/build_sound_mapping.gd` | JSON → fuzzy import → MoveSoundTable.tres | Uid |

The pure selector and the resources are independently testable; `Fighter`/`Sound` are the glue.

---

## 8. Testing

- **Selector** (`pick_index`, seeded rng): weighted mode never returns silence and respects weights
  over many draws; chance mode returns `-1` with frequency `≈ 1 - sum`, and weights the rest; `S = 0`
  → always silent; empty → silent; `S > 1` → never silent.
- **SoundPool**: `pick_stream` returns null on silence, a stream otherwise.
- **MoveSoundTable**: `resolve("punch")` non-null with all four buckets; `resolve("knee")` (unmapped)
  → null.
- **Fighter integration** (via the existing sound seam, e.g. `Sound.last_sfx`/`last_voice`):
  - a mapped strike fires a swing (SFX) at move start and a hit (SFX) + pain (Voice) on contact;
  - effort/pain go silent when the seeded roll exceeds the probability sum;
  - an unmapped move still uses the legacy `play_impact` path (no regression);
  - a mapped move does NOT also fire the legacy impact/pain (no double-play).
- **Build tool**: fuzzy resolver maps `swing4.wav`→`Swing 4.wav`, `punch2.wav`→`Punch2.wav`; an
  unknown filename makes the tool exit non-zero.

---

## 9. Open content notes (data, not blocking)

- `headbutt.pain.doink` mixes several wrestlers' voices — intentional variety (attacker-keyed pool).
- These are seed values; the user tunes precedence/probability by editing the JSON and rebuilding.
