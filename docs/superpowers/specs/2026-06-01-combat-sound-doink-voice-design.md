# Combat Sound — Universal SFX + Doink Voice (Design)

**Date:** 2026-06-01
**Status:** Design locked, pending implementation plan
**Engine:** Godot 4.x · GDScript
**Slice:** Sub-project 1 of the audio effort (see §8 for the decomposition).

---

## 1. Purpose & scope

The game has no audio at all — zero `AudioStreamPlayer` nodes, buses, or sound hooks. The GMS
port barely touched sound (2 `audio_play_sound` calls total), so the **arcade asm is the source
of truth** for which sound fires on which combat event.

This feature delivers the **core audio engine** plus the first, highest-payoff sound layer:
**universal combat SFX** (punches, impacts, body drops, swings, neck-crackles) and **Doink's
voice** (effort grunts, pain, taunts, joy-buzzer/hammer specials). Doink is the only enemy that
exists, so this gives the most immediate "feel" payoff while building the data-driven plumbing
that the remaining sound slices (announcer, music, UI, other 7 wrestlers) drop into without
rework.

### In scope
- Audio bus layout (`Master → SFX`, `Master → Voice`, `Music` stub).
- `SoundManager` autoload: resolve a sound (category or explicit id) and play it on a fighter.
- Per-fighter playback: pooled polyphonic SFX + **one dedicated Voice channel per fighter**.
- **Positional** audio via `AudioStreamPlayer2D` (pan/attenuation follow screen position).
- Data-driven `SoundTable` / `SoundEntry` resources mirroring the arcade's
  `MASTER_SOUND_TABLE[wrestler]` + `DEFAULT_SOUND_TABLE` fallback model.
- Three trigger paths: on-hit impacts (`WRSND`), per-frame sounds (`ANI_SOUND` →
  `SequenceFrame.sound`), and reaction sounds (knockdown body-drop, pain voice).
- Asset import pipeline for the subset of WAVs this slice needs.
- GUT coverage of all pure logic (lookup, fallback, variant pick, voice-priority decision).

### Out of scope (later slices — see §8)
Announcer (294 comment lines) · background music · UI/event beeps (combo meter, timer,
low-health, menu) · voice sets for the other 7 wrestlers · sound options/volume menu.
The data model is built so these are additive.

---

## 2. Arcade reference (source of truth)

From `/home/pablin/Games/wwf-wrestlemania` (TMS34010): `SOUND.H`, `SOUND.EQU`, `ANIM.EQU`,
`DCSSOUND.ASM`, and the per-wrestler logic / sequence files (`ADAM.ASM`, `DNKSEQ*.ASM`, …).

Two distinct mechanisms drive combat sound:

**(a) On-hit impact — `WRSND` macro (`SOUND.H:131`).**
`WRSND WRESTLER, SOUND1, SOUND2` plays one or two sound layers for a wrestler+move category. It
indexes `MASTER_SOUND_TABLE + wrestler*16*(LAST_MOVE+1) + category*16`; if that slot is empty
(`jrnn`/`jrz`), it falls back to `DEFAULT_SOUND_TABLE + category*16`. Example usage:
`WRSND W_ADAM,PUNCH_T1,PUNCH_T2` (ADAM.ASM:437). The **T1/T2 are two layers played together**
(e.g. an effort + an impact), *not* random alternatives.

Move categories (`SOUND.H:59+`), 4 slots each (`_T1,_T2` = throw layers, `_L1,_L2` = land
layers): `PUNCH, HDBUTT, KICK, FLYKICK, GRABTHROW, UPRCUT, LBOWDROP, GRABHOLD, GRABFLING, PUSH,
HIPTOSS, SPUNCH, TURNDIVE, RUGSLAM (RUGSLAM_IMPACT=55), RSLASH, YELL_THROW`. `LAST_MOVE =
YELL_THROW`.

**(b) Per-frame script sound — `ANI_SOUND` opcode (`ANIM.EQU:40`, `= 26 + 8000h`).**
Animation sequence scripts interleave `.word ANI_SOUND, <id>` with the frame data; the sound
fires when that frame begins. Doink examples (`DNKSEQ3.ASM`): `ANI_SOUND,020Fh` ("PUT IT THERE"
joy-buzzer taunt), `ANI_SOUND,82h` (effort grunt), `ANI_SOUND,33h` (neck break), `ANI_SOUND,43h`
(repeated hammer/attack hit). There is also `ANI_RAWSOUND` (`=65+8000h`) — out of scope.

