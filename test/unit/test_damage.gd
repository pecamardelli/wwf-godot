extends "res://addons/gut/test.gd"

# Offense mod is the universal _35PCT=89 -> ×(256+89)/256 (REACT1.ASM:490-507, 1695-1704).
func test_punch_base_8_after_offense_mod():
	# 8 * 345 / 256 = 10 (integer)
	assert_eq(Damage.resolve(AMode.PUNCH, false, false), 10)

func test_kick_base_13_after_offense_mod():
	# 13 * 345 / 256 = 17
	assert_eq(Damage.resolve(AMode.KICK, false, false), 17)

func test_repeat_uses_two_thirds_column():
	# RD_PUNCH = floor(8*2/3)=5; 5*345/256 = 6
	assert_eq(Damage.resolve(AMode.PUNCH, true, false), 6)

func test_block_is_one_pixel():
	assert_eq(Damage.resolve(AMode.BIGBOOT, false, true), 1)

func test_apply_clamps_to_zero_and_sets_ko():
	# 163 max; a 10 hit on 6 life -> would be -4; lethal fudge: after>-10 and hit<=20 -> survives at 5
	assert_eq(Damage.apply_health(6, 10), 5)

func test_apply_kills_when_below_fudge_window():
	# big hit (24) on 6 -> after = -18 (<= -10) -> dead at 0
	assert_eq(Damage.apply_health(6, 24), 0)

func test_apply_normal_subtract():
	assert_eq(Damage.apply_health(163, 10), 153)
