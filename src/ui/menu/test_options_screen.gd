extends GutTest
## The options screen: its controls write the expected UserSettings values, a tab resets to
## its defaults, a change of language is reported once the screen closed and closing saves.
## The options edited are the test's own; the player's file is never touched. Tabs, focus
## and keys: test_options_navigation.gd.

const PATH := "user://test_options/settings.cfg"
const LANGUAGE_ITEMS: Array[String] = [UserSettings.LOCALE_SYSTEM, "de", "en"]

var _settings: UserSettings
var _screen: OptionsScreen


func before_each() -> void:
	DirAccess.remove_absolute(PATH)
	_settings = UserSettings.new()
	_settings.path = PATH
	_screen = add_child_autofree(OptionsScreen.new())
	_screen.settings = _settings


func after_each() -> void:
	DirAccess.remove_absolute(PATH)
	DirAccess.remove_absolute(PATH.get_base_dir())


func test_video_controls_write_the_options() -> void:
	_screen.open()
	_choose("video_window_mode", UserSettings.WindowMode.FULLSCREEN)
	assert_eq(_settings.get_int(UserSettings.WINDOW_MODE), UserSettings.WindowMode.FULLSCREEN)
	_toggle("video_vsync", false)
	assert_false(_settings.get_bool(UserSettings.VSYNC))
	var limit := _control("video_fps_limit") as OptionButton
	assert_eq(limit.get_item_text(0), tr("OPTIONS_FPS_UNLIMITED"), "0 reads as unlimited")
	_choose("video_fps_limit", UserSettings.FPS_LIMITS.find(60))
	assert_eq(_settings.get_int(UserSettings.FPS_LIMIT), 60)
	_choose("video_quality", UserSettings.Quality.LOW)
	assert_eq(_settings.get_int(UserSettings.QUALITY), UserSettings.Quality.LOW)
	_slide("video_render_scale", 70)
	assert_almost_eq(_settings.get_float(UserSettings.RENDER_SCALE), 0.7, 0.001)
	var render := _control("video_render_scale") as HSlider
	assert_eq([render.min_value, render.max_value, render.step], [50.0, 100.0, 5.0])
	var ui := _control("video_ui_scale") as HSlider
	assert_eq([ui.min_value, ui.max_value, ui.step], [75.0, 115.0, 5.0])


func test_window_size_is_offered_in_a_window_only_and_writes_width_and_height() -> void:
	_screen.open()
	var size := _control("video_window_size") as OptionButton
	assert_true(size.disabled, "borderless by default")
	assert_eq(size.focus_mode, Control.FOCUS_NONE, "focus skips the locked row")
	_choose("video_window_mode", UserSettings.WindowMode.WINDOWED)
	assert_false(size.disabled)
	_choose("video_window_size", _item(size, "1920 × 1080"))
	assert_eq(_settings.get_int(UserSettings.WINDOW_WIDTH), 1920)
	assert_eq(_settings.get_int(UserSettings.WINDOW_HEIGHT), 1080)
	_choose("video_window_mode", UserSettings.WindowMode.BORDERLESS)
	assert_true(size.disabled)


func test_window_sizes_fit_the_screen_and_include_the_size_in_use() -> void:
	var small: Array[Vector2i] = [Vector2i(1280, 720)]
	assert_eq(OptionsVideo.window_sizes(Vector2i(1366, 768), Vector2i(1280, 720)), small)
	var deck: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1280, 800)]
	assert_eq(OptionsVideo.window_sizes(Vector2i(1280, 800), Vector2i(1280, 800)), deck)
	var odd := OptionsVideo.window_sizes(Vector2i(1920, 1080), Vector2i(1500, 850))
	assert_eq(odd.find(Vector2i(1500, 850)), 3, "a hand-edited size is listed in order")
	assert_false(Vector2i(1920, 1200) in odd)
	assert_eq(
		OptionsVideo.window_sizes(Vector2i.ZERO, Vector2i(1600, 900)), OptionsVideo.WINDOW_SIZES,
		"without a real screen every size is offered"
	)


