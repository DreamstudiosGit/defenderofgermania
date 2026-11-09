extends GutTest
## The player's options: defaults, ranges, a file that survives a round trip and one that was
## edited by hand.

const PATH := "user://test_settings/settings.cfg"

var _settings: UserSettings


func before_each() -> void:
	_settings = UserSettings.new()
	_settings.path = PATH
	DirAccess.remove_absolute(PATH)


func after_each() -> void:
	DirAccess.remove_absolute(PATH)


func test_every_key_starts_at_its_default() -> void:
	for key: String in _settings.keys():
		assert_eq(_settings.value_of(key), _settings.default_of(key), key)
	assert_eq(_settings.get_float(UserSettings.UI_SCALE), 1.0)
	assert_true(_settings.get_bool(UserSettings.VSYNC))


func test_values_are_clamped_to_their_range() -> void:
	_settings.set_value(UserSettings.VOLUME_MUSIC, 3.0)
	assert_eq(_settings.get_float(UserSettings.VOLUME_MUSIC), 1.0)
	_settings.set_value(UserSettings.UI_SCALE, 0.1)
	assert_eq(_settings.get_float(UserSettings.UI_SCALE), 0.75)
	_settings.set_value(UserSettings.QUALITY, 9)
	assert_eq(_settings.get_int(UserSettings.QUALITY), UserSettings.Quality.HIGH)


func test_values_of_the_wrong_type_are_ignored() -> void:
	_settings.set_value(UserSettings.VSYNC, "yes")
	assert_true(_settings.get_bool(UserSettings.VSYNC))
	_settings.set_value(UserSettings.VOLUME_SFX, "loud")
	assert_eq(_settings.get_float(UserSettings.VOLUME_SFX), 0.8)
	_settings.set_value(UserSettings.LOCALE, "fr")
	assert_eq(_settings.get_string(UserSettings.LOCALE), UserSettings.LOCALE_SYSTEM)
	_settings.set_value(UserSettings.FPS_LIMIT, 77)
	assert_eq(_settings.get_int(UserSettings.FPS_LIMIT), 0)


func test_changed_fires_only_for_new_values() -> void:
	watch_signals(_settings)
	_settings.set_value(UserSettings.RUMBLE, true)
	assert_signal_emit_count(_settings, "changed", 0, "same value")
	_settings.set_value(UserSettings.RUMBLE, false)
	assert_signal_emitted_with_parameters(_settings, "changed", [UserSettings.RUMBLE])


func test_a_saved_file_loads_back() -> void:
	_settings.set_value(UserSettings.LOCALE, "en")
	_settings.set_value(UserSettings.VOLUME_MASTER, 0.25)
	_settings.set_value(UserSettings.WINDOW_MODE, UserSettings.WindowMode.WINDOWED)
	assert_eq(_settings.save_file(), OK)
	var loaded := UserSettings.new()
	loaded.path = PATH
	loaded.load_file()
	assert_eq(loaded.get_string(UserSettings.LOCALE), "en")
	assert_eq(loaded.get_float(UserSettings.VOLUME_MASTER), 0.25)
	assert_eq(loaded.get_int(UserSettings.WINDOW_MODE), UserSettings.WindowMode.WINDOWED)


func test_a_hand_edited_file_keeps_defaults_for_bad_entries() -> void:
	var file := ConfigFile.new()
	file.set_value("audio", "music", "broken")
	file.set_value("audio", "sfx", 0.3)
	file.set_value("video", "unknown_key", 5)
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	file.save(PATH)
	_settings.load_file()
	assert_eq(_settings.get_float(UserSettings.VOLUME_MUSIC), 0.6)
	assert_eq(_settings.get_float(UserSettings.VOLUME_SFX), 0.3)


func test_reset_restores_one_section() -> void:
	_settings.set_value(UserSettings.VOLUME_MUSIC, 0.1)
	_settings.set_value(UserSettings.RUMBLE, false)
	_settings.reset("audio")
	assert_eq(_settings.get_float(UserSettings.VOLUME_MUSIC), 0.6)
	assert_false(_settings.get_bool(UserSettings.RUMBLE), "game section untouched")
	_settings.reset()
	assert_true(_settings.get_bool(UserSettings.RUMBLE))
