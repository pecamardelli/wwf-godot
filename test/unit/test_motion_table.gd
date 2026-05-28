extends "res://addons/gut/test.gd"

func _move(id: String) -> MotionMove:
	var m := MotionMove.new(); m.move_id = id; return m

func _seq(id: String) -> MoveSequence:
	var s := MoveSequence.new(); s.id = id; return s

func test_lookup_returns_sequence_for_matched_move():
	var t := MotionTable.new()
	var seq := _seq("hip_toss_seq")
	t.add(_move("hip_toss"), seq)
	assert_eq(t.lookup("hip_toss"), seq)

func test_lookup_unknown_returns_null():
	var t := MotionTable.new()
	assert_null(t.lookup("nope"))

func test_moves_preserves_insertion_order():
	var t := MotionTable.new()
	t.add(_move("a"), _seq("sa"))
	t.add(_move("b"), _seq("sb"))
	var ids := []
	for m in t.moves():
		ids.append(m.move_id)
	assert_eq(ids, ["a", "b"], "scan order is authoring order (arcade table order)")
