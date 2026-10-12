class_name CastleInputMap
extends RefCounted
## Registers the castle view's input actions at runtime ("castle_<action>", every controller):
## orbit_left/right/up/down (WASD/arrows, right stick, d-pad), zoom_in/zoom_out (Page Up/Down,
## +/-, triggers) and close (Esc, Backspace, controller B). The mouse wheel and drags are read
## directly by CastleCamera.

const PREFIX := "castle_"
const STICK_DEADZONE := 0.2
const BUTTON_DEADZONE := 0.5
const ALL_PADS := -1


static func register() -> void:
	if InputMap.has_action(PREFIX + "close"):
		return
	_add("orbit_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_RIGHT_X, -1.0),
		_button(JOY_BUTTON_DPAD_LEFT)], STICK_DEADZONE)
	_add("orbit_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_RIGHT_X, 1.0),
		_button(JOY_BUTTON_DPAD_RIGHT)], STICK_DEADZONE)
	_add("orbit_up", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_RIGHT_Y, -1.0),
		_button(JOY_BUTTON_DPAD_UP)], STICK_DEADZONE)
	_add("orbit_down", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_RIGHT_Y, 1.0),
		_button(JOY_BUTTON_DPAD_DOWN)], STICK_DEADZONE)
	_add("zoom_in", [_key(KEY_PAGEUP), _key(KEY_KP_ADD), _key(KEY_EQUAL),
		_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)], STICK_DEADZONE)
	_add("zoom_out", [_key(KEY_PAGEDOWN), _key(KEY_KP_SUBTRACT), _key(KEY_MINUS),
		_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)], STICK_DEADZONE)
	_add("close", [_key(KEY_ESCAPE), _key(KEY_BACKSPACE), _button(JOY_BUTTON_B)], BUTTON_DEADZONE)


## Orbit input, at most length 1: x turns the view, y tilts it (positive looks from higher up).
static func orbit_vector() -> Vector2:
	return Input.get_vector(
		PREFIX + "orbit_left", PREFIX + "orbit_right", PREFIX + "orbit_down", PREFIX + "orbit_up"
	)


## Zoom input: positive zooms in.
static func zoom_axis() -> float:
	return Input.get_axis(PREFIX + "zoom_out", PREFIX + "zoom_in")


static func _add(action: String, events: Array[InputEvent], deadzone: float) -> void:
	InputMap.add_action(PREFIX + action, deadzone)
	for event: InputEvent in events:
		InputMap.action_add_event(PREFIX + action, event)


static func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


static func _button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = ALL_PADS
	event.button_index = button
	return event


static func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = ALL_PADS
	event.axis = axis
	event.axis_value = value
	return event
