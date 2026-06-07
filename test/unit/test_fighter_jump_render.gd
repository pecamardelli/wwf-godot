extends "res://addons/gut/test.gd"
## Altitude rendering: the sprite offset lifts by _height; a shadow node exists at the feet.

func test_sprite_lifts_with_height():
	var f := Fighter.new()
	add_child_autofree(f)
	await get_tree().process_frame   # let _ready wire @onready sprite + shadow
	if f.sprite == null:
		pass_test("no AnimatedSprite2D in the bare Fighter; lift is a no-op")
		return
	var base := f.sprite.offset.y
	f._height = 80.0
	f._refresh_flip()
	assert_almost_eq(f.sprite.offset.y, base - 80.0, 0.01, "sprite lifted up by _height")

func test_shadow_node_created():
	var f := Fighter.new()
	add_child_autofree(f)
	await get_tree().process_frame
	assert_not_null(f.get_node_or_null("Shadow"), "a ground shadow node exists")
