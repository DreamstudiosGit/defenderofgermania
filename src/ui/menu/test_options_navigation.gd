extends GutTest
## The options screen with keys and a controller alone: the panel fits the base canvas, LB /
## RB and PageUp / PageDown switch the tabs, left and right change every kind of row, focus
## starts on the first row, never leaves the screen and returns when it closes, and the
## focused row is described. The options edited are the test's own.

const PATH := "user://test_options/settings.cfg"
const BASE := Vector2(1280, 720)

var _settings: UserSettings
var _screen: OptionsScreen


func before_each() -> void:
	_settings = UserSettings.new()
	_settings.path = PATH
	_screen = add_child_autofree(OptionsScreen.new())
	_screen.settings = _settings


func after_each() -> void:
	App.pad_in_use = false
	DirAccess.remove_absolute(PATH)
	DirAccess.remove_absolute(PATH.get_base_dir())


func test_the_panel_fits_the_base_canvas_on_every_tab() -> void:
	_screen.open()
	var panel := _screen.find_children("*", "PanelContainer", true, false)[0] as PanelContainer
	var largest: float = UserSettings.SPEC[UserSettings.UI_SCALE][2]
	var tabs := _tabs()
	for tab: int in tabs.get_tab_count():
		tabs.current_tab = tab
		var needed := panel.get_combined_minimum_size()
		assert_lte(needed.x, BASE.x / largest, "width on tab %d" % tab)
		assert_lte(needed.y, BASE.y / largest, "height on tab %d, also at the largest UI" % tab)


func test_shoulder_buttons_and_page_keys_switch_the_tabs() -> void:
	_screen.open()
	var tabs := _tabs()
	var names: Array[String] = []
	for tab: int in tabs.get_tab_count():
		names.append(String(tabs.get_tab_control(tab).name))
	assert_eq(names, OptionsScreen.PAGE_NAMES)
	var controls := tabs.get_tab_control(3).find_children("*", "ControlsSection", true, false)
	assert_eq(controls.size(), 1, "the fourth tab holds the controls")
	_push(_shoulder(JOY_BUTTON_RIGHT_SHOULDER))
	assert_eq(tabs.current_tab, 1)
	assert_eq(_focused(), _control("audio_master"))
	var prompt := _screen.find_child("tab_prompt", true, false) as Label
	assert_eq(prompt.text, tr("OPTIONS_TABS_PAD"), "the prompt names the device in use")
	_press("ui_page_down")
	assert_eq(tabs.current_tab, 2)
	assert_eq(_focused(), _control("game_locale"))
	_push(_shoulder(JOY_BUTTON_RIGHT_SHOULDER))
	assert_eq(tabs.current_tab, 3)
	assert_not_null(_focused(), "no dead end on the controls tab")
	assert_false(_button("reset").visible, "the controls reset themselves")
	_push(_shoulder(JOY_BUTTON_RIGHT_SHOULDER))
	assert_eq(tabs.current_tab, 0, "wraps around")
	assert_true(_button("reset").visible)
	_push(_shoulder(JOY_BUTTON_LEFT_SHOULDER))
	assert_eq(tabs.current_tab, 3)
	_press("ui_page_up")
	assert_eq(tabs.current_tab, 2)


func test_left_and_right_change_every_kind_of_row() -> void:
	_screen.open()
	var quality := _control("video_quality")
	quality.grab_focus()
	_press("ui_left")
	assert_eq(_settings.get_int(UserSettings.QUALITY), UserSettings.Quality.MEDIUM)
	_press("ui_right")
	_press("ui_right")
	assert_eq(_settings.get_int(UserSettings.QUALITY), UserSettings.Quality.HIGH, "no wrap")
	assert_eq(_focused(), quality, "focus stays on the row")
	var vsync := _control("video_vsync")
	vsync.grab_focus()
	_press("ui_left")
	assert_false(_settings.get_bool(UserSettings.VSYNC))
	_press("ui_right")
	assert_true(_settings.get_bool(UserSettings.VSYNC))
	assert_eq(_focused(), vsync)
	var scale := _control("video_render_scale")
	scale.grab_focus()
	_press("ui_left")
	assert_almost_eq(_settings.get_float(UserSettings.RENDER_SCALE), 0.95, 0.001)
	assert_eq(_focused(), scale)


