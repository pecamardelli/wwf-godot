extends "res://addons/gut/test.gd"

const FRAME := 1.0 / 60.0

func _f(dur: int, cmd: int) -> SequenceFrame:
	var f := SequenceFrame.new(); f.duration_ticks = dur; f.command = cmd; return f

func _grab_seq() -> MoveSequence:
	# windup(NONE) -> WAIT_HIT_OPP(box) -> SET_ATTACH -> DAMAGE_OPP -> DETACH
	var m := MoveSequence.new(); m.id = "g"; m.anim_name = "hip_toss"; m.is_grapple = true
	var wait := _f(4, SequenceFrame.Command.WAIT_HIT_OPP)
	wait.attack_box = Box3.new(); wait.attack_box.size = Vector3(40, 60, 10)
	wait.wait_hit_max_ticks = 16
	var attach := _f(2, SequenceFrame.Command.SET_ATTACH); attach.slave_anim = "hip_tossed"
	var dmg := _f(2, SequenceFrame.Command.DAMAGE_OPP); dmg.victim_amode = AMode.BIGBOOT
	var detach := _f(2, SequenceFrame.Command.DETACH)
	m.frames = [_f(2, SequenceFrame.Command.NONE), wait, attach, dmg, detach]
	return m

func test_wait_hit_opens_box_and_holds():
	var sp := SequencePlayer.new(); sp.play(_grab_seq())
	for _i in range(4):   # advance into the WAIT_HIT_OPP frame
		sp.advance(FRAME)
	assert_true(sp.attack_live, "grab box live on WAIT_HIT_OPP")
	assert_true(sp.is_waiting_for_hit(), "holding for a connect")
	var idx := sp._index
	for _i in range(10):  # fewer frames than the 16-tick (~19 frame) timeout
		sp.advance(FRAME)
	assert_eq(sp._index, idx, "does not advance while still within the wait window")
	assert_true(sp.is_waiting_for_hit(), "still waiting (not yet timed out)")

func test_connect_resumes_and_attaches():
	var sp := SequencePlayer.new(); sp.play(_grab_seq())
	for _i in range(4):
		sp.advance(FRAME)
	sp.notify_grab_connected()
	assert_false(sp.is_waiting_for_hit())
	for _i in range(10):   # clear the contact freeze (~4 ticks) then reach SET_ATTACH
		sp.advance(FRAME)
	assert_true(sp.consume_attach(), "attach intent surfaced once")
	assert_false(sp.consume_attach(), "attach intent is one-shot")
	assert_eq(sp.slave_anim, "hip_tossed")

func test_whiff_ends_the_move_without_playing_the_throw():
	var sp := SequencePlayer.new(); sp.play(_grab_seq())
	for _i in range(4):
		sp.advance(FRAME)
	for _i in range(30):
		sp.advance(FRAME)
	assert_true(sp.whiffed, "timed out without a connect")
	assert_false(sp.is_waiting_for_hit(), "released the hold on whiff")
	assert_false(sp.is_playing(), "whiff ends the move (no full toss in empty air)")
	assert_false(sp.damage_opp_seen, "DAMAGE_OPP never fires on a whiff")
	assert_false(sp.detach_seen, "DETACH never fires on a whiff")

func test_damage_and_detach_intents_surface_once():
	var sp := SequencePlayer.new(); sp.play(_grab_seq())
	for _i in range(4):
		sp.advance(FRAME)
	sp.notify_grab_connected()
	for _i in range(40):
		sp.advance(FRAME)
	assert_true(sp.damage_opp_seen, "DAMAGE_OPP fired")
	assert_true(sp.detach_seen, "DETACH fired")

func test_whiff_finishes_the_move_on_timeout():
	var sp := SequencePlayer.new(); sp.play(_grab_seq())
	for _i in range(4):
		sp.advance(FRAME)
	# Never connect. The move ends ON the timeout tick (no terminal stall, no throw frames).
	var finished := false
	for _i in range(60):
		if sp.advance(FRAME):
			finished = true
	assert_true(sp.whiffed, "timed out")
	assert_true(finished, "advance() returns true the moment the whiff ends the move")
	assert_false(sp.is_playing(), "attacker is not soft-locked")
	assert_false(sp.damage_opp_seen, "no phantom DAMAGE_OPP on a whiff")

func test_contact_freeze_holds_the_reach_before_the_throw():
	var sp := SequencePlayer.new(); sp.play(_grab_seq())
	for _i in range(4):
		sp.advance(FRAME)
	var idx := sp._index
	sp.notify_grab_connected()
	sp.advance(FRAME)   # first frame after contact: still in the hitstop
	assert_eq(sp._index, idx, "holds the reach frame during the contact freeze")
	assert_false(sp.consume_attach(), "the throw (SET_ATTACH) hasn't begun yet")

func _reach_grab_seq() -> MoveSequence:
	# reach(0,1) -> WAIT_HIT_OPP(2) -> connected SET_ATTACH(3) -> SLAVE_ANIM(4)
	var m := MoveSequence.new(); m.id = "neck_grab"; m.anim_name = "headlocks"
	m.is_grapple = true; m.reverse_reach_on_whiff = true
	var r0 := _f(3, SequenceFrame.Command.NONE); r0.anim_frame = 0
	var r1 := _f(3, SequenceFrame.Command.NONE); r1.anim_frame = 1
	var wait := _f(3, SequenceFrame.Command.WAIT_HIT_OPP); wait.anim_frame = 2
	wait.attack_box = Box3.new(); wait.attack_box.size = Vector3(40, 60, 10); wait.wait_hit_max_ticks = 16
	var attach := _f(4, SequenceFrame.Command.SET_ATTACH); attach.anim_frame = 3; attach.slave_anim = "headlocked"
	var pull := _f(4, SequenceFrame.Command.SLAVE_ANIM); pull.anim_frame = 4; pull.slave_anim = "headlocked"
	m.frames = [r0, r1, wait, attach, pull]
	return m

func test_whiff_reverses_the_reach_to_the_start():
	var sp := SequencePlayer.new(); sp.play(_reach_grab_seq())
	for _i in range(8):   # advance through reach 0,1 into the WAIT_HIT_OPP at index 2
		sp.advance(FRAME)
	assert_true(sp.is_waiting_for_hit(), "reached the grab window")
	# Never connect. Collect the attacker frames shown after the whiff begins.
	var seen_after_whiff := []
	for _i in range(60):
		sp.advance(FRAME)
		var f: SequenceFrame = sp.current_frame()
		if sp.whiffed and f != null:
			seen_after_whiff.append(f.anim_frame)
	assert_true(sp.whiffed, "timed out without a connect")
	assert_false(sp.attack_live, "grab box dropped while the reach retracts")
	assert_false(sp.is_playing(), "the move ends after the reach has retracted")
	# The reach retracted: frames stepped DOWN from the grab window (2) toward 0.
	assert_true(seen_after_whiff.has(1), "reverse shows reach frame 1")
	assert_true(seen_after_whiff.has(0), "reverse shows reach frame 0")
	assert_true(seen_after_whiff.find(1) < seen_after_whiff.find(0), "frames descend (2->1->0)")
	assert_false(sp.consume_attach(), "the reverse phase never fires SET_ATTACH")
	assert_false(sp.damage_opp_seen, "the reverse phase never damages")