func test_ui_scale_applies_when_the_slider_is_released() -> void:
	_screen.open()
	var slider := _control("video_ui_scale") as HSlider
	slider.drag_started.emit()
	slider.value = 90
	assert_eq(_settings.get_float(UserSettings.UI_SCALE), 1.0, "not while dragging")
	slider.drag_ended.emit(true)
	assert_almost_eq(_settings.get_float(UserSettings.UI_SCALE), 0.9, 0.001)
	slider.value = 110
	assert_almost_eq(
		_settings.get_float(UserSettings.UI_SCALE), 1.1, 0.001, "keys step it without a drag"
	)


func test_audio_controls_write_the_options() -> void:
	_screen.open()
	var keys: Dictionary[String, String] = {
		"audio_master": UserSettings.VOLUME_MASTER, "audio_music": UserSettings.VOLUME_MUSIC,
		"audio_sfx": UserSettings.VOLUME_SFX, "audio_ui": UserSettings.VOLUME_UI,
	}
	var percent := 5
	for control_name: String in keys:
		var slider := _control(control_name) as HSlider
		assert_eq([slider.min_value, slider.max_value, slider.step], [0.0, 100.0, 5.0])
		_slide(control_name, percent)
		assert_almost_eq(_settings.get_float(keys[control_name]), percent / 100.0, 0.001)
		var number := slider.get_parent().get_child(1) as Label
		assert_eq(number.text, tr("OPTIONS_PERCENT") % percent, "the value is shown")
		percent += 30
	_toggle("audio_mute_unfocused", false)
	assert_false(_settings.get_bool(UserSettings.MUTE_UNFOCUSED))


func test_game_controls_write_the_options() -> void:
	_screen.open()
	_toggle("game_rumble", false)
	assert_false(_settings.get_bool(UserSettings.RUMBLE))
	_slide("game_screen_shake", 50)
	assert_almost_eq(_settings.get_float(UserSettings.SCREEN_SHAKE), 0.5, 0.001)
	_toggle("game_slow_motion", false)
	assert_false(_settings.get_bool(UserSettings.SLOW_MOTION))
	_toggle("game_advisors", false)
	assert_false(_settings.get_bool(UserSettings.ADVISORS))
	_choose("game_locale", LANGUAGE_ITEMS.find("en"))
	assert_eq(_settings.get_string(UserSettings.LOCALE), "en")


func test_reset_restores_the_tab_in_front_only() -> void:
	_screen.open()
	_choose("video_window_mode", UserSettings.WindowMode.WINDOWED)
	_choose("video_window_size", _item(_control("video_window_size") as OptionButton, "1280 × 720"))
	_toggle("video_vsync", false)
	_slide("video_ui_scale", 85)
	_slide("audio_master", 10)
	_button("reset").pressed.emit()
	for key: String in _settings.keys():
		if key.begins_with("video/"):
			assert_eq(_settings.value_of(key), _settings.default_of(key), key)
	assert_almost_eq(_settings.get_float(UserSettings.VOLUME_MASTER), 0.1, 0.001, "audio stays")
	assert_true((_control("video_vsync") as CheckBox).button_pressed, "the controls follow")
	assert_eq((_control("video_ui_scale") as HSlider).value, 100.0)
	assert_true((_control("video_window_size") as OptionButton).disabled)


func test_a_new_language_is_reported_once_the_screen_closed() -> void:
	_settings.set_value(UserSettings.LOCALE, "de")
	_screen.open()
	watch_signals(_screen)
	_choose("game_locale", LANGUAGE_ITEMS.find("en"))
	assert_signal_not_emitted(_screen, "language_changed", "not while the screen is open")
	await get_tree().process_frame
	assert_eq((_control("game_locale") as OptionButton).selected, LANGUAGE_ITEMS.find("en"))
	_screen.close()
	assert_signal_emit_count(_screen, "closed", 1)
	assert_signal_emit_count(_screen, "language_changed", 1)


