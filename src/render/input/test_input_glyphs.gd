extends GutTest
## Bindings in words: the notation reads and writes every event of the table, keys are named
## by their label, mouse buttons in words, controller buttons the Xbox way, and a prompt
## frames the first binding for the device family. Texts are checked in English.

const KEYS := InputTable.Family.KEYS
const PAD := InputTable.Family.PAD

var _locale_before: String


func before_all() -> void:
	_locale_before = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	InputTable.register()
	InputTable.restore()


func after_all() -> void:
	TranslationServer.set_locale(_locale_before)
	InputOverrides.load_file()


func test_the_notation_reads_events() -> void:
	var key := InputNotation.event("key:Kp Add") as InputEventKey
	assert_eq(key.physical_keycode, KEY_KP_ADD)
	assert_eq(key.keycode, KEY_NONE, "a position on the keyboard, not a label")
	var click := InputNotation.event("mouse:right") as InputEventMouseButton
	assert_eq(click.button_index, MOUSE_BUTTON_RIGHT)
	var button := InputNotation.event("pad:lb", 1) as InputEventJoypadButton
	assert_eq([button.button_index, button.device], [JOY_BUTTON_LEFT_SHOULDER, 1])
	var stick := InputNotation.event("axis:left_y-") as InputEventJoypadMotion
	assert_eq([stick.axis, stick.axis_value, stick.device], [JOY_AXIS_LEFT_Y, -1.0, -1])
	var trigger := InputNotation.event("axis:rt", 0) as InputEventJoypadMotion
	assert_eq([trigger.axis, trigger.axis_value], [JOY_AXIS_TRIGGER_RIGHT, 1.0])


func test_the_notation_knows_what_is_no_event() -> void:
	var nonsense: Array[String] = [
		"", "W", "key:", "key:NoSuchKey", "mouse:wheel", "mouse:pointer", "pad:paddle",
		"axis:left_y", "axis:left_z+", "axis:lt-", "stick:left",
	]
	for token: String in nonsense:
		assert_null(InputNotation.event(token), token)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	assert_eq(InputNotation.token(wheel), "", "the wheel cannot be bound")
	var guide := InputEventJoypadButton.new()
	guide.button_index = JOY_BUTTON_GUIDE
	assert_eq(InputNotation.token(guide), "")
	assert_eq(InputNotation.token(InputEventKey.new()), "", "a key without a code")
	assert_true(InputNotation.is_pad("axis:rt"))
	assert_true(InputNotation.is_pad("pad:a"))
	assert_false(InputNotation.is_pad("mouse:left"))


func test_every_event_of_the_table_is_written_as_it_was_read() -> void:
	var seen := 0
	for scene: String in InputTable.scenes():
		for action: String in InputTable.actions(scene):
			for family: InputTable.Family in [KEYS, PAD]:
				for token: String in InputTable.tokens(scene, action, family):
					assert_eq(InputNotation.token(InputNotation.event(token, 1)), token)
					seen += 1
	assert_gt(seen, 150)
	var strong := InputEventJoypadMotion.new()
	strong.axis = JOY_AXIS_RIGHT_X
	strong.axis_value = 0.8
	assert_eq(InputNotation.token(strong), "axis:right_x+", "a push names its direction")
	var labelled := InputEventKey.new()
	labelled.keycode = KEY_ENTER
	assert_eq(InputNotation.token(labelled), "key:Enter", "the engine's own actions use labels")


func test_keys_are_named_by_their_label() -> void:
	assert_eq(InputGlyphs.key_label(KEY_W), "W")
	assert_eq(InputGlyphs.key_label(KEY_1), "1")
	assert_eq(InputGlyphs.key_label(KEY_F1), "F1")
	assert_eq(InputGlyphs.key_label(KEY_EQUAL), "=")
	assert_eq(InputGlyphs.key_label(0xFC as Key), "Ü", "a label outside the US layout")
	assert_eq(InputGlyphs.key_label(KEY_UP), "↑")
	assert_eq(InputGlyphs.key_label(KEY_SPACE), "Space")
	assert_eq(InputGlyphs.key_label(KEY_ESCAPE), "Esc")
	assert_eq(InputGlyphs.key_label(KEY_PAGEUP), "Page Up")
	assert_eq(InputGlyphs.key_label(KEY_SHIFT), "Shift")
	assert_eq(InputGlyphs.key_label(KEY_KP_ADD), "Num +")
	assert_eq(InputGlyphs.key_label(KEY_KP_7), "Num 7")
	assert_eq(InputGlyphs.key_label(KEY_KP_ENTER), "Num Enter")
	assert_eq(InputGlyphs.key_label(KEY_SCROLLLOCK), "ScrollLock", "the engine's name otherwise")
	TranslationServer.set_locale("de")
	assert_eq(InputGlyphs.key_label(KEY_SPACE), "Leertaste")
	assert_eq(InputGlyphs.key_label(KEY_PAGEDOWN), "Bild ab")
	TranslationServer.set_locale("en")
	# Layout-independent keys also by position; letters depend on the player's keyboard.
	assert_eq(InputGlyphs.text("key:Space"), "Space")
	assert_eq(InputGlyphs.text("key:Left"), "←")


