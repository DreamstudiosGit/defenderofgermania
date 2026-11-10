class_name InputNotation
extends RefCounted
## The text form of one input event, as data/input.json and the player's user://input.cfg
## write it: "<kind>:<name>".
##   key:W  key:Up  key:Space  key:Kp Add   a key by its position on the keyboard, under the
##       name Godot gives it on a US layout (OS.get_keycode_string)
##   mouse:left  right  middle  back  forward
##   pad:a  b  x  y  lb  rb  ls  rs (stick clicks)  back  start  dpad_up  dpad_down
##       dpad_left  dpad_right
##   axis:left_x-  left_x+  left_y-  left_y+  right_x-  …  a stick pushed one way (y- is up);
##       axis:lt  axis:rt  the triggers
## Three more only describe mouse input a scene reads without an action and are no events:
## mouse:wheel, mouse:shift_wheel, mouse:pointer.

const KEY := "key"
const MOUSE := "mouse"
const PAD := "pad"
const AXIS := "axis"
const ALL_PADS := -1

const MOUSE_BUTTONS: Dictionary[String, MouseButton] = {
	"left": MOUSE_BUTTON_LEFT,
	"right": MOUSE_BUTTON_RIGHT,
	"middle": MOUSE_BUTTON_MIDDLE,
	"back": MOUSE_BUTTON_XBUTTON1,
	"forward": MOUSE_BUTTON_XBUTTON2,
}
const PAD_BUTTONS: Dictionary[String, JoyButton] = {
	"a": JOY_BUTTON_A,
	"b": JOY_BUTTON_B,
	"x": JOY_BUTTON_X,
	"y": JOY_BUTTON_Y,
	"lb": JOY_BUTTON_LEFT_SHOULDER,
	"rb": JOY_BUTTON_RIGHT_SHOULDER,
	"ls": JOY_BUTTON_LEFT_STICK,
	"rs": JOY_BUTTON_RIGHT_STICK,
	"back": JOY_BUTTON_BACK,
	"start": JOY_BUTTON_START,
	"dpad_up": JOY_BUTTON_DPAD_UP,
	"dpad_down": JOY_BUTTON_DPAD_DOWN,
	"dpad_left": JOY_BUTTON_DPAD_LEFT,
	"dpad_right": JOY_BUTTON_DPAD_RIGHT,
}
const STICK_AXES: Dictionary[String, JoyAxis] = {
	"left_x": JOY_AXIS_LEFT_X,
	"left_y": JOY_AXIS_LEFT_Y,
	"right_x": JOY_AXIS_RIGHT_X,
	"right_y": JOY_AXIS_RIGHT_Y,
}
const TRIGGER_AXES: Dictionary[String, JoyAxis] = {
	"lt": JOY_AXIS_TRIGGER_LEFT,
	"rt": JOY_AXIS_TRIGGER_RIGHT,
}


## The kind of a token ("key", "mouse", "pad", "axis") and its name.
static func split(token: String) -> PackedStringArray:
	var parts := token.split(":", true, 1)
	if parts.size() < 2:
		parts.append("")
	return parts


## True for controller tokens, false for keyboard and mouse.
static func is_pad(token: String) -> bool:
	return split(token)[0] in [PAD, AXIS]


## The event a token stands for, stamped with the joypad id for controller events; null when
## the token names no event.
static func event(token: String, joypad: int = ALL_PADS) -> InputEvent:
	var parts := split(token)
	match parts[0]:
		KEY:
			return _key_event(keycode(parts[1]))
		MOUSE:
			if MOUSE_BUTTONS.has(parts[1]):
				var click := InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTONS[parts[1]]
				return click
		PAD:
			if PAD_BUTTONS.has(parts[1]):
				var button := InputEventJoypadButton.new()
				button.device = joypad
				button.button_index = PAD_BUTTONS[parts[1]]
				return button
		AXIS:
			return _axis_event(parts[1], joypad)
	return null


## The token of an event, without its device; empty for events the notation cannot write
## (mouse wheel, unnamed keys, further controller buttons).
static func token(input: InputEvent) -> String:
	if input is InputEventKey:
		var key := input as InputEventKey
		var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		var name := OS.get_keycode_string(code)
		return "%s:%s" % [KEY, name] if code != KEY_NONE and keycode(name) == code else ""
	if input is InputEventMouseButton:
		return _named(MOUSE, MOUSE_BUTTONS.find_key((input as InputEventMouseButton).button_index))
	if input is InputEventJoypadButton:
		return _named(PAD, PAD_BUTTONS.find_key((input as InputEventJoypadButton).button_index))
	if input is InputEventJoypadMotion:
		var motion := input as InputEventJoypadMotion
		if TRIGGER_AXES.find_key(motion.axis) != null:
			return _named(AXIS, TRIGGER_AXES.find_key(motion.axis))
		var stick: Variant = STICK_AXES.find_key(motion.axis)
		if stick != null and motion.axis_value != 0.0:
			return "%s:%s%s" % [AXIS, stick, "-" if motion.axis_value < 0.0 else "+"]
	return ""


## The key a key token's name stands for; KEY_NONE for an unknown name.
static func keycode(name: String) -> Key:
	return OS.find_keycode_from_string(name) if not name.is_empty() else KEY_NONE


static func _key_event(code: Key) -> InputEventKey:
	if code == KEY_NONE:
		return null
	var key := InputEventKey.new()
	key.physical_keycode = code
	return key


static func _axis_event(name: String, joypad: int) -> InputEventJoypadMotion:
	var motion := InputEventJoypadMotion.new()
	motion.device = joypad
	motion.axis_value = 1.0
	if TRIGGER_AXES.has(name):
		motion.axis = TRIGGER_AXES[name]
		return motion
	var stick := name.left(-1)
	if not STICK_AXES.has(stick) or not name.right(1) in ["-", "+"]:
		return null
	motion.axis = STICK_AXES[stick]
	if name.ends_with("-"):
		motion.axis_value = -1.0
	return motion


static func _named(kind: String, name: Variant) -> String:
	return "%s:%s" % [kind, name] if name != null else ""
