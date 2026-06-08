extends "res://addons/gut/test.gd"
## Full path: buffered hip-toss motion -> Player.scan_specials fires the grapple ->
## AttackResolver connects the grab -> puppet playback -> DAMAGE_OPP -> DETACH knockdown.

var resolver: AttackResolver

func before_each():
	resolver = AttackResolver.new()
	add_child_autofree(resolver)

func _player(pos: Vector2, side: int) -> Player:
	var p := Player.new(); p.side = side
	p.motions = load("res://assets/motions/doink_motions.tres")
	add_child_autofree(p); p.global_position = pos
	return p

func test_hip_toss_full_flow():
	var atk := _player(Vector2(100, 400), Fighter.Side.PLAYER)
	atk._set_facing(1.0)
	var vic := _player(Vector2(150, 400), Fighter.Side.ENEMY)
	var before := vic.health
	# Buffer the hip-toss motion: away, away, PUNCH (held away), all "now".
	atk.motion_buffer.push(MotionBuffer.J_AWAY | MotionBuffer.J_LEFT, 1)
	atk.motion_buffer.push(MotionBuffer.J_AWAY | MotionBuffer.J_LEFT, 2)
	atk.motion_buffer.push(MotionBuffer.B_PUNCH | MotionBuffer.J_AWAY | MotionBuffer.J_LEFT, 3)
	atk._input_tick = 3
	assert_true(atk.scan_specials(), "hip toss fired")
	assert_eq(atk.mode, Fighter.Mode.NORMAL, "not yet GRABBING until the box connects")
	# Drive the sim through the full throw (~36-tick throw + contact freeze at 4 ticks/frame).
	var was_downed := false
	for _i in range(70):
		atk._physics_process(1.0 / 60.0)
		resolver.resolve_tick()
		vic._physics_process(1.0 / 60.0)
		if vic.mode == Fighter.Mode.ONGROUND:
			was_downed = true   # near-instant getup: caught during the down beat, not after
	assert_lt(vic.health, before, "victim took puppet damage")
	assert_true(was_downed, "victim knocked down after detach")
	assert_eq(atk.mode, Fighter.Mode.NORMAL, "attacker returns to NORMAL (not stuck in GRABBING)")

func test_hip_toss_rolls_pain_and_body_drop_once():
	# The hip-toss sequence has BOTH a DAMAGE_OPP and a DETACH frame; the victim's pain must roll
	# only ONCE per toss (else the 30% probability would be double-counted), and the body-drop thud
	# must play once. Inject an always-on per-move pain + shared hit_ground so counts are deterministic.
	var pain := SoundPool.new(); pain.streams = [AudioStreamWAV.new()]; pain.weights = [1.0]
	pain.chance_gated = true; pain.bus = &"Voice"
	var hg := SoundPool.new(); hg.streams = [AudioStreamWAV.new()]; hg.weights = [1.0]
	hg.chance_gated = false; hg.bus = &"SFX"
	var ms := MoveSounds.new(); ms.pain = {&"doink": pain}
	var t := MoveSoundTable.new(); t.moves = {"hip_toss": ms}; t.hit_ground = hg
	var prev = Sound.move_table
	Sound.move_table = t

	var atk := _player(Vector2(100, 400), Fighter.Side.PLAYER); atk._set_facing(1.0)
	atk.wrestler_id = &"doink"
	var vic := _player(Vector2(150, 400), Fighter.Side.ENEMY); vic.wrestler_id = &"doink"
	atk.motion_buffer.push(MotionBuffer.J_AWAY | MotionBuffer.J_LEFT, 1)
	atk.motion_buffer.push(MotionBuffer.J_AWAY | MotionBuffer.J_LEFT, 2)
	atk.motion_buffer.push(MotionBuffer.B_PUNCH | MotionBuffer.J_AWAY | MotionBuffer.J_LEFT, 3)
	atk._input_tick = 3
	atk.scan_specials()
	var pain_fires := 0
	var drop_fires := 0
	for _i in range(70):
		Sound.last_voice = {}; Sound.last_sfx = {}
		atk._physics_process(1.0 / 60.0)
		resolver.resolve_tick()
		vic._physics_process(1.0 / 60.0)
		if Sound.last_voice.get("fighter") == vic:
			pain_fires += 1
		if not Sound.last_sfx.is_empty():
			drop_fires += 1
	Sound.move_table = prev
	assert_eq(pain_fires, 1, "victim pain rolls exactly once per hip toss")
	assert_eq(drop_fires, 1, "body-drop thud plays exactly once per hip toss")

func test_hip_toss_lifts_the_victim():
	var atk := _player(Vector2(100, 400), Fighter.Side.PLAYER); atk._set_facing(1.0)
	var vic := _player(Vector2(150, 400), Fighter.Side.ENEMY)
	atk.motion_buffer.push(MotionBuffer.J_AWAY | MotionBuffer.J_LEFT, 1)
	atk.motion_buffer.push(MotionBuffer.J_AWAY | MotionBuffer.J_LEFT, 2)
	atk.motion_buffer.push(MotionBuffer.B_PUNCH | MotionBuffer.J_AWAY | MotionBuffer.J_LEFT, 3)
	atk._input_tick = 3
	atk.scan_specials()
	var max_lift := 0.0
	for _i in range(70):
		atk._physics_process(1.0 / 60.0); resolver.resolve_tick(); vic._physics_process(1.0 / 60.0)
		max_lift = maxf(max_lift, atk.global_position.y - vic.global_position.y)
	# Proves the victim is driven UP off the ground (atk.y - off.y) during the throw —
	# the lift scales with _GRAB_OFFSET_SCALE_Y, applied when the .tres is regenerated.
	assert_gt(max_lift, 40.0, "victim is lifted well off the ground during the toss")

func test_connected_neck_grab_enters_head_hold():
	# Load the REAL neck_grab sequence via the motions table (same path as production).
	var atk := _player(Vector2(100, 400), Fighter.Side.PLAYER)
	atk._set_facing(1.0)
	var vic := _player(Vector2(150, 400), Fighter.Side.ENEMY)
	# Trigger the neck_grab: SPUNCH (B_SPUNCH=64) with J_TOWARD(8), matching the .tres values.
	atk.motion_buffer.push(MotionBuffer.J_TOWARD | MotionBuffer.J_RIGHT, 1)
	atk.motion_buffer.push(MotionBuffer.J_TOWARD | MotionBuffer.J_RIGHT, 2)
	atk.motion_buffer.push(MotionBuffer.B_SPUNCH | MotionBuffer.J_TOWARD | MotionBuffer.J_RIGHT, 3)
	atk._input_tick = 3
	assert_true(atk.scan_specials(), "neck grab fired")
	# Advance tick-by-tick until the grab window opens (WAIT_HIT_OPP at anim frame 4).
	var guard := 0
	while not atk._player.is_waiting_for_hit() and guard < 120:
		atk._physics_process(1.0 / 60.0)
		vic._physics_process(1.0 / 60.0)
		guard += 1
	assert_true(atk._player.is_waiting_for_hit(), "reached the grab window")
	# Connect: resolve_tick() with the victim in grab range and not guarding.
	resolver.resolve_tick()
	assert_eq(atk.mode, Fighter.Mode.HEADHOLD, "connected neck grab enters the head hold")
	assert_eq(vic.mode, Fighter.Mode.HEADHELD, "victim is held")
	assert_eq(atk._grappling, vic, "victim bound to the captor")
