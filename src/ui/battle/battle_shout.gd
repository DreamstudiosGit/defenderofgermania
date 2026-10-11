class_name BattleShout
extends Control
## Big shouts in the middle of the screen ("Zum Angriff!", battle cries), shown one after the
## other with a pop-in and fade-out; repeats of the current shout are dropped.

const SHOW_SECONDS := 1.4
const POP_SECONDS := 0.15
const MAX_QUEUE := 2

var _title := Label.new()
var _subtitle := Label.new()
var _queue: Array[PackedStringArray] = []
var _queue_colors: Array[Color] = []
var _left: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for label: Label in [_title, _subtitle]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
	_title.label_settings = _settings(76, 16)
	_subtitle.label_settings = _settings(34, 10)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle.offset_top = 140
	_subtitle.offset_bottom = 140
	modulate.a = 0.0


func shout(text: String, subtitle: String, color: Color) -> void:
	if _left > 0.0 and _title.text == text:
		return
	for entry: PackedStringArray in _queue:
		if entry[0] == text:
			return
	if _queue.size() >= MAX_QUEUE:
		return
	_queue.append(PackedStringArray([text, subtitle]))
	_queue_colors.append(color)


func clear() -> void:
	_queue.clear()
	_queue_colors.clear()
	_left = 0.0
	modulate.a = 0.0


func _process(delta: float) -> void:
	if _left <= 0.0 and not _queue.is_empty():
		var entry: PackedStringArray = _queue.pop_front()
		var color: Color = _queue_colors.pop_front()
		_title.text = entry[0]
		_subtitle.text = entry[1]
		_title.label_settings.outline_color = color.darkened(0.4)
		_subtitle.label_settings.outline_color = color.darkened(0.4)
		_left = SHOW_SECONDS
	if _left <= 0.0:
		return
	_left -= delta
	var shown := SHOW_SECONDS - _left
	modulate.a = clampf(_left / 0.35, 0.0, 1.0)
	var pop := 1.0 + 0.3 * clampf(1.0 - shown / POP_SECONDS, 0.0, 1.0)
	pivot_offset = size * 0.5
	scale = Vector2.ONE * pop


func _settings(font_size: int, outline: int) -> LabelSettings:
	var settings := LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = Color(1.0, 0.97, 0.9)
	settings.outline_size = outline
	settings.shadow_size = 6
	settings.shadow_color = Color(0, 0, 0, 0.45)
	settings.shadow_offset = Vector2(3, 4)
	return settings
