class_name MerchantInputMap
extends RefCounted
## Registers the raid's input actions at runtime, one set per device as in the battle:
## "merchant_kb_<action>" for keyboard and mouse, "merchant_pad<n>_<action>" for controller n.
## Devices are BattleInputMap.Device values, so the campaign passes the same ids to both.

const STICK_DEADZONE := 0.25
const BUTTON_DEADZONE := 0.5


static func prefix(device: int) -> String:
	if device == BattleInputMap.Device.KEYBOARD:
		return "merchant_kb_"
	return "merchant_pad%d_" % (device - BattleInputMap.Device.PAD_1)


static func register() -> void:
	if InputMap.has_action(prefix(BattleInputMap.Device.KEYBOARD) + "strike"):
		return
	var p := prefix(BattleInputMap.Device.KEYBOARD)
	_add(p + "left", [_key(KEY_A), _key(KEY_LEFT)], STICK_DEADZONE)
	_add(p + "right", [_key(KEY_D), _key(KEY_RIGHT)], STICK_DEADZONE)
	_add(p + "pull", [_key(KEY_W), _key(KEY_UP), _key(KEY_E)], BUTTON_DEADZONE)
	_add(p + "strike", [_key(KEY_SPACE), _key(KEY_J), _mouse(MOUSE_BUTTON_LEFT)], BUTTON_DEADZONE)
	_add(p + "parry", [_key(KEY_S), _key(KEY_DOWN), _key(KEY_K), _mouse(MOUSE_BUTTON_RIGHT)],
		BUTTON_DEADZONE)
	_add(p + "shoot", [_key(KEY_F), _key(KEY_L)], BUTTON_DEADZONE)
	_add(p + "menu", [_key(KEY_ESCAPE)], BUTTON_DEADZONE)
	for pad: int in BattleInputMap.PADS:
		p = prefix(BattleInputMap.Device.PAD_1 + pad)
		_add(p + "left", [_axis(pad, JOY_AXIS_LEFT_X, -1.0), _button(pad, JOY_BUTTON_DPAD_LEFT)],
			STICK_DEADZONE)
		_add(p + "right", [_axis(pad, JOY_AXIS_LEFT_X, 1.0), _button(pad, JOY_BUTTON_DPAD_RIGHT)],
			STICK_DEADZONE)
		_add(p + "pull", [_button(pad, JOY_BUTTON_A)], BUTTON_DEADZONE)
		_add(p + "strike", [_button(pad, JOY_BUTTON_X)], BUTTON_DEADZONE)
		_add(p + "parry", [_button(pad, JOY_BUTTON_B), _button(pad, JOY_BUTTON_LEFT_SHOULDER)],
			BUTTON_DEADZONE)
		_add(p + "shoot", [_button(pad, JOY_BUTTON_Y), _axis(pad, JOY_AXIS_TRIGGER_RIGHT, 1.0)],
			BUTTON_DEADZONE)
		_add(p + "menu", [_button(pad, JOY_BUTTON_START)], BUTTON_DEADZONE)


static func _add(action: String, events: Array[InputEvent], deadzone: float) -> void:
	InputMap.add_action(action, deadzone)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event)


static func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


static func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
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
