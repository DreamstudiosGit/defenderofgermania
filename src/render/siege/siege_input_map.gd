class_name SiegeInputMap
extends RefCounted
## Registers the trebuchet minigame's input actions at runtime, one set per device like the
## battle (BattleInputMap.Device numbering): "siege_kb_<action>" for keyboard and mouse,
## "siege_pad<n>_<action>" for controller n. Up/down tilt the release angle, left/right shift
## the counterweight; the mouse uses the HUD sliders and the wheel.

const STICK_DEADZONE := 0.3
const BUTTON_DEADZONE := 0.5
const PADS := 2


static func prefix(device: int) -> String:
	if device == BattleInputMap.Device.KEYBOARD:
		return "siege_kb_"
	return "siege_pad%d_" % (device - BattleInputMap.Device.PAD_1)


static func register() -> void:
	if InputMap.has_action(prefix(BattleInputMap.Device.KEYBOARD) + "fire"):
		return
	var p := prefix(BattleInputMap.Device.KEYBOARD)
	_add(p + "angle_up", [_key(KEY_W), _key(KEY_UP)], STICK_DEADZONE)
	_add(p + "angle_down", [_key(KEY_S), _key(KEY_DOWN)], STICK_DEADZONE)
	_add(p + "weight_down", [_key(KEY_A), _key(KEY_LEFT)], STICK_DEADZONE)
	_add(p + "weight_up", [_key(KEY_D), _key(KEY_RIGHT)], STICK_DEADZONE)
	_add(p + "projectile", [_key(KEY_Q), _key(KEY_E), _key(KEY_TAB)], BUTTON_DEADZONE)
	_add(p + "fire", [_key(KEY_SPACE), _key(KEY_ENTER)], BUTTON_DEADZONE)
	_add(p + "look", [_key(KEY_C)], BUTTON_DEADZONE)
	_add(p + "menu", [_key(KEY_ESCAPE), _key(KEY_H), _key(KEY_F1)], BUTTON_DEADZONE)
	for pad: int in PADS:
		_register_pad(pad)


static func _register_pad(pad: int) -> void:
	var p := prefix(BattleInputMap.Device.PAD_1 + pad)
	_add(p + "angle_up", [_axis(pad, JOY_AXIS_LEFT_Y, -1.0), _button(pad, JOY_BUTTON_DPAD_UP)],
		STICK_DEADZONE)
	_add(p + "angle_down", [_axis(pad, JOY_AXIS_LEFT_Y, 1.0), _button(pad, JOY_BUTTON_DPAD_DOWN)],
		STICK_DEADZONE)
	_add(p + "weight_down",
		[_axis(pad, JOY_AXIS_LEFT_X, -1.0), _button(pad, JOY_BUTTON_DPAD_LEFT)], STICK_DEADZONE)
	_add(p + "weight_up",
		[_axis(pad, JOY_AXIS_LEFT_X, 1.0), _button(pad, JOY_BUTTON_DPAD_RIGHT)], STICK_DEADZONE)
	_add(p + "projectile", [_button(pad, JOY_BUTTON_X), _button(pad, JOY_BUTTON_LEFT_SHOULDER),
		_button(pad, JOY_BUTTON_RIGHT_SHOULDER)], BUTTON_DEADZONE)
	_add(p + "fire", [_button(pad, JOY_BUTTON_A)], BUTTON_DEADZONE)
	_add(p + "look", [_button(pad, JOY_BUTTON_Y), _axis(pad, JOY_AXIS_TRIGGER_LEFT, 1.0)],
		BUTTON_DEADZONE)
	_add(p + "menu", [_button(pad, JOY_BUTTON_START), _button(pad, JOY_BUTTON_BACK)],
		BUTTON_DEADZONE)


static func _add(action: String, events: Array[InputEvent], deadzone: float) -> void:
	InputMap.add_action(action, deadzone)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event)


static func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


static func _button(pad: int, button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = pad
	event.button_index = button
	return event


static func _axis(pad: int, axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = pad
	event.axis = axis
	event.axis_value = value
	return event
