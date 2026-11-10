class_name CastleInputMap
extends RefCounted
## The castle view's input actions ("castle_<action>", keyboard and every controller alike):
## orbit_left/right/up/down, zoom_in/zoom_out, close and timelapse (skip the time-lapse or
## watch it again). Their bindings are data (data/input.json, InputTable). The mouse wheel and
## drags are read directly by CastleCamera.

const PREFIX := "castle_"


static func register() -> void:
	InputTable.register()


## Orbit input, at most length 1: x turns the view, y tilts it (positive looks from higher up).
static func orbit_vector() -> Vector2:
	return Input.get_vector(
		PREFIX + "orbit_left", PREFIX + "orbit_right", PREFIX + "orbit_down", PREFIX + "orbit_up"
	)


## Zoom input: positive zooms in.
static func zoom_axis() -> float:
	return Input.get_axis(PREFIX + "zoom_out", PREFIX + "zoom_in")
