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

## Arcade DRONE.ASM blkbase_t: base block % indexed by skill 0..29 (SKLM-expanded rows).
const _BLOCK_BASE := [
	10, 12, 14, 16, 18,   # skill 0-4
	20, 22, 24, 26, 28,   # 5-9
	30, 31, 32, 33, 34,   # 10-14
	35, 36, 37, 38, 39,   # 15-19
	40, 41, 42, 43, 44,   # 20-24
	47, 54, 61, 68, 75,   # 25-29
]
## Arcade blkatk_t: bonus % per consecutive incoming attack (capped at index 9).
const _BLOCK_ATK := [0, 10, 20, 30, 40, 50, 50, 50, 50, 50]

## Block threshold (0..99). base(skill) + repeat-bonus, scaled by block_skill, minus the
## arcade crowd penalty (32 per extra ally). Clamped to [0,99].
static func block_chance(skill: int, block_skill: float, repeat_count: int, ally_count: int) -> int:
	var s := clampi(skill, 0, 29)
	var r := clampi(repeat_count, 0, _BLOCK_ATK.size() - 1)
	var raw := (float(_BLOCK_BASE[s] + _BLOCK_ATK[r])) * block_skill
	raw -= 32.0 * float(maxi(ally_count - 1, 0))
	return clampi(int(round(raw)), 0, 99)

## roll is 0..99 (e.g. rng.randi_range(0, 99)).
static func should_block(threshold: int, roll: int) -> bool:
	return roll < threshold

## Grapple/leaping-reversal chance. Arcade gates reversals at ~skill/4; we normalize that to
## a 0..1 probability over the 0..29 skill range, scaled by reversal_skill. roll is 0..1.
static func should_reverse(skill: int, reversal_skill: float, roll: float) -> bool:
	var chance := (float(clampi(skill, 0, 29)) / 29.0) * reversal_skill
	return roll < chance

## Choose a strike button by the fighter's fists/legs bias. roll is 0..1.
## (Low variants only for now; high-punch/high-kick selection is a later tuning pass.)
static func pick_strike_button(limb_bias: float, roll: float) -> int:
	return MoveTable.Btn.LOW_KICK if roll < limb_bias else MoveTable.Btn.LOW_PUNCH
