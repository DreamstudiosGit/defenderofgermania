class_name OptionsTab
extends VBoxContainer
## One page of the options screen: rows that show and write the options of a UserSettings.
## The pages (OptionsVideo, OptionsAudio, OptionsGame) add their rows in _build(). A row's
## texts are the key it is given and that key with _HINT; its control is named after the
## option ("video/vsync" -> "video_vsync").

var settings: UserSettings

## Option key -> its row.
var _rows: Dictionary[String, OptionRow] = {}


func _init(edited: UserSettings) -> void:
	settings = edited
	add_theme_constant_override("separation", 2)
	_build()
	refresh()


## Shows the current values.
func refresh() -> void:
	for key: String in _rows:
		_rows[key].show_value(settings.value_of(key))


## Puts every option of the page back to its default.
func reset() -> void:
	for key: String in _reset_keys():
		settings.set_value(key, settings.default_of(key))
	refresh()


## The rows' controls from top to bottom, also those that are locked right now.
func controls() -> Array[Control]:
	var result: Array[Control] = []
	for child: Node in get_children():
		var row := child as OptionRow
		if row != null:
			result.append(row.control)
	return result


func _build() -> void:
	pass


## The options reset() restores: those of the rows unless a page knows better.
func _reset_keys() -> Array[String]:
	var keys: Array[String] = []
	keys.assign(_rows.keys())
	return keys


func _add_toggle(key: String, text_key: String) -> OptionRow:
	return _bind(key, OptionRow.toggle(tr(text_key), tr(text_key + "_HINT")))


## A slider over the option's whole range (UserSettings.SPEC), shown in percent.
func _add_percent(key: String, text_key: String) -> OptionRow:
	var spec: Array = UserSettings.SPEC[key]
	var low: float = spec[1]
	var high: float = spec[2]
	var steps := OptionRow.PERCENT_STEPS
	var row := OptionRow.percent(
		tr(text_key), tr(text_key + "_HINT"), roundi(low * steps), roundi(high * steps)
	)
	return _bind(key, row)


func _add_choice(key: String, text_key: String, names: Array[String], values: Array) -> OptionRow:
	return _bind(key, OptionRow.choice(tr(text_key), tr(text_key + "_HINT"), names, values))


func _texts(text_keys: Array[String]) -> Array[String]:
	var texts: Array[String] = []
	for text_key: String in text_keys:
		texts.append(tr(text_key))
	return texts


func _bind(key: String, row: OptionRow) -> OptionRow:
	row.control.name = key.replace("/", "_")
	row.changed.connect(func(value: Variant) -> void: settings.set_value(key, value))
	_rows[key] = row
	add_child(row)
	return row
