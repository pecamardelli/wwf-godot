class_name Damage
## Arcade damage resolution + health bookkeeping.
## final = base × (256 + offense_mod)/256 × (256 + defense_mod)/256  (REACT1.ASM:490-507).
## offense_mod = _35PCT = 89 (universal); defense_mod = 0.

const OFFENSE_MOD := 89          # _35PCT (GAME.EQU:460)
const LIFE_MAX := 163            # LIFEBAR.ASM:135
const REPEAT_WINDOW_TICKS := 50  # REACT1.ASM:457-466
const BLOCK_DAMAGE := 1          # blocked hits = 1px (REACT1.ASM block_hit)

## Damage a hit deals. `repeat` picks the ⅔ column; `blocked` overrides to 1px.
static func resolve(amode: int, repeat: bool, blocked: bool) -> int:
	if blocked:
		return BLOCK_DAMAGE
	var base_dmg := DamageTable.repeat(amode) if repeat else DamageTable.base(amode)
	return (base_dmg * (256 + OFFENSE_MOD)) / 256   # ×1.348, integer

## Subtract `dmg` from `life`, clamped [0, LIFE_MAX], with the lethal fudge:
## a would-be kill survives at 5 when life-after > -10 and the hit was <= 20 (LIFEBAR.ASM:1557-1573).
static func apply_health(life: int, dmg: int) -> int:
	var after := life - dmg
	if after <= 0 and after > -10 and dmg <= 20:
		return 5
	return clampi(after, 0, LIFE_MAX)