**Playback core:** `SNDSND` (DCS sound board) plays a sound id; sounds carry a priority
(`sndpri`), duration, and run on a small set of channels (`chan1snd…chan4snd`). Our
"one voice per fighter + priority interrupt" models this per-channel priority behavior; we do not
emulate the DCS board itself.

**Mapping Doink's existing Godot moves → categories** (from `assets/movetables/doink.tres` and
`assets/motions/`):

| Godot move | Category | Godot move | Category |
|---|---|---|---|
| punch | PUNCH | uppercut | UPPERCUT |
| headbutt | HEADBUTT | spin_kick | SPIN_KICK (FLYKICK) |
| kick | KICK | grab_fling | GRAB_FLING |
| knee | KNEE (→KICK) | hip_toss | HIP_TOSS |
| stomp | STOMP (→KICK) | piledriver | PILEDRIVER (GRABTHROW) |
| big_boot | BIG_BOOT (→KICK) | head_slam | HEAD_SLAM (RUGSLAM) |
| slap | SLAP | joy_buzzer | TAUNT (voice special) |
| elbow_drop | ELBOW_DROP | hammer | EFFORT/hit (voice special) |

Categories with no arcade-distinct impact reuse the nearest base via the default table
(parenthesized). `joy_buzzer`/`hammer` are voiced through `ANI_SOUND` frame hooks, not `WRSND`.

---

## 3. Approach (chosen: data-driven sound tables)

Translate the arcade's own design directly:

- `SoundTable` (default map + per-wrestler override map) == `DEFAULT_SOUND_TABLE` +
  `MASTER_SOUND_TABLE`; lookup falls back default-ward == the `WRSND` `jrnn/jrz` logic.
- `SequenceFrame.sound` == `ANI_SOUND` opcode.
- `SoundManager` + per-fighter players == the DCS play routine + channels.

Rejected: **(B)** hardcoded `match` triggers in `attack_resolver`/`fighter` — fast but diverges
from the arcade model, not data-driven, brittle as characters grow. **(C)** Godot
`AnimationPlayer` call-method tracks — doesn't fit; the game uses its own tick-based
`SequencePlayer`, not `AnimationPlayer`.

---

## 4. Components

### 4.1 Buses
`default_bus_layout.tres`: `Master → SFX`, `Master → Voice`, and a `Music` bus (stub, unused
this slice). Per-bus volume so SFX vs. voice can be balanced. Configured in `project.godot`.

### 4.2 Data model (`scripts/audio/`)
- **`SoundCategory`** (constants/enum): the impact categories actually used —
  `PUNCH, KICK, HEADBUTT, UPPERCUT, ELBOW_DROP, KNEE, STOMP, BIG_BOOT, SLAP, SPIN_KICK,
  GRAB_FLING, HIP_TOSS, PILEDRIVER, HEAD_SLAM` — plus voice/event categories
  `PAIN, EFFORT, TAUNT, BODY_DROP`.
- **`SoundEntry`** (Resource): `streams: Array[AudioStream]` (random-pick among variants),
  `priority: int` (higher interrupts lower on the voice channel), `bus: StringName`
  (`&"SFX"`/`&"Voice"`), optional `volume_db`, `pitch_jitter` (small random pitch spread).
  - **On T1/T2:** the arcade's `WRSND` plays two *layers* (a throw/effort layer + an impact
    layer). We collapse a category to **one impact `SoundEntry`** whose `streams` are the
    impact variants (e.g. `Impact, Impact 2…6` → random pick). The effort/grunt layer is not
    folded in here — it rides the `ANI_SOUND` per-frame voice hook (§5, path 2) where the
    arcade sequence actually places it. This avoids double-firing and keeps entries
    single-purpose.
- **`SoundTable`** (Resource): `default: Dictionary` (category → `SoundEntry`) and
  `per_wrestler: Dictionary` (wrestler_id → `{category → SoundEntry}`). One shipped instance:
  Doink overrides + a universal default. Method `resolve(wrestler_id, category) -> SoundEntry`:
  try the wrestler override, else default, else `null`.
- **Explicit ids** for `ANI_SOUND`-style frame sounds: `SequenceFrame.sound` is a `SoundEntry`
  (or null). No table lookup — the sequence author picks the exact clip (grunt, taunt, hammer).

