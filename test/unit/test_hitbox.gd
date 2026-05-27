extends "res://addons/gut/test.gd"

func _box(ox, oy, oz, w, h, d) -> Box3:
	var b := Box3.new()
	b.offset = Vector3(ox, oy, oz)
	b.size = Vector3(w, h, d)
	return b

func test_world_aabb_offsets_toward_facing():
	# offset.x extends toward facing: facing -1 mirrors it to the left.
	# centre x = 100 + (-1)*20 = 80; width 10 -> [75, 85].
	var aabb := Box3.world_aabb(_box(20, 86, 0, 10, 10, 10), Vector2(100, 400), -1.0, 0.0)
	assert_almost_eq(aabb.position.x, 75.0, 0.01)
	assert_almost_eq(aabb.end.x, 85.0, 0.01)

func test_overlapping_boxes_hit():
	var a := _box(0, 50, 0, 40, 40, 60)
	var b := _box(0, 50, 0, 40, 40, 60)
	assert_true(Hitbox.boxes_overlap(a, Vector2(100, 400), 1.0, 0.0,
	                                  b, Vector2(120, 405), 1.0, 0.0), "20px apart, within widths")

func test_disjoint_on_depth_misses():
	var a := _box(0, 50, 0, 40, 40, 10)
	var b := _box(0, 50, 0, 40, 40, 10)
	assert_false(Hitbox.boxes_overlap(a, Vector2(100, 400), 1.0, 0.0,
	                                  b, Vector2(100, 460), 1.0, 0.0), "60px apart in depth (Z) -> miss")

func test_standing_hurt_box_depth_is_60():
	var hb := Hitbox.hurt_box_for_mode(Fighter.Mode.NORMAL)
	assert_almost_eq(hb.size.z, 60.0, 0.01)
	assert_almost_eq(hb.offset.z, 0.0, 0.01)

func test_running_hurt_box_is_thin():
	var hb := Hitbox.hurt_box_for_mode(Fighter.Mode.RUNNING)
	assert_almost_eq(hb.size.z, 10.0, 0.01)

func test_hit_side_is_left_when_attacker_is_to_the_right():
	assert_eq(Hitbox.hit_side(Vector2(120, 400), Vector2(100, 400)), -1, "attacker on +x => push victim -x")
