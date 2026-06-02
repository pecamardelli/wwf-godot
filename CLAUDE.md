# Project: WWF Mania — Beat-'em-up

## Vision
This is a **2-player co-op side-scrolling beat-'em-up** in the style of **Double Dragon / Final
Fight**, built with **Godot 4 + GDScript**, using the characters, sprites, sounds, and combat
feel of **WWF WrestleMania: The Arcade Game** (Midway, 1995).

Players traverse a **landscape** (side-scrolling levels), clearing arenas of enemies — NOT a
wrestling match in a ring. **There is no ring.** Turnbuckles may appear as set pieces/props,
but the game is about walking through a level and beating up enemies, not ring-based wrestling.

## Sources of truth (combat fidelity)
- **Arcade asm is the source of truth** for combat/movement logic: `/home/pablin/Games/wwf-wrestlemania`
  (TMS34010). Match it; don't approximate.
- **The GMS (GameMaker) port** at `/media/pablin/DATOS/JUEGOS/Wrestlemania/wwf/` is the reference
  for how mechanics were already solved (e.g. `scripts/update_sprites/update_sprites.gml` for
  walk/facing/animation). Check it before guessing.

## Workflow
- Features go through: `brainstorming` → `writing-plans` → subagent-driven execution, with
  spec + code-quality review per task. Tests are GUT (`test/unit/`), run headless:
  `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json -gexit`
- Specs live in `docs/superpowers/specs/`, plans in `docs/superpowers/plans/`.
- A new `class_name` needs the script-class cache rebuilt before the headless test runner sees it:
  `godot --headless --path . --import`.

## Architecture notes
- Pure, unit-testable helpers in `scripts/` and `scripts/combat/` (e.g. `Facing`, `RotatePlanner`,
  `AnimSelector`, `MovementMath`, `AMode`, `Reaction`); stateful glue in `Fighter`/`Player`.
- `Fighter` (`scripts/fighter.gd`) is the base: depth-plane movement, 2D facing (horizontal ×
  depth), walk/idle/turn/getup animation, combat state, grapple/puppet driving.
- Audio (`scripts/audio/`): the `Sound` autoload plays through a `SoundTable` resource that maps a
  move category → `SoundEntry` (random-variant pool) with per-wrestler overrides over a universal
  default — the arcade `WRSND` model (`MASTER_SOUND_TABLE`/`DEFAULT_SOUND_TABLE`). Impacts key off
  `move.attack_mode` (== the arcade move category, which `AMode` mirrors); fired at hit resolution
  in `Fighter`. Per-frame sounds (arcade `ANI_SOUND`) ride `SequenceFrame.sound`, surfaced by
  `SequencePlayer.consume_sounds()`. Voice is one positional channel per fighter (`VoicePolicy`
  priority); SFX is a pooled `AudioStreamPlayer2D`. The autoload self-mutes under the headless
  test runner (no audio device). Table built by `tools/build_doink_sound_table.gd` from WAVs the
  `tools/import_sounds.gd` manifest copies out of `../WWF Sources/Sounds`.
- Announcer (`scripts/audio/announcer.gd`, a child of `Sound` on the `Announcer` bus) reacts to
  big-hit / KO / near-KO events via `Sound.announce(category, priority)`, picking a random line
  from `announcer_table.tres`, gated by `AnnouncerPolicy` (cooldown + priority, arcade `sp_anncer`).
  Toggled by the `wwfmania/audio/announcer_enabled` ProjectSettings flag (default true). Table built
  by `tools/build_announcer_table.gd` from `tools/import_announcer_sounds.gd`'s WAV subset.
