class_name BattleInputMap
extends RefCounted
## Registers the battle's input actions at runtime, one set per device: "battle_kb_<action>"
## for keyboard and mouse, "battle_pad<n>_<action>" for controller n (joypad device n).

enum Device { KEYBOARD, PAD_1, PAD_2 }

const PADS := 2
const SLOTS := 4
const STICK_DEADZONE := 0.25
const BUTTON_DEADZONE := 0.5


static func prefix(device: int) -> String:
	if device == Device.KEYBOARD:
		return "battle_kb_"
	return "battle_pad%d_" % (device - Device.PAD_1)


static func register() -> void:
	if InputMap.has_action(prefix(Device.KEYBOARD) + "attack"):
		return
	_register_keyboard()
	for pad: int in PADS:
		_register_pad(pad)


static func _register_keyboard() -> void:
	var p := prefix(Device.KEYBOARD)
	_add(p + "up", [_key(KEY_W), _key(KEY_UP)], STICK_DEADZONE)
	_add(p + "down", [_key(KEY_S), _key(KEY_DOWN)], STICK_DEADZONE)
	_add(p + "left", [_key(KEY_A), _key(KEY_LEFT)], STICK_DEADZONE)
	_add(p + "right", [_key(KEY_D), _key(KEY_RIGHT)], STICK_DEADZONE)
	_add(p + "group_prev", [_key(KEY_Q)], BUTTON_DEADZONE)
	_add(p + "group_next", [_key(KEY_E)], BUTTON_DEADZONE)
	var digits: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4]
	for slot: int in SLOTS:
		_add(p + "slot_%d" % (slot + 1), [_key(digits[slot])], BUTTON_DEADZONE)
	_add(p + "attack", [_key(KEY_SPACE)], BUTTON_DEADZONE)
	_add(p + "formation", [_key(KEY_F)], BUTTON_DEADZONE)
	_add(p + "rally", [_key(KEY_R)], BUTTON_DEADZONE)
	_add(p + "menu", [_key(KEY_ESCAPE)], BUTTON_DEADZONE)


static func _register_pad(pad: int) -> void:
	var p := prefix(Device.PAD_1 + pad)
	_add(
		p + "up", [_axis(pad, JOY_AXIS_LEFT_Y, -1.0), _button(pad, JOY_BUTTON_DPAD_UP)],
		STICK_DEADZONE
	)
	_add(
		p + "down", [_axis(pad, JOY_AXIS_LEFT_Y, 1.0), _button(pad, JOY_BUTTON_DPAD_DOWN)],
		STICK_DEADZONE
	)
	_add(
		p + "left", [_axis(pad, JOY_AXIS_LEFT_X, -1.0), _button(pad, JOY_BUTTON_DPAD_LEFT)],
		STICK_DEADZONE
	)
	_add(
		p + "right", [_axis(pad, JOY_AXIS_LEFT_X, 1.0), _button(pad, JOY_BUTTON_DPAD_RIGHT)],
		STICK_DEADZONE
	)
	_add(
		p + "group_prev",
		[_axis(pad, JOY_AXIS_TRIGGER_LEFT, 1.0), _button(pad, JOY_BUTTON_LEFT_SHOULDER)],
		BUTTON_DEADZONE
	)
	_add(
		p + "group_next",
		[_axis(pad, JOY_AXIS_TRIGGER_RIGHT, 1.0), _button(pad, JOY_BUTTON_RIGHT_SHOULDER)],
		BUTTON_DEADZONE
	)
	_add(p + "attack", [_button(pad, JOY_BUTTON_A)], BUTTON_DEADZONE)
	_add(p + "formation", [_button(pad, JOY_BUTTON_B)], BUTTON_DEADZONE)
	_add(p + "rally", [_button(pad, JOY_BUTTON_Y)], BUTTON_DEADZONE)
	_add(p + "menu", [_button(pad, JOY_BUTTON_START)], BUTTON_DEADZONE)


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
