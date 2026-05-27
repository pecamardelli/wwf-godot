class_name ArcadeUnits
## Conversions from the arcade's tick / 16.16-fixed-point model to our world
## (fixed 60 Hz logic, float, pixels). See research doc 2026-05-27-arcade-movement-*.

## The arcade treats 1 second = 53 ticks (DISPLAY.EQU TSEC). DIRQ is 60 Hz but
## effective dispatch averages ~53/s; speeds-per-second use 53.
## NOTE: we match the arcade's WALL-CLOCK speed (px/second), not its per-frame
## displacement. Our logic runs at Godot's 60 Hz, so 1 frame != 1 arcade tick.
## To match tick-denominated durations (knockdown, knockback arcs, combo windows),
## convert through ticks_to_seconds() — never assume 1 frame = 1 tick.
const TICKS_PER_SECOND: float = 53.0

## Arcade velocity, written as a 16.16 hex value in px/tick, converted to px/second.
static func vel_to_px_per_sec(hex_per_tick: int) -> float:
	return (float(hex_per_tick) / 65536.0) * TICKS_PER_SECOND

## Arcade duration in ticks -> seconds.
static func ticks_to_seconds(ticks: float) -> float:
	return ticks / TICKS_PER_SECOND

# Derived walk/run speeds (px/second) straight from the arcade velocity table.
const WALK_CARDINAL: float = 192.125        # 0x3a000 (3.625 px/tick)
const WALK_DIAGONAL_AXIS: float = 162.3125  # 0x31000 (3.0625 px/tick, per axis)
const RUN_SPEED: float = 331.25             # 0x64000 (6.25 px/tick, Doink)
const RUN_DEPTH_DRIFT: float = 132.5        # 0x28000 (2.5 px/tick)
const BACKWARD_MULT: float = 0.9
const OPP_DOWN_MULT: float = 1.5
