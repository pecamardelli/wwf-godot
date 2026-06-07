extends "res://addons/gut/test.gd"
## SoundPool selection: weighted-always-pick (swing/hit) and chance-with-silence (attack/pain).

# --- pick_from_roll: deterministic boundary math (roll is pre-normalized) ---
func test_weighted_pick_from_roll_walks_cumulative():
	var w := [50.0, 50.0, 30.0]   # total 130
	assert_eq(SoundPool.pick_from_roll(w, 0.0, false), 0)
	assert_eq(SoundPool.pick_from_roll(w, 49.9, false), 0)
	assert_eq(SoundPool.pick_from_roll(w, 50.0, false), 1)
	assert_eq(SoundPool.pick_from_roll(w, 100.0, false), 2)
	assert_eq(SoundPool.pick_from_roll(w, 129.9, false), 2)

func test_chance_pick_from_roll_has_a_silence_band():
	var w := [0.2, 0.2]   # sum 0.4 -> 60% silence
	assert_eq(SoundPool.pick_from_roll(w, 0.0, true), 0)
	assert_eq(SoundPool.pick_from_roll(w, 0.19, true), 0)
	assert_eq(SoundPool.pick_from_roll(w, 0.2, true), 1)
	assert_eq(SoundPool.pick_from_roll(w, 0.39, true), 1)
	assert_eq(SoundPool.pick_from_roll(w, 0.4, true), -1)   # silence
	assert_eq(SoundPool.pick_from_roll(w, 0.99, true), -1)

# --- pick_index: rolls through the rng ---
func test_weighted_index_never_silent():
	var w := [0.0, 1.0]   # zero-weight entry is never picked
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	for _i in range(50):
		assert_eq(SoundPool.pick_index(w, rng, false), 1)

func test_chance_index_is_sometimes_silent():
	var w := [0.5]   # ~50% silence
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var silent := 0
	for _i in range(400):
		if SoundPool.pick_index(w, rng, true) == -1:
			silent += 1
	assert_between(silent, 120, 280, "roughly half are silent over 400 draws")

func test_zero_total_is_silent():
	assert_eq(SoundPool.pick_index([0.0, 0.0], RandomNumberGenerator.new(), false), -1)

# --- pick_stream wires the index to the streams array ---
func test_pick_stream_returns_null_on_silence():
	var p := SoundPool.new()
	p.streams = [AudioStreamWAV.new()]
	p.weights = [0.0]; p.chance_gated = true
	assert_null(p.pick_stream(RandomNumberGenerator.new()), "sum 0 -> silence -> null")

func test_pick_stream_returns_the_chosen_variant():
	var p := SoundPool.new()
	var a := AudioStreamWAV.new(); var b := AudioStreamWAV.new()
	p.streams = [a, b]; p.weights = [0.0, 1.0]; p.chance_gated = false
	assert_eq(p.pick_stream(RandomNumberGenerator.new()), b)
