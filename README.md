# wwfmania-godot

A **2-player co-op side-scrolling beat-'em-up** (Double Dragon / Final Fight
style) built in **Godot 4 + GDScript**, using the characters, sprites, sounds,
and combat feel of **WWF WrestleMania: The Arcade Game** (Midway, 1995).

Players traverse a level, clear arenas full of enemies, grab weapons, and avoid
hazards. Enemies are drawn from the WWF roster and varied with modifier profiles
(size, strength, speed, voice pitch, cloth color).

The original arcade source (TMS34010 assembly) is used only as a **combat-layer
reference** — movesets, animation timing, damage tables, and the "dizzy" stun
mechanic. The macro structure is a new beat-'em-up, not a port of the ring mode.

## Status

Pre-implementation. Design specs live in `docs/superpowers/specs/`.
Current target: the SP-0 vertical slice (see
`docs/superpowers/specs/2026-05-26-vertical-slice-design.md`).

## Principles

- Native Linux development and build — no Windows, no proprietary IDE.
- Fixed 60 Hz tick logic; arcade combat constants ported as data.
- Player mechanics reproduced faithfully from the original arcade source
  (movement, moves, damage, reactions, knockdown/getup with mash-to-recover).
