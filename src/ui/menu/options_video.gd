class_name OptionsVideo
extends OptionsTab
## The video page of the options: window, frame pacing, 3D quality and the size of the UI.

## Common 16:9 and 16:10 window sizes; the page offers those that fit the screen.
const WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1280, 800), Vector2i(1440, 900), Vector2i(1600, 900),
	Vector2i(1680, 1050), Vector2i(1920, 1080), Vector2i(1920, 1200), Vector2i(2560, 1440),
	Vector2i(2560, 1600), Vector2i(3840, 2160),
]
const SIZE_CONTROL := "video_window_size"
const SIZE_KEYS: Array[String] = [UserSettings.WINDOW_WIDTH, UserSettings.WINDOW_HEIGHT]

var _size: OptionRow


## The sizes to offer on a screen of `screen` pixels (unknown when empty: all of them),
## always with the size in use so the row shows the truth.
static func window_sizes(screen: Vector2i, current: Vector2i) -> Array[Vector2i]:
	var sizes: Array[Vector2i] = []
	var unknown := screen.x <= 0 or screen.y <= 0
	for entry: Vector2i in WINDOW_SIZES:
		if unknown or (entry.x <= screen.x and entry.y <= screen.y):
			sizes.append(entry)
	if current not in sizes:
		sizes.append(current)
		sizes.sort()
	return sizes


func refresh() -> void:
	super()
	var current := _window_size()
	var sizes := window_sizes(_screen_size(), current)
	var names: Array[String] = []
	for entry: Vector2i in sizes:
		names.append("%d × %d" % [entry.x, entry.y])
	_size.set_choices(names, sizes)
	_size.show_value(current)
	_show_size_enabled()


func _build() -> void:
	var modes: Array[String] = [
		"OPTIONS_WINDOW_WINDOWED", "OPTIONS_WINDOW_BORDERLESS", "OPTIONS_WINDOW_FULLSCREEN",
	]
	_add_choice(
		UserSettings.WINDOW_MODE, "OPTIONS_WINDOW_MODE", _texts(modes),
		UserSettings.WindowMode.values()
	)
	var none: Array[String] = []
	_size = OptionRow.choice(tr("OPTIONS_WINDOW_SIZE"), tr("OPTIONS_WINDOW_SIZE_HINT"), none, [])
	_size.control.name = SIZE_CONTROL
	_size.changed.connect(_on_size_chosen)
	add_child(_size)
	_add_toggle(UserSettings.VSYNC, "OPTIONS_VSYNC")
	var limits: Array[String] = []
	for limit: int in UserSettings.FPS_LIMITS:
		limits.append(tr("OPTIONS_FPS_VALUE") % limit if limit > 0 else tr("OPTIONS_FPS_UNLIMITED"))
	_add_choice(UserSettings.FPS_LIMIT, "OPTIONS_FPS_LIMIT", limits, UserSettings.FPS_LIMITS)
	var levels: Array[String] = [
		"OPTIONS_QUALITY_LOW", "OPTIONS_QUALITY_MEDIUM", "OPTIONS_QUALITY_HIGH",
	]
	var quality := _add_choice(
		UserSettings.QUALITY, "OPTIONS_QUALITY", _texts(levels), UserSettings.Quality.values()
	)
	quality.set_note(tr("OPTIONS_QUALITY_NOTE"))
	_add_percent(UserSettings.RENDER_SCALE, "OPTIONS_RENDER_SCALE")
	_add_percent(UserSettings.UI_SCALE, "OPTIONS_UI_SCALE").on_release = true
	settings.changed.connect(_on_setting_changed)


func _reset_keys() -> Array[String]:
	var keys := super()
	keys.append_array(SIZE_KEYS)
	return keys


func _window_size() -> Vector2i:
	return Vector2i(
		settings.get_int(UserSettings.WINDOW_WIDTH), settings.get_int(UserSettings.WINDOW_HEIGHT)
	)


## What a window can take up on the screen it is on; empty without a real screen.
func _screen_size() -> Vector2i:
	if DisplayServer.get_name() == "headless":
		return Vector2i.ZERO
	return DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()).size


func _show_size_enabled() -> void:
	var windowed := settings.get_int(UserSettings.WINDOW_MODE) == UserSettings.WindowMode.WINDOWED
	_size.set_enabled(windowed)


func _on_size_chosen(value: Variant) -> void:
	var chosen: Vector2i = value
	settings.set_value(UserSettings.WINDOW_WIDTH, chosen.x)
	settings.set_value(UserSettings.WINDOW_HEIGHT, chosen.y)


func _on_setting_changed(key: String) -> void:
	if key == UserSettings.WINDOW_MODE:
		_show_size_enabled()
