class_name SettingsApplier
extends RefCounted
## Turns the player's options (UserSettings) into engine state: window, frame pacing, 3D
## quality, UI scale, language and bus volumes. Headless runs (tests, smoke test) skip
## everything that needs a real window.

const MSAA_BY_QUALITY: Array[Viewport.MSAA] = [
	Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X,
]
const SHADOW_ATLAS_BY_QUALITY: Array[int] = [2048, 4096, 8192]
const BUS_BY_KEY: Dictionary[String, StringName] = {
	UserSettings.VOLUME_MASTER: &"Master",
	UserSettings.VOLUME_MUSIC: AudioBank.BUS_MUSIC,
	UserSettings.VOLUME_SFX: AudioBank.BUS_SFX,
	UserSettings.VOLUME_UI: AudioBank.BUS_UI,
}
## Language when the system's is not one of the game's.
const FALLBACK_LOCALE := "en"

var _settings: UserSettings
var _window: Window
var _headless: bool


func _init(settings: UserSettings, window: Window) -> void:
	_settings = settings
	_window = window
	_headless = DisplayServer.get_name() == "headless"


func apply_all() -> void:
	apply_window()
	apply_pacing()
	apply_quality()
	apply_ui_scale()
	apply_locale()
	for key: String in BUS_BY_KEY:
		apply_volume(key)


## Applies the one option that changed.
func apply(key: String) -> void:
	match key:
		UserSettings.WINDOW_MODE, UserSettings.WINDOW_WIDTH, UserSettings.WINDOW_HEIGHT:
			apply_window()
		UserSettings.VSYNC, UserSettings.FPS_LIMIT:
			apply_pacing()
		UserSettings.QUALITY, UserSettings.RENDER_SCALE:
			apply_quality()
		UserSettings.UI_SCALE:
			apply_ui_scale()
		UserSettings.LOCALE:
			apply_locale()
		_:
			if BUS_BY_KEY.has(key):
				apply_volume(key)


func apply_window() -> void:
	if _headless:
		return
	match _settings.get_int(UserSettings.WINDOW_MODE):
		UserSettings.WindowMode.FULLSCREEN:
			_window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		UserSettings.WindowMode.BORDERLESS:
			_window.mode = Window.MODE_FULLSCREEN
		_:
			_window.mode = Window.MODE_WINDOWED
			var screen := DisplayServer.screen_get_usable_rect(_window.current_screen)
			var wanted := Vector2i(
				_settings.get_int(UserSettings.WINDOW_WIDTH),
				_settings.get_int(UserSettings.WINDOW_HEIGHT)
			)
			_window.size = wanted.min(screen.size)
			_window.position = screen.position + (screen.size - _window.size) / 2


func apply_pacing() -> void:
	Engine.max_fps = _settings.get_int(UserSettings.FPS_LIMIT)
	if _headless:
		return
	var vsync := _settings.get_bool(UserSettings.VSYNC)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)


## Anti-aliasing, shadow resolution and the 3D render scale; scenes read the quality level for
## their own extras (ink post effect, grass density) through App.quality().
func apply_quality() -> void:
	if _headless:
		return
	var quality := _settings.get_int(UserSettings.QUALITY)
	_window.msaa_3d = MSAA_BY_QUALITY[quality]
	_window.scaling_3d_scale = _settings.get_float(UserSettings.RENDER_SCALE)
	RenderingServer.directional_shadow_atlas_set_size(SHADOW_ATLAS_BY_QUALITY[quality], true)
	var filter := RenderingServer.SHADOW_QUALITY_SOFT_LOW
	if quality == UserSettings.Quality.HIGH:
		filter = RenderingServer.SHADOW_QUALITY_SOFT_HIGH
	RenderingServer.directional_soft_shadow_filter_set_quality(filter)


func apply_ui_scale() -> void:
	_window.content_scale_factor = _settings.get_float(UserSettings.UI_SCALE)


func apply_locale() -> void:
	TranslationServer.set_locale(locale())


## The language in use: the chosen one, else the system's when the game has it, else English.
func locale() -> String:
	var chosen := _settings.get_string(UserSettings.LOCALE)
	if chosen != UserSettings.LOCALE_SYSTEM:
		return chosen
	var system := OS.get_locale_language()
	return system if system in UserSettings.LOCALES else FALLBACK_LOCALE


func apply_volume(key: String) -> void:
	var bus := AudioServer.get_bus_index(BUS_BY_KEY[key])
	if bus < 0:
		return
	var level := _settings.get_float(key)
	AudioServer.set_bus_mute(bus, level <= 0.0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(level, 0.0001)))
