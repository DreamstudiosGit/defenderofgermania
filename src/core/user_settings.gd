class_name UserSettings
extends RefCounted
## The player's options (video, audio, game, accessibility), kept in a ConfigFile apart from
## the saved campaigns. Every key has a default and a valid range; values out of range or of
## the wrong type fall back, so a hand-edited or outdated file never breaks the start.
## Presentation applies them (SettingsApplier); nothing here touches the window or the mixer.

signal changed(key: String)

enum WindowMode { WINDOWED, BORDERLESS, FULLSCREEN }
enum Quality { LOW, MEDIUM, HIGH }

const WINDOW_MODE := "video/window_mode"
const WINDOW_WIDTH := "video/window_width"
const WINDOW_HEIGHT := "video/window_height"
const VSYNC := "video/vsync"
const FPS_LIMIT := "video/fps_limit"
const QUALITY := "video/quality"
const RENDER_SCALE := "video/render_scale"
const UI_SCALE := "video/ui_scale"
const VOLUME_MASTER := "audio/master"
const VOLUME_MUSIC := "audio/music"
const VOLUME_SFX := "audio/sfx"
const VOLUME_UI := "audio/ui"
const MUTE_UNFOCUSED := "audio/mute_unfocused"
const LOCALE := "game/locale"
const RUMBLE := "game/rumble"
const SCREEN_SHAKE := "game/screen_shake"
const SLOW_MOTION := "game/slow_motion"
const ADVISORS := "game/advisors"

## Locale value for "follow the system language".
const LOCALE_SYSTEM := ""
const LOCALES: Array[String] = ["de", "en"]
const FPS_LIMITS: Array[int] = [0, 30, 60, 90, 120, 144, 240]

## key -> [default, minimum, maximum]; booleans and strings carry only the default.
const SPEC: Dictionary[String, Array] = {
	WINDOW_MODE: [WindowMode.BORDERLESS, 0, 2],
	WINDOW_WIDTH: [1600, 960, 7680],
	WINDOW_HEIGHT: [900, 540, 4320],
	VSYNC: [true],
	FPS_LIMIT: [0, 0, 240],
	QUALITY: [Quality.HIGH, 0, 2],
	RENDER_SCALE: [1.0, 0.5, 1.0],
	UI_SCALE: [1.0, 0.75, 1.15],
	VOLUME_MASTER: [0.8, 0.0, 1.0],
	VOLUME_MUSIC: [0.6, 0.0, 1.0],
	VOLUME_SFX: [0.8, 0.0, 1.0],
	VOLUME_UI: [0.7, 0.0, 1.0],
	MUTE_UNFOCUSED: [true],
	LOCALE: [LOCALE_SYSTEM],
	RUMBLE: [true],
	SCREEN_SHAKE: [1.0, 0.0, 1.0],
	SLOW_MOTION: [true],
	ADVISORS: [true],
}

## Where the options live; tests point it elsewhere.
var path := "user://settings.cfg"

var _values: Dictionary[String, Variant] = {}


func _init() -> void:
	for key: String in SPEC:
		_values[key] = SPEC[key][0]


func keys() -> Array[String]:
	var result: Array[String] = []
	result.assign(SPEC.keys())
	return result


func default_of(key: String) -> Variant:
	return SPEC[key][0]


func value_of(key: String) -> Variant:
	return _values[key]


func get_bool(key: String) -> bool:
	return _values[key]


func get_int(key: String) -> int:
	return _values[key]


func get_float(key: String) -> float:
	return _values[key]


func get_string(key: String) -> String:
	return _values[key]


## Stores the value, clamped to the key's range; a value of the wrong type is ignored. Emits
## changed only when the stored value differs.
func set_value(key: String, value: Variant) -> void:
	if not SPEC.has(key):
		push_warning("settings: unknown key %s" % key)
		return
	var valid: Variant = _validated(key, value)
	if valid == null or _values[key] == valid:
		return
	_values[key] = valid
	changed.emit(key)


## Back to the defaults: every key, or only those of one section ("video", "audio", "game").
func reset(section: String = "") -> void:
	for key: String in SPEC:
		if section.is_empty() or key.begins_with(section + "/"):
			set_value(key, SPEC[key][0])


## Reads the file; missing or invalid entries keep their defaults. A missing file is fine.
func load_file() -> void:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	for key: String in SPEC:
		var parts := key.split("/")
		if file.has_section_key(parts[0], parts[1]):
			set_value(key, file.get_value(parts[0], parts[1]))


func save_file() -> Error:
	var file := ConfigFile.new()
	for key: String in SPEC:
		var parts := key.split("/")
		file.set_value(parts[0], parts[1], _values[key])
	var folder := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(folder):
		var made := DirAccess.make_dir_recursive_absolute(folder)
		if made != OK:
			return made
	return file.save(path)


## The value in the key's type and range, or null when it cannot be used.
func _validated(key: String, value: Variant) -> Variant:
	var spec: Array = SPEC[key]
	var is_number := value is int or value is float
	match typeof(spec[0]):
		TYPE_BOOL:
			return value if value is bool else null
		TYPE_INT:
			return _whole(key, value, spec) if is_number else null
		TYPE_FLOAT:
			var number: float = value if is_number else NAN
			return clampf(number, spec[1], spec[2]) if is_finite(number) else null
		TYPE_STRING:
			return _text(key, value)
	return null


func _whole(key: String, value: float, spec: Array) -> Variant:
	var whole := roundi(value)
	if key == FPS_LIMIT and whole not in FPS_LIMITS:
		return null
	return clampi(whole, spec[1], spec[2])


func _text(key: String, value: Variant) -> Variant:
	if not value is String:
		return null
	var text: String = value
	if key == LOCALE and text != LOCALE_SYSTEM and text not in LOCALES:
		return null
	return text
