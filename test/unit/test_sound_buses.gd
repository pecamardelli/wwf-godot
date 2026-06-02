extends "res://addons/gut/test.gd"
## The audio bus layout the sound system routes through must exist at runtime.

func test_buses_exist():
	assert_true(AudioServer.get_bus_index("Master") >= 0, "Master bus present")
	assert_true(AudioServer.get_bus_index("SFX") >= 0, "SFX bus present")
	assert_true(AudioServer.get_bus_index("Voice") >= 0, "Voice bus present")
	assert_true(AudioServer.get_bus_index("Music") >= 0, "Music bus present (stub)")

func test_sfx_and_voice_route_to_master():
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index("SFX")), &"Master")
	assert_eq(AudioServer.get_bus_send(AudioServer.get_bus_index("Voice")), &"Master")