func test_focus_starts_on_the_first_row_and_returns_when_cancel_closes() -> void:
	var before: Button = add_child_autofree(Button.new())
	before.grab_focus()
	_screen.open()
	watch_signals(_screen)
	assert_eq(_focused(), _control("video_window_mode"))
	_press("ui_cancel")
	assert_false(_screen.visible)
	assert_signal_emit_count(_screen, "closed", 1)
	assert_eq(_focused(), before)


func test_keys_never_lead_out_of_the_screen() -> void:
	_cover_the_viewport_with_buttons()
	_screen.open()
	await get_tree().process_frame
	await get_tree().process_frame
	var route: Array[String] = [
		"ui_up", "ui_up", "ui_left", "ui_down", "ui_down", "ui_down", "ui_down", "ui_down",
		"ui_down", "ui_down", "ui_right", "ui_down", "ui_left", "ui_left", "ui_down",
	]
	for action: String in route:
		_press(action)
		assert_true(_screen.is_ancestor_of(_focused()), "%s led to %s" % [action, _focused().name])
	assert_eq(_focused(), _button("reset"))
	_press("ui_up")
	assert_eq(_focused(), _control("video_ui_scale"))
	_button("back").grab_focus()
	_press("ui_focus_next")
	assert_eq(_focused(), _tabs().get_tab_bar(), "Tab starts over at the tabs")
	_press("ui_focus_prev")
	assert_eq(_focused(), _button("back"))
	_press("ui_up")
	assert_eq(_focused(), _control("video_ui_scale"))
	_press("ui_page_up")
	_press("ui_up")
	_press("ui_down")
	_press("ui_down")
	assert_eq(_focused(), _button("back"), "also on the controls tab")


func test_a_locked_row_is_passed_over() -> void:
	_screen.allow_language = false
	_screen.open()
	_press("ui_down")
	assert_eq(_focused(), _control("video_vsync"), "the window size is locked while borderless")
	_press("ui_page_down")
	_press("ui_page_down")
	assert_eq(_focused(), _control("game_rumble"), "the language is locked outside the main menu")
	_press("ui_up")
	assert_eq(_focused(), _tabs().get_tab_bar())
	_press("ui_down")
	assert_eq(_focused(), _control("game_rumble"))


func test_the_focused_row_is_described() -> void:
	_screen.open()
	var hint := _screen.find_child("hint", true, false) as Label
	assert_eq(hint.text, tr("OPTIONS_WINDOW_MODE_HINT"))
	_control("video_vsync").grab_focus()
	assert_eq(hint.text, tr("OPTIONS_VSYNC_HINT"))
	_button("back").grab_focus()
	assert_eq(hint.text, "")


func test_no_description_is_cut_off_in_either_language() -> void:
	var locale_before := TranslationServer.get_locale()
	# Windowed, so the window size row takes focus too.
	_settings.set_value(UserSettings.WINDOW_MODE, UserSettings.WindowMode.WINDOWED)
	for locale: String in UserSettings.LOCALES:
		TranslationServer.set_locale(locale)
		_screen.open()
		await get_tree().process_frame
		await get_tree().process_frame
		var hint := _screen.find_child("hint", true, false) as Label
		var tabs := _tabs()
		var described := 0
		for tab: int in tabs.get_tab_count():
			tabs.current_tab = tab
			for row: OptionRow in tabs.get_tab_control(tab).find_children("*", "OptionRow", true, false):
				row.control.grab_focus()
				assert_eq(hint.text, row.hint)
				# Counting the lines lays the new text out; the lines shown are read after it.
				var lines := hint.get_line_count()
				assert_eq(
					hint.get_visible_line_count(), lines,
					"lines shown of %s (%s)" % [row.control.name, locale]
				)
				described += 1
		assert_eq(described, 17, locale)
		_screen.close()
	TranslationServer.set_locale(locale_before)


## Stands in for the screen behind the modal: wherever Godot looks for a neighbour, one is.
func _cover_the_viewport_with_buttons() -> void:
	var grid: GridContainer = add_child_autofree(GridContainer.new())
	grid.columns = 9
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for index: int in 81:
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid.add_child(button)


func _focused() -> Control:
	return get_viewport().gui_get_focus_owner()


func _tabs() -> TabContainer:
	return _screen.find_child("tabs", true, false) as TabContainer


func _control(control_name: String) -> Control:
	return _screen.find_child(control_name, true, false) as Control


func _button(button_name: String) -> Button:
	return _screen.find_child(button_name, true, false) as Button


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_push(event)


func _shoulder(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	return event


func _push(event: InputEvent) -> void:
	get_viewport().push_input(event)
