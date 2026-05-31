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
