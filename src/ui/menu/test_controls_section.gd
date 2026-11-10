extends GutTest
## The controls tab inside the options screen, driven by synthetic input: it lists every
## action of every scene, a selected binding takes the next key or controller input, a
## conflict swaps or is refused, and resets ask first. Bindings and options are the test's
## own files. Focus and scrolling: test_controls_navigation.gd.

const PATH := "user://test_controls/input.cfg"
const SETTINGS := "user://test_controls/settings.cfg"
const KEYS := InputTable.Family.KEYS
const PAD := InputTable.Family.PAD

var _path_before: String
var _locale_before: String
var _screen: OptionsScreen
var _section: ControlsSection


func before_all() -> void:
	_path_before = InputOverrides.path
	_locale_before = TranslationServer.get_locale()
	InputOverrides.path = PATH
	TranslationServer.set_locale("en")


func before_each() -> void:
	_remove_files()
	InputOverrides.load_file()
	_screen = add_child_autofree(OptionsScreen.new())
	_screen.settings = UserSettings.new()
	_screen.settings.path = SETTINGS
	_screen.open()
	_press("ui_page_up")
	_section = _screen.find_children("*", "ControlsSection", true, false)[0] as ControlsSection


func after_each() -> void:
	App.pad_in_use = false
	_remove_files()


func after_all() -> void:
	TranslationServer.set_locale(_locale_before)
	InputOverrides.path = _path_before
	InputOverrides.load_file()


func test_every_action_of_every_scene_is_listed_with_its_bindings() -> void:
	var cells := 0
	for scene: String in InputTable.scenes():
		for action: String in InputTable.actions(scene):
			var row := _row(scene, action)
			assert_not_null(row, "%s %s" % [scene, action])
			for family: InputTable.Family in [KEYS, PAD]:
				var has_binding := not InputTable.tokens(scene, action, family).is_empty()
				var rebindable := has_binding and not InputTable.is_locked(scene, action)
				assert_eq(row.cells[family] != null, rebindable, "%s %s" % [scene, action])
				cells += int(rebindable)
	assert_gt(cells, 100, "the whole table is listed")
	assert_eq(_cell("battle", "up", KEYS).text, "W / ↑")
	assert_eq(_cell("battle", "up", PAD).text, "L-stick ↑ / D-pad ↑")
	assert_eq(_focused(), _cell("map", "up", KEYS), "focus starts on the first binding")


func test_fixed_rows_are_shown_and_cannot_be_selected() -> void:
	var texts: Array[String] = []
	for label: Label in _section.find_children("*", "Label", true, false):
		texts.append(label.text)
	for fixed: String in [
		"Confirm", "Back or cancel", "Pause menu", "Start", "Move or attack", "Right mouse",
		"Mouse wheel", "Shift + mouse wheel", "Mouse pointer", "Drag the map", "Esc / H / F1",
		"Strike at pointer height",
	]:
		assert_has(texts, fixed)
	assert_false(_row("battle", "menu").is_rebindable(), "a locked action has no button")


func test_no_text_is_missing_in_either_language() -> void:
	for locale: String in UserSettings.LOCALES:
		TranslationServer.set_locale(locale)
		var section: ControlsSection = add_child_autofree(ControlsSection.new())
		var shown := section.find_children("*", "Label", true, false)
		shown.append_array(section.find_children("*", "Button", true, false))
		assert_gt(shown.size(), 200)
		for control: Control in shown:
			var text: String = control.get("text")
			assert_false(text.contains("INPUT_"), "%s: %s" % [locale, text])
	TranslationServer.set_locale("en")


func test_a_selected_binding_takes_the_next_key_and_saves() -> void:
	var cell := _cell("battle", "attack", KEYS)
	cell.grab_focus()
	_tap("ui_accept")
	assert_not_null(_capture(), "the screen waits for a key")
	_push(_key(KEY_T))
	assert_eq(InputTable.tokens("battle", "attack", KEYS), PackedStringArray(["key:T"]))
	var bound := InputMap.action_get_events(&"battle_kb_attack")[0] as InputEventKey
	assert_eq(bound.physical_keycode, KEY_T, "the game reads the new key at once")
	assert_eq(cell.text, "T")
	assert_eq(_notice().text, "Attack: now T.")
	assert_eq(_focused(), cell, "focus stays on the binding")
	var file := ConfigFile.new()
	assert_eq(file.load(PATH), OK, "saved")
	assert_eq(file.get_value("battle", "keys/attack"), ["key:T"])
	assert_eq(_cell("battle", "attack", PAD).text, "A", "the controller keeps its own")


