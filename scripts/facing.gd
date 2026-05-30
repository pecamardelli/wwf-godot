class_name Facing
## 2D facing: horizontal (±1) × depth (FRONT/BACK). The combined orientation is one of
## four corners, ordered to match the `rotate` clip cycle FR→BR→BL→FL→FR.

const FRONT := 1   # facing toward the camera (opponent nearer / larger screen Y)
const BACK := -1   # facing away from the camera

enum State { FR, BR, BL, FL }

## (horizontal ±1, depth FRONT/BACK) -> State. `horizontal` is expected pre-signed (±1);
## callers pass `_facing` or `signf(...)`. A zero/positive value maps to the right-facing
## states (FR/BR), matching the sign convention used elsewhere (signf(0) == 0 -> right).
static func state_of(horizontal: float, depth: int) -> int:
	var right := horizontal >= 0.0
	if depth == FRONT:
		return State.FR if right else State.FL
	return State.BR if right else State.BL

## State -> horizontal facing (±1).
static func horizontal_of(state: int) -> float:
	return 1.0 if (state == State.FR or state == State.BR) else -1.0

## State -> depth (FRONT/BACK).
static func depth_of(state: int) -> int:
	return FRONT if (state == State.FR or state == State.FL) else BACK

## Depth toward an opponent. FRONT when the opponent is nearer the camera (larger screen Y),
## BACK when farther. `deadzone` adds hysteresis: within it, keep `current` (anti-jitter when
## the two fighters are roughly level in depth).
static func desired_depth(self_y: float, opp_y: float, current: int = FRONT, deadzone: float = 0.0) -> int:
	var d := opp_y - self_y
	if d > deadzone:
		return FRONT
	if d < -deadzone:
		return BACK
	return current
