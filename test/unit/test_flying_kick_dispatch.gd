extends "res://addons/gut/test.gd"
## _normal_kick_or_flying_kick: HIGH_KICK at range swaps the standing spin_kick for flying_kick.

func _spin_kick() -> MoveSequence:
	var m := MoveSequence.new(); m.id = "spin_kick"; return m

func test_far_target_swaps_to_flying_kick():
	var p := Player.new()
	add_child_autofree(p)
	var foe := Fighter.new()
	add_child_autofree(foe)
	p.global_position = Vector2(0, 400); p._set_facing(1.0)
	foe.global_position = Vector2(150, 400); foe.mode = Fighter.Mode.NORMAL
	p.target = foe
	var out := p._normal_kick_or_flying_kick(_spin_kick(), MoveTable.Btn.HIGH_KICK)
	assert_eq(out.id, "flying_kick", "far HIGH_KICK -> flying kick")

func test_close_target_also_leaps():
	var p := Player.new()
	add_child_autofree(p)
	var foe := Fighter.new()
	add_child_autofree(foe)
	p.global_position = Vector2(0, 400); p._set_facing(1.0)
	foe.global_position = Vector2(30, 400); foe.mode = Fighter.Mode.NORMAL
	p.target = foe
	var out := p._normal_kick_or_flying_kick(_spin_kick(), MoveTable.Btn.HIGH_KICK)
	assert_eq(out.id, "flying_kick", "close HIGH_KICK still leaps (arcade always LEAPATOPPs) -> a little jump")

func test_low_kick_is_untouched():
	var p := Player.new()
	add_child_autofree(p)
	var foe := Fighter.new()
	add_child_autofree(foe)
	p.global_position = Vector2(0, 400); p._set_facing(1.0)
	foe.global_position = Vector2(150, 400); foe.mode = Fighter.Mode.NORMAL
	p.target = foe
	var kick := MoveSequence.new(); kick.id = "kick"
	var out := p._normal_kick_or_flying_kick(kick, MoveTable.Btn.LOW_KICK)
	assert_eq(out.id, "kick", "low kick is never swapped")