func test_a_new_section_shows_what_was_bound() -> void:
	InputOverrides.set_binding("raid", "act", KEYS, PackedStringArray(["mouse:middle"]))
	var section: ControlsSection = add_child_autofree(ControlsSection.new())
	var cell := section.find_child("raid_act", true, false).get_node("keys") as Button
	assert_eq(cell.text, "Middle mouse")
	assert_eq(_cell("raid", "act", KEYS).text, "E", "the old one until it is refreshed")
	_section.refresh()
	assert_eq(_cell("raid", "act", KEYS).text, "Middle mouse")


func test_a_key_in_use_swaps_or_leaves_the_other_action_its_rest() -> void:
	_rebind("battle", "attack", KEYS, _key(KEY_F))
	assert_eq(_cell("battle", "attack", KEYS).text, "F")
	assert_eq(_cell("battle", "formation", KEYS).text, "Space", "swapped")
	assert_eq(_notice().text, "Attack: now F. Formation: Space instead.")
	await _capture_gone()
	_rebind("battle", "rally", KEYS, _key(KEY_UP))
	assert_eq(_cell("battle", "rally", KEYS).text, "↑")
	assert_eq(_cell("battle", "up", KEYS).text, "W", "kept its other key")
	assert_eq(_notice().text, "Rally: now ↑. Move up: only W left.")


func test_a_fixed_input_is_refused_and_says_why() -> void:
	_rebind("battle", "attack", KEYS, _click(MOUSE_BUTTON_RIGHT))
	assert_eq(_cell("battle", "attack", KEYS).text, "Space")
	assert_eq(_notice().text, "Right mouse is fixed (Move or attack).")
	assert_eq(_notice().get_theme_color("font_color"), CampaignStyle.BAD)
	assert_false(FileAccess.file_exists(PATH))
	await _capture_gone()
	_rebind("map", "zoom_in", PAD, _pad(JOY_BUTTON_START))
	assert_eq(_notice().text, "Start is fixed (Pause menu).")
	assert_true(InputTable.is_default("map", "zoom_in", PAD))


func test_escape_cancels_the_wait_and_nothing_reaches_the_options() -> void:
	var tabs := _screen.find_child("tabs", true, false) as TabContainer
	var cell := _cell("battle", "attack", KEYS)
	cell.grab_focus()
	_tap("ui_accept")
	_press("ui_page_down")
	_push(_pad(JOY_BUTTON_RIGHT_SHOULDER))
	assert_eq(tabs.current_tab, 3, "the tabs do not switch under the wait")
	_push(_key(KEY_ESCAPE))
	assert_true(_screen.visible, "Esc ends the wait, not the options")
	assert_false(_capture().visible)
	assert_true(InputTable.is_default("battle", "attack", KEYS))
	assert_eq(_focused(), cell)
	await _capture_gone()
	_press("ui_cancel")
	assert_false(_screen.visible, "afterwards Esc closes the options again")


func test_waiting_too_long_cancels() -> void:
	_cell("battle", "attack", PAD).pressed.emit()
	_capture().tick(BindingCapture.TIMEOUT)
	assert_false(_capture().visible)
	assert_true(InputTable.is_default("battle", "attack", PAD))
	await _capture_gone()
	assert_null(_capture())


func test_the_controller_rebinds_the_controller() -> void:
	var cell := _cell("battle", "attack", PAD)
	cell.grab_focus()
	_push(_pad(JOY_BUTTON_A))
	assert_null(_capture(), "the press alone does not start the wait, so A can be bound")
	_push(_pad(JOY_BUTTON_A, false))
	assert_not_null(_capture())
	_push(_pad(JOY_BUTTON_X, true, 1))
	_push(_pad(JOY_BUTTON_X, false, 1))
	assert_eq(cell.text, "X")
	for pad: int in InputTable.PADS:
		var events := InputMap.action_get_events("battle_pad%d_attack" % pad)
		assert_eq((events[0] as InputEventJoypadButton).button_index, JOY_BUTTON_X)
		assert_eq(events[0].device, pad, "both controllers alike")
	assert_eq(_focused(), cell)
	await _capture_gone()
	_push(_pad(JOY_BUTTON_DPAD_DOWN))
	assert_eq(_focused(), _cell("battle", "formation", PAD), "and moves on with the d-pad")
	_push(_pad(JOY_BUTTON_A))
	_push(_pad(JOY_BUTTON_A, false))
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_RIGHT_X
	stick.axis_value = 1.0
	_push(stick)
	assert_eq(_cell("battle", "formation", PAD).text, "R-stick →")


