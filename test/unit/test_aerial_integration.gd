extends "res://addons/gut/test.gd"
## End-to-end: the authored aerial sequences launch the fighter and land it.

const FRAME: float = 1.0 / 60.0
const FLY_KICK := preload("res://assets/sequences/doink/flying_kick.tres")
const CLOTHESLINE := preload("res://assets/sequences/doink/flying_clothesline.tres")

func test_flying_kick_launches_and_lands():
	var p := Player.new()
	add_child_autofree(p)
	var foe := Fighter.new()
	add_child_autofree(foe)
	p.global_position = Vector2(0, 400); p._set_facing(1.0)
	foe.global_position = Vector2(150, 400); foe.mode = Fighter.Mode.NORMAL
	p.target = foe
	p.start_move(FLY_KICK)
	var went_airborne := false
	var max_h := 0.0
	for _i in range(240):
		p._physics_process(FRAME)
		if p.mode == Fighter.Mode.INAIR:
			went_airborne = true
		max_h = maxf(max_h, p._height)
		if went_airborne and p.mode == Fighter.Mode.NORMAL and not p.is_attacking():
			break
	assert_true(went_airborne, "flying kick took the fighter airborne")
	assert_gt(max_h, 10.0, "rose off the mat (a small hop, ~18px apex per the lowered launch)")
	assert_almost_eq(p._height, 0.0, 0.001, "landed back on the mat")

func test_clothesline_launches_forward():
	var p := Player.new()
	add_child_autofree(p)
	p.global_position = Vector2(0, 400); p._set_facing(1.0)
	p.start_move(CLOTHESLINE)
	for _i in range(12):
		p._physics_process(FRAME)
	assert_gt(p.global_position.x, 0.0, "clothesline carried the body forward")

# --- Bug fix: the clothesline lands FLAT (ONGROUND -> getup), not straight to a standing idle ---
func test_clothesline_lands_prone_then_recovers():
	var p := Player.new()
	add_child_autofree(p)
	p.global_position = Vector2(0, 400); p._set_facing(1.0)
	p.start_move(CLOTHESLINE)
	var went_onground := false
	for _i in range(240):
		p._physics_process(FRAME)
		if p.mode == Fighter.Mode.ONGROUND:
			went_onground = true
		if went_onground and p.mode == Fighter.Mode.NORMAL and not p.is_attacking():
			break
	assert_true(went_onground, "clothesline lands the body ONGROUND (gets up) instead of snapping to idle")
	assert_almost_eq(p._height, 0.0, 0.001, "ended back on the mat")

# --- Bug fix: the clothesline keeps sliding forward (decelerating) after it lands, then gets up ---
func test_clothesline_slides_after_landing_then_recovers():
	var p := Player.new()
	add_child_autofree(p)
	p.global_position = Vector2(0, 400); p._set_facing(1.0)
	p.start_move(CLOTHESLINE)
	var x_at_first_touchdown := 0.0
	var captured := false
	var x_at_recovery := 0.0
	for _i in range(300):
		p._physics_process(FRAME)
		if not captured and p._prone_land_stage == 1:
			captured = true
			x_at_first_touchdown = p.global_position.x
		if captured and p.mode == Fighter.Mode.ONGROUND:
			x_at_recovery = p.global_position.x
			break
	assert_true(captured, "clothesline reached its flat landing")
	assert_gt(x_at_recovery, x_at_first_touchdown + 5.0, "kept sliding forward after touchdown before settling")

# --- Bug fix: facing is set once at move start and HELD; a traveling attack must not flip when it
# crosses the foe's vertical line (arcade ANI_SETFACING + MODE_NOAUTOFLIP) ---
func test_facing_holds_through_a_traveling_attack_past_the_foe():
	var p := Player.new()
	add_child_autofree(p)
	var foe := Fighter.new()
	add_child_autofree(foe)
	p.global_position = Vector2(0, 400); p.separation_radii = Vector2.ZERO
	foe.global_position = Vector2(60, 400); foe.mode = Fighter.Mode.NORMAL; foe.separation_radii = Vector2.ZERO
	p.target = foe
	p._set_facing(1.0)
	p.start_move(CLOTHESLINE)
	assert_eq(p.facing(), 1.0, "faces the right-side foe at move start")
	var crossed := false
	var flipped := false
	for _i in range(200):
		p._physics_process(FRAME)
		if p.global_position.x > foe.global_position.x:
			crossed = true
		if p.facing() != 1.0:
			flipped = true
		if crossed and p.mode == Fighter.Mode.ONGROUND:
			break
	assert_true(crossed, "the clothesline carried the body past the foe's X line")
	assert_false(flipped, "facing held through the attack even after crossing the foe — no instant flip")
