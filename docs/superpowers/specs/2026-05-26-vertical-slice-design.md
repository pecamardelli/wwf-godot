# Vertical Slice (SP-0) — Co-op Belt-Scroll Beat-'em-up

**Date:** 2026-05-26
**Status:** Design locked, pending implementation plan
**Engine:** Godot 4.x · GDScript · Linux-native development and export

---

## 1. Project vision (revised)

A **2-player co-op side-scrolling beat-'em-up** in the **Double Dragon / Final
Fight / Streets of Rage** mold, built with the characters, sprites, sounds, and
**combat feel** of *WWF WrestleMania: The Arcade Game* (Midway, 1995).

Players traverse a level, the camera locks into **arenas** where they clear
gangs of enemies, grab weapons, and avoid hazards like pits, then advance.

This is **not** a faithful reimplementation of the arcade game's 1-on-1 ring
mode. The structure is a new beat-'em-up; the arcade game contributes only the
**combat layer**.

### Role of the original arcade source

The decompiled arcade source (`historicalsource/wwf-wrestlemania`, TMS34010
assembly) is a **behavioral reference for combat only**: move sequences,
animation timing, damage values (`DAMAGE.EQU`), tick constants (`GAME.EQU`),
hit reactions, and the **dizzy/stun** mechanic (`PLYR_DIZZY` / `MODE_DIZZY` /
`PLYR_DIZZY_CNT`). It does **not** define the macro structure (scrolling,
spawning, weapons, hazards) — those follow beat-'em-up genre conventions.
MAME is used only as a per-move "does this feel right" reference.

---

## 2. Locked design decisions

| Decision | Choice |
|---|---|
| Genre | Co-op belt-scroll beat-'em-up |
| Players | **2-player local co-op from the start** |
| Enemies | **WWF roster as enemies**, varied by **modifier profiles** |
| Enemy modifiers | size, strength, speed, voice pitch, cloth color |
| Combat depth | **Full wrestling moveset** (strikes, grapples/throws, dizzy) |
| Slice base character | **Doink** (both players + all enemy variants) |
| Slice hazards | **One pit** (weapons deferred to SP-1) |

---

## 3. Slice scope — "one real fight, end to end"

A short walkable level section playable in co-op: the camera scrolls, **locks
into one arena**, spawns a gang of **modifier-distinct Doink variants**, and
unlocks when they are cleared so players can advance. One pit hazard is present.

### In scope (the architectural pillars to retire)

1. **Local co-op** — two players, independent input (keyboard + gamepad),
   **shared camera** framing both and clamped to level bounds.
2. **Belt-scroll + lock-arena** — camera scroll along the level; `Arena`
   triggers lock → spawn waves → unlock on clear → advance.
3. **Enemy variety from one base** — `CharacterDef` (base art/moveset/stats) +
   `EnemyVariant` (scale, strength, speed, voice pitch, cloth color). Spawn ~3
   visibly distinct foes from one Doink sprite set.
4. **Multi-attacker AI** — several enemies approach/surround, gated by an
   **attack-token manager** so only 1–2 attack at once (genre fairness rule).
5. **Wrestling combat** — 2 strikes + 1 grapple/throw + **dizzy**, with an
   exported **`disable_dizzy_lockout`** toggle (the original modding goal).
6. **Depth movement** — 8-way on a floor plane with Y-sort draw order.
7. **Fixed 60 Hz logic** — gameplay in `_physics_process`; ported arcade timing
   constants expressed as frame counts.
8. **One pit hazard** — fall zone → damage/knockout → respawn at edge.
9. **Audio** — impact SFX + a voice sample with per-variant `pitch_scale`.
10. **Native Linux export** — slice runs as an exported Linux binary.

### Out of scope (later slices)

Weapons (SP-1) · full roster & per-character movesets · multiple stages/bosses ·
lives/continues/score · full signature-move lists · menus/character select ·
music · polish/juice.

---

## 4. Architecture

### Node/scene structure

- `Fighter` (`CharacterBody2D`) — base: movement, state machine, health,
  hurtbox, hitbox, animation, audio. Configured by a `CharacterDef`.
  - `Player` — reads `p1_*` / `p2_*` input actions.
  - `Enemy` — driven by `AIController`; configured additionally by an
    `EnemyVariant`.
- `LevelController` — owns scroll bounds, the sequence of `Arena`s, spawning.
- `Arena` (trigger zone) — locks the camera, spawns waves, holds an
  `AttackTokenManager`, unlocks on clear.
- `CoopCamera` (`Camera2D`) — tracks the players' midpoint, limit-clamped.
- `Pit` (`Area2D`) — fall hazard region on the floor plane.

### Data resources (inspector-editable)

- `CharacterDef` — sprite frames ref, moveset (list of `AttackDef`), base stats
  (health, walk/run speed), sound set.
- `AttackDef` — startup / active / recovery frame counts, hitbox rect,
  damage, knockback, `causes_dizzy`, hit SFX. Ported from `getAttackDefinitions`
  + `DAMAGE.EQU`.