func test_resetting_a_scene_asks_first() -> void:
	InputOverrides.set_binding("battle", "attack", KEYS, PackedStringArray(["key:T"]))
	InputOverrides.set_binding("raid", "act", KEYS, PackedStringArray(["key:T"]))
	_section.refresh()
	var tabs := _screen.find_child("tabs", true, false) as TabContainer
	var reset := _button("reset_battle")
	reset.grab_focus()
	_tap("ui_accept")
	var dialog := _section.find_child("confirm_reset", true, false) as ConfirmDialog
	assert_true(dialog.visible)
	assert_eq(_focused(), dialog.find_child("cancel", true, false), "cancel is the safe start")
	_push(_pad(JOY_BUTTON_LEFT_SHOULDER))
	assert_eq(tabs.current_tab, 3, "the tabs do not switch under the question")
	_press("ui_cancel")
	assert_false(dialog.visible)
	assert_true(_screen.visible, "Esc answers the question, not the options")
	assert_eq(_cell("battle", "attack", KEYS).text, "T")
	assert_eq(_focused(), reset)
	_tap("ui_accept")
	_press("ui_right")
	_tap("ui_accept")
	assert_false(dialog.visible)
	assert_eq(_cell("battle", "attack", KEYS).text, "Space")
	assert_eq(_cell("raid", "act", KEYS).text, "T", "the other scene keeps its bindings")
	assert_eq(_notice().text, "Battle: defaults restored.")
	assert_eq(_focused(), reset)
	var file := ConfigFile.new()
	file.load(PATH)
	assert_eq(file.get_sections(), PackedStringArray(["raid"]))


func test_resetting_everything_asks_first() -> void:
	InputOverrides.set_binding("battle", "attack", KEYS, PackedStringArray(["key:T"]))
	InputOverrides.set_binding("raid", "act", PAD, PackedStringArray(["pad:y"]))
	_section.refresh()
	_button("reset_all").pressed.emit()
	var dialog := _section.find_child("confirm_reset", true, false) as ConfirmDialog
	(dialog.find_child("confirm", true, false) as Button).pressed.emit()
	assert_eq(_cell("battle", "attack", KEYS).text, "Space")
	assert_eq(_cell("raid", "act", PAD).text, "A")
	assert_eq(_notice().text, "All defaults restored.")
	var file := ConfigFile.new()
	file.load(PATH)
	assert_eq(file.get_sections().size(), 0)


func _row(scene: String, action: String) -> ControlsRow:
	return _section.find_child("%s_%s" % [scene, action], true, false) as ControlsRow


func _cell(scene: String, action: String, family: InputTable.Family) -> Button:
	return _row(scene, action).cells[family]


func _button(button_name: String) -> Button:
	return _screen.find_child(button_name, true, false) as Button


func _notice() -> Label:
	return _section.find_child("notice", true, false) as Label


func _capture() -> BindingCapture:
	return _section.find_child("capture", true, false) as BindingCapture


## Selects a binding and answers the wait with `event` (a click counts after a moment).
func _rebind(scene: String, action: String, family: InputTable.Family, event: InputEvent) -> void:
	_cell(scene, action, family).grab_focus()
	_cell(scene, action, family).pressed.emit()
	_capture().tick(BindingCapture.MOUSE_GUARD)
	_push(event)


## The wait swallows input for a moment after it is done; this lets it leave.
func _capture_gone() -> void:
	_capture().tick(BindingCapture.SETTLE)
	await get_tree().process_frame
	await get_tree().process_frame


func _focused() -> Control:
	return get_viewport().gui_get_focus_owner()


func _press(action: String, pressed: bool = true) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	_push(event)


## A press and its release: buttons act on the release.
func _tap(action: String) -> void:
	_press(action)
	_press(action, false)


## A key as the keyboard sends it on a US layout: its position and its label.
func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	return event


func _click(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	return event


func _pad(button: JoyButton, pressed: bool = true, joypad: int = 0) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = joypad
	event.button_index = button
	event.pressed = pressed
	return event


func _push(event: InputEvent) -> void:
	get_viewport().push_input(event)


func _remove_files() -> void:
	for path: String in [PATH, SETTINGS]:
		DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(PATH.get_base_dir())
