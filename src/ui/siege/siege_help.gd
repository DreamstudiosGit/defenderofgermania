class_name SiegeHelp
extends Control
## How the trebuchet works, in four lines, with the controls; in practice it is also the pause
## menu with "again" and "quit".

signal closed
signal retry_requested
signal quit_requested

const WIDTH := 640.0
const LINES: Array[String] = ["SIEGE_HELP_1", "SIEGE_HELP_2", "SIEGE_HELP_3", "SIEGE_HELP_4"]

var _continue := Button.new()
var _retry := Button.new()
var _quit := Button.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", BattleResultPanel.panel_style())
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var title := Label.new()
	title.text = tr("SIEGE_HELP_TITLE")
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = GroupShield.GOLD
	column.add_child(title)
	for key: String in LINES:
		column.add_child(_text(tr(key), 17))
	for key: String in ["SIEGE_HINT_KEYBOARD", "SIEGE_HINT_PAD"]:
		var hint := _text(tr(key), 14)
		hint.modulate = Color(0.85, 0.8, 0.7)
		column.add_child(hint)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	column.add_child(buttons)
	for entry: Array in [[_continue, "SIEGE_CONTINUE", closed], [_retry, "SIEGE_RETRY",
			retry_requested], [_quit, "SIEGE_QUIT", quit_requested]]:
		var button: Button = entry[0]
		button.text = tr(str(entry[1]))
		var done: Signal = entry[2]
		button.pressed.connect(func() -> void: done.emit())
		buttons.add_child(button)


func open(practice: bool) -> void:
	_retry.visible = practice
	_quit.visible = practice
	visible = true
	_continue.grab_focus()


func _text(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = WIDTH
	return label
