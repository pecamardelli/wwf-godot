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

## Our logic runs at Godot's fixed 60 Hz; the arcade ran at 53 ticks/s.
const LOGIC_FPS: float = 60.0

## Arcade-tick duration -> whole logic frames (round up so a window never truncates).
static func ticks_to_frames(ticks: float) -> int:
	return int(ceil(ticks * (LOGIC_FPS / TICKS_PER_SECOND)))

## Arcade velocity, written as a 16.16 hex value in px/tick, converted to px/second.
static func vel_to_px_per_sec(hex_per_tick: int) -> float:
	return (float(hex_per_tick) / 65536.0) * TICKS_PER_SECOND

## Arcade acceleration (a 16.16 px/tick^2 value) -> px/second^2. Acceleration scales by
## ticks-per-second SQUARED (it is per-tick applied per-tick).
static func accel_to_px_per_sec2(hex_per_tick2: int) -> float:
	return (float(hex_per_tick2) / 65536.0) * TICKS_PER_SECOND * TICKS_PER_SECOND

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

# --- Vertical axis (arcade wrestler_veladd, WRESTLE2.ASM:2282) ---
const GRAVITY: float = 1404.5        # 0x08000/tick^2 (GAME.EQU:436): 0.5 px/tick^2 -> px/s^2
const MAX_FALL: float = -13568.0     # MAX_YVEL -0x1000000 (WRESTLE2.ASM:2280): terminal fall vel
const FLYKICK_YVEL: float = 477.0    # 0x90000 launch (DNKSEQ2.ASM:902 spin/flying kick LEAPATOPP)
const CLINE_YVEL: float = 331.25     # 0x64000 launch (DNKSEQ2.ASM:2401 flying clothesline)
const CLINE_XVEL: float = 304.75     # 0x5c000 forward (DNKSEQ2.ASM:2402 flying clothesline)
const HDBUTT_HOP_YVEL: float = 198.75  # 0x3c000 pop (REACT1.ASM:1171 headbutt OBJ_YVEL): small hop
