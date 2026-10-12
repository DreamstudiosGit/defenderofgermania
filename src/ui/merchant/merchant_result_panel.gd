class_name MerchantResultPanel
extends Control
## End of the raid: how it went, wagons stopped, loot and time, a dry remark — then again or
## quit in practice, continue in the campaign.

signal retry_requested
signal quit_requested
signal continue_requested

const RICH_SHARE := 0.8

var _column := VBoxContainer.new()
var _retry := Button.new()
var _quit := Button.new()
var _continue := Button.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", BattleResultPanel.panel_style())
	center.add_child(panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 16)
	panel.add_child(outer)
	_column.add_theme_constant_override("separation", 8)
	outer.add_child(_column)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	outer.add_child(buttons)
	for entry: Array in [
		[_retry, "MERCHANT_RESULT_RETRY", retry_requested],
		[_quit, "MERCHANT_RESULT_QUIT", quit_requested],
		[_continue, "MERCHANT_RESULT_CONTINUE", continue_requested],
	]:
		var button: Button = entry[0]
		var pressed: Signal = entry[2]
		button.text = tr(str(entry[1]))
		button.custom_minimum_size = Vector2(160, 44)
		button.pressed.connect(func() -> void: pressed.emit())
		buttons.add_child(button)


func show_result(result: MerchantResult, practice: bool, house_color: Color) -> void:
	for child: Node in _column.get_children():
		child.queue_free()
	var title_key := "MERCHANT_RESULT_NONE"
	var note_key := "MERCHANT_RESULT_NOTE_NONE"
	if result.leader_captured:
		title_key = "MERCHANT_RESULT_CAPTURED"
		note_key = "MERCHANT_RESULT_NOTE_CAPTURED"
	elif result.wagons_stopped >= ceili(result.wagons_total * RICH_SHARE):
		title_key = "MERCHANT_RESULT_RICH"
		note_key = "MERCHANT_RESULT_NOTE_RICH"
	elif result.wagons_stopped > 0:
		title_key = "MERCHANT_RESULT_SOME"
		note_key = "MERCHANT_RESULT_NOTE_SOME"
	var title := _label(tr(title_key), 38)
	title.modulate = house_color.lightened(0.35)
	_label(tr("MERCHANT_RESULT_WAGONS") % [result.wagons_stopped, result.wagons_total], 20)
	_label(tr("MERCHANT_RESULT_LOOT") % result.taler, 20)
	var seconds := roundi(result.seconds)
	_label(tr("MERCHANT_RESULT_TIME") % ("%d:%02d" % [floori(seconds / 60.0), seconds % 60]), 18)
	_label(tr(note_key), 16)
	_retry.visible = practice
	_quit.visible = practice
	_continue.visible = not practice
	visible = true
	(_retry if practice else _continue).grab_focus()


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	_column.add_child(label)
	return label
