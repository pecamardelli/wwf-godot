class_name MotionBuffer
extends RefCounted
## Per-fighter rolling input-history buffer (arcade wrest_joystat, RESEARCH §A.1-A.2).
## Stores INPUT EDGES (stick changes + button-downs), newest at index 0. Joystick bits
## are facing-relative (toward/away), exactly like the arcade's #xflip_table.

const CAPACITY := 16
## Per match step, intervening unrelated entries tolerated (arcade 8-entry skip budget).
const SKIP_BUDGET := 8

# --- Input bit layout (RESEARCH §A.1). Joystick b0-3, buttons b4-8, real L/R b10-11. ---
const J_UP := 1 << 0
const J_DOWN := 1 << 1
const J_AWAY := 1 << 2
const J_TOWARD := 1 << 3
const B_PUNCH := 1 << 4
const B_BLOCK := 1 << 5
const B_SPUNCH := 1 << 6
const B_KICK := 1 << 7
const B_SKICK := 1 << 8
const J_LEFT := 1 << 10
const J_RIGHT := 1 << 11
const J_REAL_LR := J_LEFT | J_RIGHT

var _codes: Array[int] = []   # newest at index 0
var _ticks: Array[int] = []

## Build a facing-relative joystick code from an 8-way direction (no buttons).
static func encode_stick(dir: Vector2, facing: float) -> int:
	var rel := RelativeInput.resolve(dir, facing)
	var code := 0
	if rel.up: code |= J_UP
	if rel.down: code |= J_DOWN
	if rel.toward: code |= J_TOWARD
	if rel.away: code |= J_AWAY
	if dir.x < 0.0: code |= J_LEFT
	elif dir.x > 0.0: code |= J_RIGHT
	return code

## Push one input edge (newest). Evicts the oldest beyond CAPACITY.
func push(code: int, tick: int) -> void:
	_codes.push_front(code)
	_ticks.push_front(tick)
	if _codes.size() > CAPACITY:
		_codes.resize(CAPACITY)
		_ticks.resize(CAPACITY)

func size() -> int:
	return _codes.size()

func code_at(i: int) -> int:
	return _codes[i]

func tick_at(i: int) -> int:
	return _ticks[i]

func newest_tick() -> int:
	return _ticks[0] if _ticks.size() > 0 else -1

func clear() -> void:
	_codes.clear()
	_ticks.clear()
