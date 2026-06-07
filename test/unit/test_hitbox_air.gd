extends "res://addons/gut/test.gd"
## Box3 already has a Y axis; verify the height parameter actually separates boxes vertically,
## and that hurt_box_for_mode handles INAIR.

func _box(w: float, h: float, d: float, oy: float) -> Box3:
	var b := Box3.new(); b.size = Vector3(w, h, d); b.offset = Vector3(0, oy, 0); return b

func test_height_separates_boxes_vertically():
	var a := _box(40, 40, 40, 0)
	var b := _box(40, 40, 40, 0)
	# Same X/Z. At equal height they overlap; lift one by 200 and they no longer do.
	assert_true(Hitbox.boxes_overlap(a, Vector2(0, 400), 1.0, 0.0, b, Vector2(0, 400), 1.0, 0.0))
	assert_false(Hitbox.boxes_overlap(a, Vector2(0, 400), 1.0, 0.0, b, Vector2(0, 400), 1.0, 200.0))

func test_inair_hurt_box_exists():
	var hb := Hitbox.hurt_box_for_mode(Fighter.Mode.INAIR)
	assert_not_null(hb)
	assert_gt(hb.size.y, 0.0)