func test_the_same_language_is_not_reported() -> void:
	var system := OS.get_locale_language()
	var same := system if system in UserSettings.LOCALES else SettingsApplier.FALLBACK_LOCALE
	_settings.set_value(UserSettings.LOCALE, same)
	_screen.open()
	watch_signals(_screen)
	_choose("game_locale", LANGUAGE_ITEMS.find("en" if same == "de" else "de"))
	await get_tree().process_frame
	_choose("game_locale", LANGUAGE_ITEMS.find(UserSettings.LOCALE_SYSTEM))
	await get_tree().process_frame
	_screen.close()
	assert_eq(_settings.get_string(UserSettings.LOCALE), UserSettings.LOCALE_SYSTEM)
	assert_signal_not_emitted(_screen, "language_changed", "system resolves to the same language")
	_screen.open()
	_slide("audio_music", 20)
	_screen.close()
	assert_signal_not_emitted(_screen, "language_changed", "other options do not report it")
	# The pages replaced by the second open() are freed with the frame.
	await get_tree().process_frame


func test_language_is_locked_with_a_note_outside_the_main_menu() -> void:
	_settings.set_value(UserSettings.LOCALE, "en")
	_screen.allow_language = false
	_screen.open()
	(_screen.find_child("tabs", true, false) as TabContainer).current_tab = 2
	var language := _control("game_locale") as OptionButton
	assert_true(language.disabled)
	assert_eq(language.focus_mode, Control.FOCUS_NONE)
	var notes: Array[String] = []
	for label: Label in language.get_parent().find_children("*", "Label", true, false):
		if label.is_visible_in_tree():
			notes.append(label.text)
	assert_has(notes, tr("OPTIONS_LANGUAGE_LOCKED"))
	_toggle("game_rumble", false)
	_button("reset").pressed.emit()
	assert_true(_settings.get_bool(UserSettings.RUMBLE))
	assert_eq(_settings.get_string(UserSettings.LOCALE), "en", "a reset leaves the language")


func test_back_saves_the_options_to_their_file() -> void:
	_screen.open()
	_toggle("video_vsync", false)
	_slide("audio_music", 25)
	_button("back").pressed.emit()
	assert_false(_screen.visible)
	var loaded := UserSettings.new()
	loaded.path = PATH
	loaded.load_file()
	assert_false(loaded.get_bool(UserSettings.VSYNC))
	assert_almost_eq(loaded.get_float(UserSettings.VOLUME_MUSIC), 0.25, 0.001)


func test_every_row_has_a_title_and_a_description() -> void:
	_screen.open()
	var rows := _screen.find_children("*", "OptionRow", true, false)
	assert_eq(rows.size(), 17)
	for row: OptionRow in rows:
		var title := row.find_children("*", "Label", true, false)[0] as Label
		assert_false(title.text.is_empty() or title.text.begins_with("OPTIONS_"), row.control.name)
		assert_false(row.hint.is_empty() or row.hint.begins_with("OPTIONS_"), row.control.name)


func _control(control_name: String) -> Control:
	return _screen.find_child(control_name, true, false) as Control


func _button(button_name: String) -> Button:
	return _screen.find_child(button_name, true, false) as Button


## Picks an entry the way the list does when the player chooses it.
func _choose(control_name: String, index: int) -> void:
	var list := _control(control_name) as OptionButton
	list.select(index)
	list.item_selected.emit(index)


func _toggle(control_name: String, on: bool) -> void:
	(_control(control_name) as CheckBox).button_pressed = on


func _slide(control_name: String, percent: float) -> void:
	(_control(control_name) as HSlider).value = percent


func _item(list: OptionButton, text: String) -> int:
	for index: int in list.item_count:
		if list.get_item_text(index) == text:
			return index
	return -1