### 4.3 Runtime (`scripts/audio/sound_manager.gd`, autoload `Sound`)
- Holds the `SoundTable`. Owns a small **pool of `AudioStreamPlayer2D`** (e.g. 8) for
  polyphonic SFX; round-robins / reuses finished players.
- API (pure-ish; takes positions + a player factory so it's test-seamable):
  - `play_impact(wrestler_id, category, at_position)` — table lookup → pick variant → play on a
    pooled SFX player at the victim's position.
  - `play_entry(entry, on_fighter)` — generic; routes voice entries to the fighter's voice
    channel, SFX to the pool.
- **Voice channel:** each `Fighter` gets one dedicated `AudioStreamPlayer2D` child (`VoicePlayer`).
  Playing a voice entry: if idle → play; if busy → play only when `new.priority >=
  current.priority` (interrupt), else drop. This is the per-fighter "one voice" rule.
- **Positional:** all players are `AudioStreamPlayer2D` positioned at the fighter, so the
  existing camera/listener pans and attenuates them.
- **Variant pick & pitch jitter** use an injectable RNG (seedable) so tests are deterministic.

### 4.4 Asset pipeline (`assets/audio/`, `tools/`)
- Copy only the needed WAVs from `WWF Sources/Sounds/{Punches_impacts_etc, Doink_sound}` into
  `assets/audio/sfx/` and `assets/audio/voice/doink/`, renamed to snake_case
  (`Impact 3.wav` → `impact_03.wav`, `Doink pain 5.wav` → `doink_pain_05.wav`).
- A small, re-runnable `tools/import_sounds.gd` (or documented script) performs the copy+rename
  from an explicit manifest, so the import is reproducible and reviewable.
- Godot imports each as `AudioStreamWAV`, **loop off**.

---

## 5. Trigger integration (where sounds fire)

1. **On-hit impact (`WRSND`).** At hit resolution (`scripts/combat/attack_resolver.gd` / the
   damage-apply path), the connecting attacker's move → `SoundCategory` → `Sound.play_impact(
   attacker.wrestler_id, category, victim.global_position)`. This is the primary "feel" layer.
2. **Per-frame (`ANI_SOUND`).** New optional `@export var sound: SoundEntry` on `SequenceFrame`.
   When `SequencePlayer` begins a frame, if `sound != null` it calls `Sound.play_entry(sound,
   fighter)`. Used for Doink effort grunts, joy-buzzer taunt, hammer, neck-break.
3. **Reactions.** On knockdown landing → `BODY_DROP` SFX at the victim. On taking damage →
   `PAIN` voice on the victim's voice channel (so it obeys one-voice-per-fighter and won't stack).
   These hook the existing reaction/knockdown path in `Fighter`/`Reaction`.

A given move must not double-fire (e.g. impact + pain are distinct categories/channels by
design; `WRSND` is fired once per connect, gated by the existing hit-once logic).

---

## 6. Testing (GUT, headless)

Pure logic is fully unit-tested without real audio:
- `SoundTable.resolve` — wrestler override hit, default fallback, missing → null.
- Variant selection — seeded RNG picks expected index; single-variant entry always returns it.
- Voice-priority decision — interrupt when `>=`, drop when `<`, play when idle (a pure helper
  `should_interrupt(current_priority, new_priority, is_busy) -> bool`).
- Move → category mapping for Doink's moveset.

`SoundManager` playback is verified through a **seam**: inject a fake player factory and assert
"(category X, wrestler W) resolved to stream Y on bus Z, positioned at P" — no audio device used.
A headless integration check drives a Doink punch connect and asserts the impact call happened.
Real audible playback is verified manually in `Sandbox.tscn`.

---

## 7. Architecture fit

- New pure/testable units live in `scripts/audio/` (`SoundTable`, `SoundEntry`, `SoundCategory`,
  the voice-priority helper), consistent with the project's "pure helpers in `scripts/`, stateful
  glue in `Fighter`/`Player`" rule (CLAUDE.md).
- `SoundManager` is the stateful glue (autoload). `Fighter` gains a `VoicePlayer` child and a
  `wrestler_id`; `SequenceFrame` gains one optional field; `attack_resolver`/reaction paths gain
  one call each. No restructuring of combat logic.

---

## 8. Audio effort decomposition (context)

1. **Combat SFX + Doink voice** ← *this spec* (builds the engine).
2. Announcer system (294 comments; event detection + priority queue).
3. Music + menu/event audio.
4. Voice sets for the other 7 wrestlers (pure data — reuses this engine).
