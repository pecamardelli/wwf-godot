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

## Per-(stance,band) probability of committing to an attack this decision. LONG = 0 (must close
## first). Tuned so KAMIKAZE > PRESSING > CALCULATOR > SPACING within a band.
static func attack_prob(stance: int, band: int) -> float:
	if band == Band.LONG:
		return 0.0
	var short_band := band == Band.SHORT
	match stance:
		Stance.KAMIKAZE:   return 0.95 if short_band else 0.7
		Stance.PRESSING:   return 0.7 if short_band else 0.4
		Stance.CALCULATOR: return 0.4 if short_band else 0.2
		Stance.SPACING:    return 0.2 if short_band else 0.05
	return 0.4

## Stance multiplier on the profile's special_frequency (grab eagerness).
static func _special_mult(stance: int) -> float:
	match stance:
		Stance.KAMIKAZE:   return 1.5
		Stance.CALCULATOR: return 0.5
	return 1.0

## Decide this tick's offensive action. Two independent rolls (0..1): whether to attack, and
## strike-vs-grab. Grapples only fire in the SHORT band (must be close to connect).
static func choose_action(stance: int, special_frequency: float, band: int,
		roll_attack: float, roll_kind: float) -> int:
	if roll_attack >= attack_prob(stance, band):
		return AIIntent.Action.IDLE
	if band == Band.SHORT and roll_kind < clampf(special_frequency * _special_mult(stance), 0.0, 1.0):
		return AIIntent.Action.GRAB
	return AIIntent.Action.STRIKE

const _RANGE_BASE := {              # PreferredRange -> base hold distance (px)
	AIProfile.PreferredRange.CLOSE: 45.0,
	AIProfile.PreferredRange.MID: 110.0,
	AIProfile.PreferredRange.LONG: 200.0,
}
const _SEEK_DEADZONE := 12.0        # px tolerance around desired distance before moving

## The distance this fighter wants to hold, from preferred_range shifted by the active stance.
static func desired_distance(stance: int, preferred_range: int) -> float:
	var base: float = _RANGE_BASE.get(preferred_range, 45.0)
	match stance:
		Stance.KAMIKAZE:   return maxf(base - 60.0, 0.0)   # rush in
		Stance.PRESSING:   return maxf(base - 20.0, 0.0)
		Stance.SPACING:    return base + 60.0              # back off / circle
		Stance.CALCULATOR: return base + 30.0
	return base

## Movement direction (analog -1..1 per axis) to reach `desired` distance from the target.
## Toward when too far, away when too close, zero inside the deadzone.
static func seek_dir(self_x: float, self_z: float, target_x: float, target_z: float, desired: float) -> Vector2:
	var to_target := Vector2(target_x - self_x, target_z - self_z)
	var dist := to_target.length()
	if dist < 0.001:
		return Vector2.ZERO
	if dist > desired + _SEEK_DEADZONE:
		return to_target / dist
	if dist < desired - _SEEK_DEADZONE:
		return -to_target / dist
	return Vector2.ZERO

## Weighted random stance among `enabled`, by `weights` (missing key = 0). roll is 0..1.
## Empty/zero-weight -> keep `current`.
static func next_stance(current: int, weights: Dictionary, enabled: Array, roll: float) -> int:
	var total := 0.0
	for st in enabled:
		total += maxf(float(weights.get(st, 0.0)), 0.0)
	if total <= 0.0:
		return current
	var target := clampf(roll, 0.0, 0.999999) * total
	var acc := 0.0
	for st in enabled:
		acc += maxf(float(weights.get(st, 0.0)), 0.0)
		if target < acc:
			return st
	return current

## Apply an early stance flip from a fight event, falling back to `current` when the chosen
## stance is not enabled. roll (0..1) breaks ties between two candidate moods.
static func event_stance(current: int, event: int, profile: AIProfile, roll: float) -> int:
	var want := current
	match event:
		Event.MOBBED:
			want = Stance.SPACING
		Event.BIG_HIT:
			want = Stance.KAMIKAZE if roll < profile.aggression else Stance.SPACING
		Event.LOW_HEALTH:
			want = Stance.KAMIKAZE if roll < profile.aggression else Stance.CALCULATOR
		_:
			return current
	if profile.enabled_stances.has(want):
		return want
	return current
