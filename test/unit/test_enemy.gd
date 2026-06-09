extends "res://addons/gut/test.gd"

func test_fighter_exposes_current_range_for_subclasses():
	var f := Fighter.new(); add_child_autofree(f)
	f.global_position = Vector2(100, 400); f.separation_radii = Vector2.ZERO
	var e := Fighter.new(); add_child_autofree(e)
	e.global_position = Vector2(300, 400); e.separation_radii = Vector2.ZERO
	e.mode = Fighter.Mode.NORMAL
	f.target = e
	assert_eq(f._current_range(), MoveTable.Rng.NORMAL)

func _basic_profile() -> AIProfile:
	var p := AIProfile.new()
	p.skill = 6
	p.reaction_delay = Vector2i(8, 8)
	p.enabled_stances = [AIController.Stance.PRESSING]
	p.stance_weights = {AIController.Stance.PRESSING: 1.0}
	p.preferred_range = AIProfile.PreferredRange.CLOSE
	return p

func _enemy() -> Enemy:
	var e := Enemy.new(); add_child_autofree(e)
	e.separation_radii = Vector2.ZERO
	e.profile = _basic_profile()
	e.side = Fighter.Side.ENEMY
	return e

func test_enemy_feeds_intent_into_movement_hook():
	var e := _enemy()
	e._intent.move_dir = Vector2(1, 0)
	assert_eq(e.get_input_direction(), Vector2(1, 0))

func test_enemy_block_intent_drives_guarding():
	var e := _enemy()
	e._intent.action = AIIntent.Action.BLOCK
	assert_true(e.wants_to_block())

func test_enemy_walks_toward_distant_player():
	var e := _enemy(); e.global_position = Vector2(100, 400)
	var p := Player.new(); add_child_autofree(p)
	p.global_position = Vector2(500, 400); p.separation_radii = Vector2.ZERO
	p.side = Fighter.Side.PLAYER
	e.target = p
	var x0 := e.global_position.x
	for _n in range(30):
		e._physics_process(1.0 / 60.0)
	assert_gt(e.global_position.x, x0, "enemy closed distance toward the player")

func test_enemy_strikes_player_in_range():
	var e := _enemy(); e.global_position = Vector2(100, 400)
	e.profile.enabled_stances = [AIController.Stance.KAMIKAZE]
	e.profile.stance_weights = {AIController.Stance.KAMIKAZE: 1.0}
	e._ai.current_stance = AIController.Stance.KAMIKAZE
	e.profile.special_frequency = 0.0
	var p := Player.new(); add_child_autofree(p)
	p.global_position = Vector2(130, 400); p.separation_radii = Vector2.ZERO
	p.side = Fighter.Side.PLAYER
	e.target = p
	var attacked := false
	for _n in range(40):
		e._physics_process(1.0 / 60.0)
		if e.is_attacking():
			attacked = true
			break
	assert_true(attacked, "kamikaze enemy throws a strike at close range")

class _FakeFoe extends Fighter:
	var faking := false
	func is_attacking() -> bool:
		return faking

func test_consecutive_incoming_counts_distinct_swings_not_frames():
	var e := _enemy(); e.global_position = Vector2(100, 400)
	var foe := _FakeFoe.new(); add_child_autofree(foe)
	foe.global_position = Vector2(130, 400); foe.separation_radii = Vector2.ZERO
	foe.side = Fighter.Side.PLAYER
	e.target = foe
	# One sustained swing held for many frames must count as ONE, not saturate.
	foe.faking = true
	for _n in range(20):
		var perc := e._build_perception()
	assert_eq(e._build_perception()["repeat_count"], 1, "a single held swing counts once, not per-frame")
	# Player stops attacking -> counter resets.
	foe.faking = false
	e._build_perception()
	assert_eq(e._build_perception()["repeat_count"], 0, "counter resets when the foe stops attacking")
	# A second distinct swing increments to 1 again.
	foe.faking = true
	assert_eq(e._build_perception()["repeat_count"], 1, "a new swing counts as one")

func test_enemy_reverses_a_headhold_when_skill_roll_succeeds():
	var captor := Player.new(); add_child_autofree(captor)
	captor.global_position = Vector2(100, 400); captor.separation_radii = Vector2.ZERO
	captor.side = Fighter.Side.PLAYER
	var e := _enemy(); e.global_position = Vector2(150, 400)
	e.profile.skill = 29; e.profile.reversal_skill = 2.0   # ~certain reversal
	e._ai.rng.seed = 1
	# put the enemy in the captor's head hold
	captor._grappling = e
	e._grappled_by = captor
	e.mode = Fighter.Mode.HEADHELD
	captor.mode = Fighter.Mode.HEADHOLD
	var reversed := false
	for _n in range(20):
		e._physics_process(1.0 / 60.0)
		if e._grappling == captor and captor._grappled_by == e:
			reversed = true
			break
	assert_true(reversed, "high-skill enemy reverses the head hold")

# --- Bug fix: head-hold reversal must be a per-DECISION roll, not a per-frame coin flip ---
# The roll ran every physics frame, so over the ~200-frame hold window even a small chance
# compounded to near-certain -> the player got hip-tossed almost every time they applied a
# headlock. The reversal attempt is now gated to the AI decision cadence (reaction_delay).
func test_headhold_reversal_is_gated_to_a_decision_cadence_not_every_frame():
	var captor := Player.new(); add_child_autofree(captor)
	captor.global_position = Vector2(100, 400); captor.separation_radii = Vector2.ZERO
	captor.side = Fighter.Side.PLAYER
	var e := _enemy(); e.global_position = Vector2(150, 400)
	e.profile.skill = 29; e.profile.reversal_skill = 2.0   # would reverse on ANY roll
	e.profile.reaction_delay = Vector2i(30, 30)            # ~0.57s decision cadence
	e._ai.rng.seed = 1
	captor._grappling = e
	e._grappled_by = captor
	e.mode = Fighter.Mode.HEADHELD
	captor.mode = Fighter.Mode.HEADHOLD
	e._physics_process(1.0 / 60.0)   # ONE frame: well inside the first decision window
	assert_false(e._grappling == captor, "no instant frame-1 reversal: the roll waits for a decision tick")

# --- Bug fix: a DISABLED enemy must not reverse a head hold (no AI at all when ai_enabled is off) ---
func test_disabled_enemy_does_not_reverse_a_headhold():
	var captor := Player.new(); add_child_autofree(captor)
	captor.global_position = Vector2(100, 400); captor.separation_radii = Vector2.ZERO
	captor.side = Fighter.Side.PLAYER
	var e := _enemy(); e.global_position = Vector2(150, 400)
	e.ai_enabled = false                                   # AI toggled OFF in the sandbox
	e.profile.skill = 29; e.profile.reversal_skill = 2.0   # would always reverse if it rolled
	e.profile.reaction_delay = Vector2i(1, 1)              # tiny cadence -> rolls fast if at all
	e._ai.rng.seed = 1
	captor._grappling = e
	e._grappled_by = captor
	e.mode = Fighter.Mode.HEADHELD
	captor.mode = Fighter.Mode.HEADHOLD
	for _n in range(60):
		e._physics_process(1.0 / 60.0)
	assert_true(e.mode == Fighter.Mode.HEADHELD, "disabled enemy stays held — no AI reversal")
	assert_false(e._grappling == captor, "disabled enemy never becomes the grappler")
