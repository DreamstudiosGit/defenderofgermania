class_name MapInputMap
extends RefCounted
## The map camera's input actions, one set per device like BattleInputMap: "map_kb_<action>"
## for keyboard and mouse, "map_pad<n>_<action>" for controller n. Actions: up, down, left,
## right (pan), zoom_in, zoom_out. Their bindings are data (data/input.json, InputTable).

const PADS := InputTable.PADS


static func prefixes() -> Array[String]:
	var result: Array[String] = ["map_kb_"]
	for pad: int in PADS:
		result.append("map_pad%d_" % pad)
	return result


static func register() -> void:
	InputTable.register()


## Pan input of all devices together, at most length 1; y points south (down the screen).
static func pan_vector() -> Vector2:
	var total := Vector2.ZERO
	for p: String in prefixes():
		total += Input.get_vector(p + "left", p + "right", p + "up", p + "down")
	return total.limit_length(1.0)


## Zoom input of all devices together: positive zooms in.
static func zoom_axis() -> float:
	var total := 0.0
	for p: String in prefixes():
		total += Input.get_axis(p + "zoom_out", p + "zoom_in")
	return clampf(total, -1.0, 1.0)