func test_mouse_buttons_are_words() -> void:
	assert_eq(InputGlyphs.text("mouse:left"), "Left mouse")
	assert_eq(InputGlyphs.text("mouse:wheel"), "Mouse wheel")
	assert_eq(InputGlyphs.text("mouse:shift_wheel"), "Shift + mouse wheel")
	TranslationServer.set_locale("de")
	assert_eq(InputGlyphs.text("mouse:right"), "Maus rechts")
	assert_eq(InputGlyphs.text("mouse:pointer"), "Mauszeiger")
	TranslationServer.set_locale("en")
	for button: String in InputNotation.MOUSE_BUTTONS:
		assert_false(InputGlyphs.text("mouse:" + button).begins_with("INPUT_"), button)


func test_controller_buttons_read_the_xbox_way() -> void:
	var names := {
		"pad:a": "A", "pad:b": "B", "pad:x": "X", "pad:y": "Y", "pad:lb": "LB", "pad:rb": "RB",
		"axis:lt": "LT", "axis:rt": "RT", "pad:start": "Start", "pad:back": "Back",
		"pad:dpad_up": "D-pad ↑", "pad:dpad_left": "D-pad ←", "pad:ls": "L-stick click",
		"axis:left_y-": "L-stick ↑", "axis:left_y+": "L-stick ↓", "axis:left_x-": "L-stick ←",
		"axis:right_x+": "R-stick →", "axis:right_y+": "R-stick ↓",
	}
	for token: String in names:
		assert_eq(InputGlyphs.text(token), names[token], token)
	TranslationServer.set_locale("de")
	assert_eq(InputGlyphs.text("pad:dpad_down"), "Steuerkreuz ↓")
	TranslationServer.set_locale("en")
	for button: String in InputNotation.PAD_BUTTONS:
		var text := InputGlyphs.text("pad:" + button)
		assert_false(text == button or text.begins_with("INPUT_"), button)


func test_every_binding_and_fixed_row_of_the_table_has_words() -> void:
	for scene: String in InputTable.scenes():
		var tokens := PackedStringArray()
		for action: String in InputTable.actions(scene):
			tokens.append_array(InputTable.tokens(scene, action, KEYS))
			tokens.append_array(InputTable.tokens(scene, action, PAD))
		for fixed_name: String in InputTable.fixed(scene):
			tokens.append_array(InputTable.fixed_tokens(scene, fixed_name))
		for token: String in tokens:
			var text := InputGlyphs.text(token)
			assert_false(text.is_empty() or text.contains("INPUT_") or text.contains(":"), token)


func test_several_events_are_joined_and_a_prompt_frames_the_first() -> void:
	assert_eq(InputGlyphs.join(InputTable.tokens("battle", "up", KEYS)), "W / ↑")
	assert_eq(InputGlyphs.join(InputTable.tokens("battle", "group_prev", PAD)), "LT / LB")
	assert_eq(InputGlyphs.join(PackedStringArray()), "")
	var attack := InputTable.tokens("battle", "attack", KEYS)
	assert_eq(InputGlyphs.prompt(attack, KEYS, "Attack"), "[Space] Attack")
	assert_eq(InputGlyphs.prompt(PackedStringArray(["pad:a"]), PAD, "Attack"), "(A) Attack")
	assert_eq(InputGlyphs.prompt(PackedStringArray(["pad:a", "pad:b"]), PAD, ""), "(A)")
	assert_eq(InputGlyphs.prompt(PackedStringArray(), PAD, "Attack"), "", "nothing to press")


func test_the_fixed_actions_of_the_app_are_read_from_the_input_map() -> void:
	assert_eq(InputGlyphs.action_tokens(&"ui_accept", PAD), PackedStringArray(["pad:a"]))
	assert_eq(InputGlyphs.action_tokens(&"ui_cancel", PAD), PackedStringArray(["pad:b"]))
	assert_eq(InputGlyphs.action_tokens(&"ui_cancel", KEYS), PackedStringArray(["key:Escape"]))
	assert_has(InputGlyphs.action_tokens(&"ui_accept", KEYS), "key:Enter")
	assert_eq(InputGlyphs.action_tokens(App.PAUSE_ACTION, KEYS), PackedStringArray(["key:Escape"]))
	assert_eq(InputGlyphs.action_tokens(App.PAUSE_ACTION, PAD), PackedStringArray(["pad:start"]))
	assert_eq(InputGlyphs.action_tokens(&"no_such_action", PAD).size(), 0)
