class_name AIController
extends RefCounted
## Pure decision core for an AI fighter. Holds its own mutable mood/cadence state;
## all randomness flows through `rng` (seed it in tests for determinism). The decision
## math lives in static helpers so it is unit-testable without a scene tree.

enum Stance { SPACING, PRESSING, KAMIKAZE, CALCULATOR }
enum Band { SHORT, MID, LONG }
enum Event { NONE, BIG_HIT, LOW_HEALTH, MOBBED }

## Distance bands in world px (combat is authored in arcade-equivalent px; tune later).
## Arcade DRONE.ASM: short <=100, medium <=180 on max(Xdist, 2*Zdist).
const BAND_SHORT_MAX := 100.0
const BAND_MID_MAX := 180.0
## Arcade DRN_MODE re-rolls roughly every ~5.3 s.
const STANCE_BASE_SECONDS := 5.3

var rng := RandomNumberGenerator.new()
var current_stance: int = Stance.PRESSING
var stance_timer: float = 0.0
var delay: int = 0

## Arcade DRONE.ASM #slctscrpt: metric = max(|Xdist|, 2*|Zdist|), banded by thresholds.
static func distance_band(dx: float, dz: float) -> int:
	var metric := maxf(absf(dx), 2.0 * absf(dz))
	if metric <= BAND_SHORT_MAX:
		return Band.SHORT
	if metric <= BAND_MID_MAX:
		return Band.MID
	return Band.LONG
