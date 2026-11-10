extends GutTest
## The credits: the game, the studio and the tools, the licence texts that must ship with the
## game, scrolling with stick, arrow and page keys, and Esc / B or the back button to close.

var _credits: CreditsScreen


func before_each() -> void:
	_credits = add_child_autofree(CreditsScreen.new())
	_credits.open()


func after_each() -> void:
	for action: String in ["ui_up", "ui_down"]:
		Input.action_release(action)


func test_the_credits_name_the_game_the_studio_and_the_tools() -> void:
	var text := _text().get_parsed_text()
	var version := str(ProjectSettings.get_setting("application/config/version"))
	for expected: String in [
		"THRONSTREIT 1198", version, tr("MENU_CREDITS_STUDIO"), "Godot Engine", "Jolt Physics",
		"Texturina", "Vollkorn", "SIL Open Font License 1.1",
	]:
		assert_string_contains(text, expected)


func test_the_licence_texts_that_must_ship_are_shown() -> void:
	var text := _text().get_parsed_text()
	assert_string_contains(text, _first_line(Engine.get_license_text()), "the engine's licence")
	for font_name: String in LicenceTexts.FONTS:
		var licence := LicenceTexts.font(font_name)
		assert_false(licence.is_empty(), "%s ships with its licence" % font_name)
		assert_string_contains(text, _first_line(licence))
		assert_string_contains(licence, "SIL OPEN FONT LICENSE")
	var components := Engine.get_copyright_info()
	assert_gt(components.size(), 20)
	for component: Dictionary in components:
		assert_string_contains(text, str(component["name"]))
	var licences := Engine.get_license_info()
	for licence: String in licences:
		assert_string_contains(text, _first_line(str(licences[licence])), licence)


func test_the_back_button_has_the_focus_and_closes() -> void:
	watch_signals(_credits)
	var back := _credits.find_child("back", true, false) as Button
	assert_eq(get_viewport().gui_get_focus_owner(), back)
	back.pressed.emit()
	assert_false(_credits.visible)
	assert_signal_emit_count(_credits, "closed", 1)


func test_cancel_closes() -> void:
	watch_signals(_credits)
	_press("ui_cancel")
	assert_false(_credits.visible)
	assert_signal_emit_count(_credits, "closed", 1)
	_press("ui_cancel")
	assert_signal_emit_count(_credits, "closed", 1, "closed credits leave the key alone")


func test_the_credits_only_process_while_open() -> void:
	var unopened: CreditsScreen = add_child_autofree(CreditsScreen.new())
	assert_false(unopened.is_processing(), "credits nobody opened rest")
	assert_true(_credits.is_processing(), "open credits read the stick")
	_credits.close()
	assert_false(_credits.is_processing(), "closed credits rest again")


func test_stick_and_arrow_keys_scroll_the_text() -> void:
	await wait_process_frames(3)
	var bar := _text().get_v_scroll_bar()
	assert_gt(bar.max_value, bar.page * 10.0, "the text is far longer than its window")
	Input.action_press("ui_down")
	_credits._process(0.5)
	var down := bar.value
	assert_gt(down, 0.0, "down scrolls on")
	_credits._process(0.5)
	assert_gt(bar.value - down, down, "and faster while held")
	Input.action_release("ui_down")
	var lowest := bar.value
	Input.action_press("ui_up")
	_credits._process(0.25)
	assert_lt(bar.value, lowest, "up scrolls back")


func test_page_keys_scroll_by_a_page_and_reopening_starts_at_the_top() -> void:
	await wait_process_frames(3)
	var bar := _text().get_v_scroll_bar()
	_press("ui_page_down")
	_press("ui_page_down")
	assert_almost_eq(bar.value, bar.page * 2.0, 1.0)
	_press("ui_page_up")
	assert_almost_eq(bar.value, bar.page, 1.0)
	_credits.close()
	_credits.open()
	assert_eq(bar.value, 0.0)


func _text() -> RichTextLabel:
	return _credits.find_child("text", true, false) as RichTextLabel


func _first_line(text: String) -> String:
	return text.strip_edges().get_slice("\n", 0).strip_edges()


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	get_viewport().push_input(event)
