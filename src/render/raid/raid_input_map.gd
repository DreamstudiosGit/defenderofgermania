class_name RaidInputMap
extends RefCounted
## Registers the castle raid's input actions at runtime, one set per device like the battle
## (BattleInputMap.Device numbering): "raid_kb_<action>" for keyboard and mouse,
## "raid_pad<n>_<action>" for controller n. Heights come from up / down held while striking or
## parrying (nothing held: middle); the mouse aims by pointing above or below the leader's body.

const PADS := 2
const STICK_DEADZONE := 0.35
const BUTTON_DEADZONE := 0.5


static func prefix(device: int) -> String:
	if device == BattleInputMap.Device.KEYBOARD:
		return "raid_kb_"
	return "raid_pad%d_" % (device - BattleInputMap.Device.PAD_1)


static func register() -> void:
	if InputMap.has_action(prefix(BattleInputMap.Device.KEYBOARD) + "strike"):
		return
	var p := prefix(BattleInputMap.Device.KEYBOARD)
	_add(p + "left", [_key(KEY_A), _key(KEY_LEFT)], STICK_DEADZONE)
	_add(p + "right", [_key(KEY_D), _key(KEY_RIGHT)], STICK_DEADZONE)
	_add(p + "high", [_key(KEY_W), _key(KEY_UP)], STICK_DEADZONE)
	_add(p + "low", [_key(KEY_S), _key(KEY_DOWN)], STICK_DEADZONE)
	_add(p + "strike", [_key(KEY_J), _key(KEY_SPACE)], BUTTON_DEADZONE)
	_add(p + "parry", [_key(KEY_K), _key(KEY_SHIFT)], BUTTON_DEADZONE)
	_add(p + "act", [_key(KEY_E)], BUTTON_DEADZONE)
	_add(p + "menu", [_key(KEY_ESCAPE)], BUTTON_DEADZONE)
	for pad: int in PADS:
		_register_pad(pad)


static func _register_pad(pad: int) -> void:
	var p := prefix(BattleInputMap.Device.PAD_1 + pad)
	_add(
		p + "left", [_axis(pad, JOY_AXIS_LEFT_X, -1.0), _button(pad, JOY_BUTTON_DPAD_LEFT)],
		STICK_DEADZONE
	)
	_add(
		p + "right", [_axis(pad, JOY_AXIS_LEFT_X, 1.0), _button(pad, JOY_BUTTON_DPAD_RIGHT)],
		STICK_DEADZONE
	)
	_add(
		p + "high",
		[
			_axis(pad, JOY_AXIS_RIGHT_Y, -1.0), _axis(pad, JOY_AXIS_LEFT_Y, -1.0),
			_button(pad, JOY_BUTTON_DPAD_UP)
		],
		STICK_DEADZONE
	)
	_add(
		p + "low",
		[
			_axis(pad, JOY_AXIS_RIGHT_Y, 1.0), _axis(pad, JOY_AXIS_LEFT_Y, 1.0),
			_button(pad, JOY_BUTTON_DPAD_DOWN)
		],
		STICK_DEADZONE
	)
	_add(
		p + "strike",
		[
			_button(pad, JOY_BUTTON_X), _button(pad, JOY_BUTTON_RIGHT_SHOULDER),
			_axis(pad, JOY_AXIS_TRIGGER_RIGHT, 1.0)
		],
		BUTTON_DEADZONE
	)
	_add(
		p + "parry",
		[
			_button(pad, JOY_BUTTON_B), _button(pad, JOY_BUTTON_LEFT_SHOULDER),
			_axis(pad, JOY_AXIS_TRIGGER_LEFT, 1.0)
		],
		BUTTON_DEADZONE
	)
	_add(p + "act", [_button(pad, JOY_BUTTON_A)], BUTTON_DEADZONE)
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
