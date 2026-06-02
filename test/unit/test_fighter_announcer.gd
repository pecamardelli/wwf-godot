extends "res://addons/gut/test.gd"
## Big hits / KOs / low-health knockdowns fire the right announcer category (asserted via the
## Sound.last_announced seam; the autoload is muted headless).

func _move(amode: int) -> MoveSequence:
	var m := MoveSequence.new()
	m.id = "t"
	m.attack_mode = amode
	return m

func before_each():
	Sound.last_announced = {}
	Sound.set_announcer_enabled(true)
	# A prior test (test_announcer_config) swaps the autoload announcer's table for a synthetic one
	# and never restores it; reload the real table so all ANNC_* categories resolve here.
	Sound._announcer.table = load("res://assets/audio/announcer_table.tres")
	Sound._announcer._cooldown_left = 0.0
	Sound._announcer._current_priority = -1

func test_knockdown_hit_announces_impressive():
	var atk := Fighter.new(); add_child_autofree(atk)
	var vic := Fighter.new(); add_child_autofree(vic)
	vic.health = Damage.LIFE_MAX            # healthy -> impressive, not near-ko
	vic.receive_hit(atk, _move(AMode.BIGBOOT))   # BIGBOOT -> KNOCKDOWN family
	assert_eq(Sound.last_announced.get("category"), SoundCategory.ANNC_IMPRESSIVE)

func test_lethal_hit_announces_ko():
	var atk := Fighter.new(); add_child_autofree(atk)
	var vic := Fighter.new(); add_child_autofree(vic)
	vic.health = 1                          # this blow kills
	vic.receive_hit(atk, _move(AMode.PUNCH))
	assert_eq(Sound.last_announced.get("category"), SoundCategory.ANNC_KO)

func test_low_health_knockdown_announces_near_ko():
	var atk := Fighter.new(); add_child_autofree(atk)
	var vic := Fighter.new(); add_child_autofree(vic)
	vic.health = Fighter._LOW_HEALTH_THRESHOLD    # = 48 (163*3/10); BIGBOOT deals 24 -> survives at 24
	vic.receive_hit(atk, _move(AMode.BIGBOOT))    # 24 <= 48 and alive -> near-ko
	assert_eq(Sound.last_announced.get("category"), SoundCategory.ANNC_NEAR_KO)

func test_plain_punch_does_not_announce():
	var atk := Fighter.new(); add_child_autofree(atk)
	var vic := Fighter.new(); add_child_autofree(vic)
	vic.health = Damage.LIFE_MAX
	vic.receive_hit(atk, _move(AMode.PUNCH))   # HEAD_HIT, not knockdown, not lethal
	assert_eq(Sound.last_announced, {}, "a plain punch is not commentary-worthy")