- `EnemyVariant` — `scale`, `strength_mult`, `speed_mult`, `voice_pitch`,
  `cloth_colors` (color-replacement map).

### State machine

Explicit GDScript enum + `match`: `IDLE`, `WALK`, `ATTACK`, `GRAB`, `THROW`,
`BLOCK`, `HIT`, `DIZZY`, `DOWN`, `GETUP`, `FALLING` (pit).

### Combat mechanics

- Animations via `AnimationPlayer`; **call-method tracks** enable/disable the
  hitbox `Area2D` on specific frames (mirrors the arcade puppet/attack-box
  model).
- Hurtbox `Area2D` per fighter; overlap → resolve `AttackDef` → apply damage,
  knockback, hit reaction, and optionally enter `DIZZY`.
- `DIZZY` normally locks input for a timer; `disable_dizzy_lockout = true`
  keeps input live (configurable rule).

### Modifier / variant system (honest note)

Source PNGs are **truecolor RGBA, not indexed**, so "cloth colors" is done with
a **color-replacement shader**: map a defined set of cloth source colors → target
colors per variant (not a trivial index-palette swap). Other modifiers are
straightforward: `scale` → node scale; `strength_mult` → damage; `speed_mult` →
move + animation speed; `voice_pitch` → `AudioStreamPlayer.pitch_scale`. The
slice de-risks the cloth recolor on Doink.

### Co-op specifics

- Input map actions suffixed `p1_*` / `p2_*` (keyboard + gamepad).
- `CoopCamera` follows midpoint of living players, clamped to level limits;
  arena lock overrides scroll target.
- Enemy aggro/targeting picks among both players; attack-token manager is
  per-arena and shared across enemies.

---

## 5. Asset pipeline (grounded in on-disk reality)

- **Doink (slice base):**
  - Sprites: **only in the GMS project** at `../wwf/sprites/*` (46 Doink sprite
    resources; each GMS sprite = PNG frame(s) + `.yy` metadata for origin/bbox).
    Task: extract frame PNGs + per-frame origins from the GMS `.yy` files →
    Godot `SpriteFrames` / `AnimatedSprite2D` animations.
  - Sounds: `../WWF Sources/Sounds/Doink_sound/Doink/*.wav` and
    `Comment_sound/Comment/*Doink*.wav`.
- **Roster (later slices):** `../WWF Sources/Sprites/<Char>/<Name>/<Move>/<n>.png`
  — clean 180×180 RGBA frame sequences, no decoding needed. A reusable importer
  ingests these folders.
- Imported, game-ready assets are committed under `assets/`; raw rips
  (`WWF Sources`) and the arcade source stay outside the repo (see `.gitignore`).

---

## 6. Definition of done

- [ ] Two humans play simultaneously (keyboard + gamepad); shared camera frames both.
- [ ] Camera scrolls, then locks on entering the arena.
- [ ] ~3 Doink enemies spawn, each visibly distinct via modifiers
      (size/speed/pitch/cloth color).
- [ ] Players clear them using 2 strikes + 1 grapple/throw.
- [ ] A hit can trigger `DIZZY`; the `disable_dizzy_lockout` toggle visibly
      switches between arcade-lockout and keep-control.
- [ ] Attack-token manager prevents all enemies attacking at once.
- [ ] At least one enemy (or player) can fall into the pit and take the result.
- [ ] Impact SFX + a pitch-shifted voice play.
- [ ] Arena unlocks on clear; camera scrolls onward.
- [ ] Builds and runs as a native Linux binary, launched from the Godot editor.

---

## 7. Repo structure (target)

```
wwfmania-godot/
  project.godot
  scenes/      Level.tscn, Arena.tscn, Fighter.tscn, Pit.tscn, CoopCamera.tscn
  scripts/     fighter.gd, player.gd, enemy.gd, ai_controller.gd,
               level_controller.gd, arena.gd, attack_token_manager.gd,
               coop_camera.gd, pit.gd
  resources/   character_def.gd, attack_def.gd, enemy_variant.gd, + .tres data
  shaders/     cloth_recolor.gdshader
  assets/      sprites/doink/*, sounds/doink/*
  tools/       gms_sprite_importer/  (GMS .yy frames -> Godot SpriteFrames)
               png_sequence_importer/ (WWF Sources -> SpriteFrames, for roster)
  docs/superpowers/specs/
```

---

## 8. Risks & open questions

- **Cloth recolor on truecolor art** — needs a defined cloth color set per
  character for the replacement shader; de-risked on Doink in the slice.
- **GMS `.yy` extraction** — must recover frame PNGs *and* per-frame
  origins/bboxes so animations align; verify against a known Doink move.
- **Grapple/throw feel** — porting wrestling grabs into a multi-enemy brawler
  (who can be grabbed, interrupt rules) needs tuning; keep slice to one throw.
- **Sprite scale** — 180×180 frames are large; confirm performance with ~5
  on-screen fighters (expected fine).
