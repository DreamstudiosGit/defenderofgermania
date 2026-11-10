class_name InputGlyphs
extends RefCounted
## Bindings as the player reads them, for button prompts and the controls list. A key is named
## as the player's keyboard layout labels it (the binding is a position: "key:Z" reads "Y" on
## a German keyboard), mouse buttons in words, controller buttons the Xbox way: A B X Y, LB RB
## LT RT, the sticks and the D-pad with an arrow. PlayStation and Switch names are not done.

const SEPARATOR := " / "
## How a prompt frames its binding, by InputTable.Family: "[Space]", "(A)".
const FRAMES: Array[String] = ["[%s]", "(%s)"]
const UP := "↑"
const DOWN := "↓"
const LEFT := "←"
const RIGHT := "→"
const KEY_SYMBOLS: Dictionary[Key, String] = {
	KEY_UP: UP, KEY_DOWN: DOWN, KEY_LEFT: LEFT, KEY_RIGHT: RIGHT,
}
const KEY_TEXTS: Dictionary[Key, String] = {
	KEY_SPACE: "INPUT_KEY_SPACE",
	KEY_ENTER: "INPUT_KEY_ENTER",
	KEY_ESCAPE: "INPUT_KEY_ESCAPE",
	KEY_TAB: "INPUT_KEY_TAB",
	KEY_BACKSPACE: "INPUT_KEY_BACKSPACE",
	KEY_SHIFT: "INPUT_KEY_SHIFT",
	KEY_CTRL: "INPUT_KEY_CTRL",
	KEY_ALT: "INPUT_KEY_ALT",
	KEY_CAPSLOCK: "INPUT_KEY_CAPSLOCK",
	KEY_PAGEUP: "INPUT_KEY_PAGEUP",
	KEY_PAGEDOWN: "INPUT_KEY_PAGEDOWN",
	KEY_HOME: "INPUT_KEY_HOME",
	KEY_END: "INPUT_KEY_END",
	KEY_INSERT: "INPUT_KEY_INSERT",
	KEY_DELETE: "INPUT_KEY_DELETE",
}
const KEYPAD_SYMBOLS: Dictionary[Key, String] = {
	KEY_KP_ADD: "+",
	KEY_KP_SUBTRACT: "-",
	KEY_KP_MULTIPLY: "*",
	KEY_KP_DIVIDE: "/",
	KEY_KP_PERIOD: ".",
}
const PAD_NAMES: Dictionary[String, String] = {
	"a": "A", "b": "B", "x": "X", "y": "Y", "lb": "LB", "rb": "RB", "lt": "LT", "rt": "RT",
	"back": "Back", "start": "Start",
}
const PAD_TEXTS: Dictionary[String, String] = {
	"ls": "INPUT_PAD_LEFT_STICK_CLICK",
	"rs": "INPUT_PAD_RIGHT_STICK_CLICK",
	"dpad": "INPUT_PAD_DPAD",
	"left": "INPUT_PAD_LEFT_STICK",
	"right": "INPUT_PAD_RIGHT_STICK",
}
## The direction a controller token ends with.
const DIRECTIONS: Dictionary[String, String] = {
	"_up": UP, "_down": DOWN, "_left": LEFT, "_right": RIGHT,
	"_y-": UP, "_y+": DOWN, "_x-": LEFT, "_x+": RIGHT,
}


## One event (an InputNotation token) in words.
static func text(token: String) -> String:
	var parts := InputNotation.split(token)
	match parts[0]:
		InputNotation.KEY:
			return key(InputNotation.keycode(parts[1]))
		InputNotation.MOUSE:
			return _tr("INPUT_MOUSE_%s" % parts[1].to_upper())
		InputNotation.PAD, InputNotation.AXIS:
			return _pad(parts[1])
	return token


## Several events of one action: "W / ↑".
static func join(tokens: PackedStringArray) -> String:
	var texts := PackedStringArray()
	for token: String in tokens:
		texts.append(text(token))
	return SEPARATOR.join(texts)


## The key at a position of the keyboard, as the player's layout labels it.
static func key(physical: Key) -> String:
	# Only printable keys move with the layout (asked for a keypad key, it answers with the
	# main block's); without a display there is no layout, and asking logs an error.
	if physical >= KEY_SPECIAL or DisplayServer.get_name() == "headless":
		return key_label(physical)
	var label := DisplayServer.keyboard_get_label_from_physical(physical)
	return key_label(label if label != KEY_NONE else physical)


## The name of the key that carries this label.
static func key_label(label: Key) -> String:
	if KEY_SYMBOLS.has(label):
		return KEY_SYMBOLS[label]
	if KEY_TEXTS.has(label):
		return _tr(KEY_TEXTS[label])
	if label >= KEY_KP_0 and label <= KEY_KP_9:
		return _tr("INPUT_KEY_KEYPAD") % (label - KEY_KP_0)
	if KEYPAD_SYMBOLS.has(label):
		return _tr("INPUT_KEY_KEYPAD") % KEYPAD_SYMBOLS[label]
	if label == KEY_KP_ENTER:
		return _tr("INPUT_KEY_KEYPAD") % _tr("INPUT_KEY_ENTER")
	if label > KEY_SPACE and label < KEY_SPECIAL:
		return String.chr(label).to_upper()
	return OS.get_keycode_string(label)


## The events of any InputMap action for one device family as tokens: for actions outside
## the table (ui_accept, ui_cancel, App.PAUSE_ACTION).
static func action_tokens(action: StringName, family: InputTable.Family) -> PackedStringArray:
	var tokens := PackedStringArray()
	if not InputMap.has_action(action):
		return tokens
	var pad := family == InputTable.Family.PAD
	for input: InputEvent in InputMap.action_get_events(action):
		var token := InputNotation.token(input)
		if not token.is_empty() and InputNotation.is_pad(token) == pad and token not in tokens:
			tokens.append(token)
	return tokens


## A prompt for the first of the events: "[Space] Attack", "(A) Attack"; empty without one.
static func prompt(tokens: PackedStringArray, family: InputTable.Family, label: String) -> String:
	if tokens.is_empty():
		return ""
	var glyph := FRAMES[family] % text(tokens[0])
	return glyph if label.is_empty() else "%s %s" % [glyph, label]


static func _pad(name: String) -> String:
	if PAD_NAMES.has(name):
		return PAD_NAMES[name]
	if PAD_TEXTS.has(name):
		return _tr(PAD_TEXTS[name])
	for ending: String in DIRECTIONS:
		if name.ends_with(ending):
			var part := name.trim_suffix(ending)
			if PAD_TEXTS.has(part):
				return _tr(PAD_TEXTS[part]) % DIRECTIONS[ending]
	return name


static func _tr(text_key: String) -> String:
	return TranslationServer.translate(text_key)
