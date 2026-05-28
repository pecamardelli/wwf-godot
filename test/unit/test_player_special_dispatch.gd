extends "res://addons/gut/test.gd"
## Player.scan_specials() fires the mapped grapple sequence when a motion matches,
## clears the buffer on fire, and is a no-op while attacking / when no registry is set.

var player: Player

func before_each():
	player = Player.new()
	add_child_autofree(player)

func _hip_toss_move() -> MotionMove:
	var m := MotionMove.new()
	m.move_id = "hip_toss"
	m.values = PackedInt32Array([MotionBuffer.B_PUNCH, MotionBuffer.J_AWAY, MotionBuffer.J_AWAY])
	var j_all := MotionBuffer.J_UP | MotionBuffer.J_DOWN | MotionBuffer.J_AWAY \
		| MotionBuffer.J_TOWARD | MotionBuffer.J_REAL_LR
	m.masks = PackedInt32Array([j_all, MotionBuffer.J_REAL_LR, MotionBuffer.J_REAL_LR])
	m.max_ticks = 32
	return m

func _grab_seq() -> MoveSequence:
	var s := MoveSequence.new()
	s.id = "hip_toss_seq"; s.anim_name = "hip_toss"; s.attack_mode = AMode.PUNCH
	var f := SequenceFrame.new(); f.duration_ticks = 4; f.anim_frame = 0
	s.frames = [f]
	return s

func _table_with_hip_toss() -> MotionTable:
	var t := MotionTable.new()
	t.add(_hip_toss_move(), _grab_seq())
	return t

func _feed_hip_toss_motion():
	player.motion_buffer.push(MotionBuffer.J_AWAY | MotionBuffer.J_LEFT, 1)
	player.motion_buffer.push(MotionBuffer.J_AWAY | MotionBuffer.J_LEFT, 2)
	player.motion_buffer.push(MotionBuffer.B_PUNCH, 3)
	player._input_tick = 3

func test_scan_fires_matched_grapple():
	player.motions = _table_with_hip_toss()
	_feed_hip_toss_motion()
	var fired := player.scan_specials()
	assert_true(fired, "scan_specials returns true when a motion fires")
	assert_true(player.is_attacking(), "the grapple sequence started")
	assert_eq(player.current_move().id, "hip_toss_seq")

func test_scan_clears_buffer_on_fire():
	player.motions = _table_with_hip_toss()
	_feed_hip_toss_motion()
	player.scan_specials()
	assert_eq(player.motion_buffer.size(), 0, "buffer cleared so the edge can't re-trigger")

func test_scan_noop_without_registry():
	_feed_hip_toss_motion()
	assert_false(player.scan_specials(), "no registry -> nothing fires")

func test_scan_noop_while_attacking():
	player.motions = _table_with_hip_toss()
	player.start_move(_grab_seq())   # already attacking
	_feed_hip_toss_motion()
	assert_false(player.scan_specials(), "no special dispatch mid-attack")
