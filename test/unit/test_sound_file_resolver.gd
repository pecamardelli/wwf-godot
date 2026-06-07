extends "res://addons/gut/test.gd"
## Normalize filenames (lowercase, strip spaces/underscores) so the JSON's "swing4.wav" matches the
## source file "Swing 4.wav". resolve() looks up a prebuilt normalized index.

func test_normalize_strips_case_and_spaces():
	assert_eq(SoundFileResolver.normalize("Swing 4.wav"), "swing4.wav")
	assert_eq(SoundFileResolver.normalize("swing4.wav"), "swing4.wav")
	assert_eq(SoundFileResolver.normalize("Doink attack 8.wav"), "doinkattack8.wav")
	assert_eq(SoundFileResolver.normalize("Punch2.wav"), "punch2.wav")

func test_resolve_hits_the_index():
	var index := {
		"swing4.wav": "/src/Punches/Swing 4.wav",
		"punch2.wav": "/src/Punches/Punch2.wav",
	}
	assert_eq(SoundFileResolver.resolve("swing4.wav", index), "/src/Punches/Swing 4.wav")
	assert_eq(SoundFileResolver.resolve("Punch2.wav", index), "/src/Punches/Punch2.wav")

func test_resolve_missing_returns_empty():
	assert_eq(SoundFileResolver.resolve("nope.wav", {}), "")
