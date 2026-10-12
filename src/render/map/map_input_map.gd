class_name MapInputMap
extends RefCounted
## Registers the map camera's input actions at runtime, one set per device like
## BattleInputMap: "map_kb_<action>" for keyboard and mouse, "map_pad<n>_<action>" for
## controller n. Actions: up, down, left, right (pan), zoom_in, zoom_out.

const PADS := 2
const STICK_DEADZONE := 0.2
const BUTTON_DEADZONE := 0.5


static func prefixes() -> Array[String]:
	var result: Array[String] = ["map_kb_"]
	for pad: int in PADS:
		result.append("map_pad%d_" % pad)
	return result


static func register() -> void:
	if InputMap.has_action("map_kb_up"):
		return
	var keys := "map_kb_"
	_add(keys + "up", [_key(KEY_W), _key(KEY_UP)], BUTTON_DEADZONE)
	_add(keys + "down", [_key(KEY_S), _key(KEY_DOWN)], BUTTON_DEADZONE)
	_add(keys + "left", [_key(KEY_A), _key(KEY_LEFT)], BUTTON_DEADZONE)
	_add(keys + "right", [_key(KEY_D), _key(KEY_RIGHT)], BUTTON_DEADZONE)
	_add(keys + "zoom_in", [_key(KEY_PAGEUP)], BUTTON_DEADZONE)
	_add(keys + "zoom_out", [_key(KEY_PAGEDOWN)], BUTTON_DEADZONE)
	for pad: int in PADS:
		var p := "map_pad%d_" % pad
		_add(p + "up", [_axis(pad, JOY_AXIS_LEFT_Y, -1.0)], STICK_DEADZONE)
		_add(p + "down", [_axis(pad, JOY_AXIS_LEFT_Y, 1.0)], STICK_DEADZONE)
		_add(p + "left", [_axis(pad, JOY_AXIS_LEFT_X, -1.0)], STICK_DEADZONE)
		_add(p + "right", [_axis(pad, JOY_AXIS_LEFT_X, 1.0)], STICK_DEADZONE)
		_add(p + "zoom_in", [_axis(pad, JOY_AXIS_RIGHT_Y, -1.0)], STICK_DEADZONE)
		_add(p + "zoom_out", [_axis(pad, JOY_AXIS_RIGHT_Y, 1.0)], STICK_DEADZONE)


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


static func _add(action: String, events: Array[InputEvent], deadzone: float) -> void:
	InputMap.add_action(action, deadzone)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event)


static func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


static func _axis(pad: int, axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = pad
	event.axis = axis
	event.axis_value = value
	return event
