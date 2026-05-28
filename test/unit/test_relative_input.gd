extends "res://addons/gut/test.gd"

func test_toward_when_input_matches_facing():
	var r := RelativeInput.resolve(Vector2(1, 0), 1.0)   # pushing right, facing right
	assert_true(r.toward)
	assert_false(r.away)

func test_away_when_input_opposes_facing():
	var r := RelativeInput.resolve(Vector2(-1, 0), 1.0)  # pushing left, facing right
	assert_true(r.away)
	assert_false(r.toward)

func test_toward_is_relative_to_facing_left():
	var r := RelativeInput.resolve(Vector2(-1, 0), -1.0) # pushing left, facing left
	assert_true(r.toward, "left input is 'toward' when facing left")

func test_vertical_flags_are_absolute():
	var up := RelativeInput.resolve(Vector2(0, -1), 1.0)
	var down := RelativeInput.resolve(Vector2(0, 1), 1.0)
	assert_true(up.up)
	assert_true(down.down)

func test_neutral_input_has_no_flags():
	var r := RelativeInput.resolve(Vector2.ZERO, 1.0)
	assert_false(r.toward or r.away or r.up or r.down)
