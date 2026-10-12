class_name JoustInputMap
extends RefCounted
## Registers the joust's input actions at runtime, one set per device like the battle
## (BattleInputMap.Device): "joust_kb_<action>" for keyboard and mouse, "joust_pad<n>_<action>"
## for controller n. The mouse aims the lance (JoustInputReader); the left mouse button couches.

const STICK_DEADZONE := 0.2
const BUTTON_DEADZONE := 0.5


static func prefix(device: int) -> String:
	if device == BattleInputMap.Device.KEYBOARD:
		return "joust_kb_"
	return "joust_pad%d_" % (device - BattleInputMap.Device.PAD_1)


static func register() -> void:
	if InputMap.has_action(prefix(BattleInputMap.Device.KEYBOARD) + "spur"):
		return
	var kb := prefix(BattleInputMap.Device.KEYBOARD)
	_add(kb + "spur", [_key(KEY_SPACE)], BUTTON_DEADZONE)
	_add(kb + "strike", [_mouse(MOUSE_BUTTON_LEFT), _key(KEY_ENTER)], BUTTON_DEADZONE)
	_add(kb + "shield_up", [_key(KEY_W), _key(KEY_UP)], STICK_DEADZONE)
	_add(kb + "shield_down", [_key(KEY_S), _key(KEY_DOWN)], STICK_DEADZONE)
	_add(kb + "shield_left", [_key(KEY_A), _key(KEY_LEFT)], STICK_DEADZONE)
	_add(kb + "shield_right", [_key(KEY_D), _key(KEY_RIGHT)], STICK_DEADZONE)
	_add(kb + "menu", [_key(KEY_ESCAPE)], BUTTON_DEADZONE)
	for pad: int in BattleInputMap.PADS:
		var p := prefix(BattleInputMap.Device.PAD_1 + pad)
		_add(p + "spur", [_button(pad, JOY_BUTTON_A)], BUTTON_DEADZONE)
		_add(
			p + "strike",
			[_axis(pad, JOY_AXIS_TRIGGER_RIGHT, 1.0), _button(pad, JOY_BUTTON_RIGHT_SHOULDER)],
			BUTTON_DEADZONE
		)
		_add(p + "aim_up", [_axis(pad, JOY_AXIS_LEFT_Y, -1.0)], STICK_DEADZONE)
		_add(p + "aim_down", [_axis(pad, JOY_AXIS_LEFT_Y, 1.0)], STICK_DEADZONE)
		_add(p + "aim_left", [_axis(pad, JOY_AXIS_LEFT_X, -1.0)], STICK_DEADZONE)
		_add(p + "aim_right", [_axis(pad, JOY_AXIS_LEFT_X, 1.0)], STICK_DEADZONE)
		_add(p + "shield_up", [_axis(pad, JOY_AXIS_RIGHT_Y, -1.0)], STICK_DEADZONE)
		_add(p + "shield_down", [_axis(pad, JOY_AXIS_RIGHT_Y, 1.0)], STICK_DEADZONE)
		_add(p + "shield_left", [_axis(pad, JOY_AXIS_RIGHT_X, -1.0)], STICK_DEADZONE)
		_add(p + "shield_right", [_axis(pad, JOY_AXIS_RIGHT_X, 1.0)], STICK_DEADZONE)
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
