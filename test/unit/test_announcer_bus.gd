extends "res://addons/gut/test.gd"
## The announcer routes through its own bus so its mix is independent of SFX/Voice.

func test_announcer_bus_exists_and_routes_to_master():
	var idx := AudioServer.get_bus_index("Announcer")
	assert_true(idx >= 0, "Announcer bus present")
	assert_eq(AudioServer.get_bus_send(idx), &"Master", "Announcer routes to Master")
