extends "res://addons/gut/test.gd"
## The generated hair_pickup sequence: a grapple that reaches (grab window), hoists the victim
## through lifted -> liftgrabbed, and settles on the held headlocked loop at the lock offset.

func _seq() -> MoveSequence:
	return load("res://assets/sequences/doink/hair_pickup.tres")

func test_is_a_grapple():
	assert_true(_seq().is_grapple, "hair pickup drives the victim channel")

func test_has_a_grab_window():
	var gw: SequenceFrame = null
	for f in _seq().frames:
		if f.command == SequenceFrame.Command.WAIT_HIT_OPP and f.attack_box != null:
			gw = f
	assert_not_null(gw, "a WAIT_HIT_OPP frame with a grab box exists")
	assert_lte(gw.attack_box.offset.y, 50.0, "grab box is LOW (reaches a downed foe, not standing height)")

func test_hoists_through_lift_clips_in_order():
	# First appearance of each victim clip must be lifted, then liftgrabbed, then headlocked.
	var order: Array = []
	for f in _seq().frames:
		if f.slave_anim != "" and (order.is_empty() or order.back() != f.slave_anim):
			order.append(f.slave_anim)
	assert_eq(order, ["lifted", "liftgrabbed", "headlocked"], "victim hoist order")

func test_every_lift_frame_is_covered_no_drop():
	# The hoist must show every frame of lifted and liftgrabbed (no skipped puppet frames).
	var sf: SpriteFrames = load("res://assets/sprites/doink/doink_frames.tres")
	var seen := {"lifted": {}, "liftgrabbed": {}}
	for f in _seq().frames:
		if seen.has(f.slave_anim):
			seen[f.slave_anim][f.victim_anim_frame] = true
	assert_eq(seen["lifted"].size(), sf.get_frame_count("lifted"), "all lifted frames shown")
	assert_eq(seen["liftgrabbed"].size(), sf.get_frame_count("liftgrabbed"), "all liftgrabbed frames shown")

func test_settles_at_the_hold_offset():
	var last: SequenceFrame = _seq().frames.back()
	assert_eq(last.slave_anim, "headlocked", "lands on the held loop")
	assert_almost_eq(last.victim_offset.x, Fighter._HEADHOLD_VICTIM_X, 0.5,
		"final offset matches the static hold continuation")
	assert_almost_eq(last.victim_offset.y, 0.0, 0.5, "victim lands on the floor line, not floating")

func test_no_damage_or_detach():
	# The head-hold follow-ups own damage + release; the lift itself does neither.
	for f in _seq().frames:
		assert_ne(f.command, SequenceFrame.Command.DAMAGE_OPP)
		assert_ne(f.command, SequenceFrame.Command.DETACH)
