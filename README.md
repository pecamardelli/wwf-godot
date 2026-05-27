# wwfmania-godot

A faithful, Linux-native reimplementation of **WWF WrestleMania: The Arcade Game**
(Midway, 1995) built in **Godot 4 + GDScript**.

The original arcade source code (TMS34010 assembly) serves as the *behavioral
spec* — move sequences, damage tables, timing constants, and the "dizzy" stun
mechanic are ported as rules/data, not code. Sprites and sounds come from
arcade-accurate rips. MAME is used as a behavioral *oracle* for tuning feel.

## Status

Pre-implementation. Design specs live in `docs/superpowers/specs/`.

## Goals

- Faithful arcade feel (fixed 60 Hz tick logic, ported timing/damage constants).
- Native Linux development and build — no Windows, no proprietary IDE.
- Configurable rule tweaks (e.g. an option to disable the dizzy input-lockout).
