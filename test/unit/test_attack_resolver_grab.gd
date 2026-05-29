extends "res://addons/gut/test.gd"

var resolver: AttackResolver

func before_each():
	resolver = AttackResolver.new()
	add_child_autofree(resolver)

func _grab_seq() -> MoveSequence:
	var m := MoveSequence.new(); m.id = "g"; m.anim_name = "hip_toss"; m.is_grapple = true
	m.attack_mode = AMode.PUNCH
	var wait := SequenceFrame.new()
	wait.duration_ticks = 4; wait.command = SequenceFrame.Command.WAIT_HIT_OPP
	wait.attack_box = Box3.new(); wait.attack_box.offset = Vector3(0, 40, 0); wait.attack_box.size = Vector3(80, 80, 40)
	m.frames = [wait]
	return m

func _fighter(pos: Vector2, side: int) -> Fighter:
	var f := Fighter.new(); f.side = side
	add_child_autofree(f); f.global_position = pos
	return f

func test_grab_box_overlap_attaches_instead_of_damaging():
	var atk := _fighter(Vector2(100, 400), Fighter.Side.PLAYER)
	var vic := _fighter(Vector2(110, 400), Fighter.Side.ENEMY)
	atk.start_move(_grab_seq())
	atk._player.advance(1.0 / 60.0)   # open the WAIT_HIT_OPP box
	resolver.resolve_tick()
	assert_eq(vic.mode, Fighter.Mode.GRABBED, "grab connected -> attached")
	assert_eq(atk.mode, Fighter.Mode.GRABBING)

func test_grab_refuses_downed_victim():
	var atk := _fighter(Vector2(100, 400), Fighter.Side.PLAYER)
	var vic := _fighter(Vector2(110, 400), Fighter.Side.ENEMY)
	vic.mode = Fighter.Mode.ONGROUND
	atk.start_move(_grab_seq())
	atk._player.advance(1.0 / 60.0)
	resolver.resolve_tick()
	assert_ne(vic.mode, Fighter.Mode.GRABBED, "cannot grab a downed fighter")
