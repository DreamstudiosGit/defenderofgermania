class_name MerchantPracticePanel
extends Control
## Practice start screen: what the raid is about, the controls, how watchful the escort is and
## how many companies lie in ambush; then ride out or quit.

signal start_requested(escort_skill: int, companies: int)
signal quit_requested

const TEXT_WIDTH := 620.0

var _escorts := OptionButton.new()
var _companies := OptionButton.new()
var _start := Button.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", BattleResultPanel.panel_style())
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	_text(column, tr("MERCHANT_TITLE"), 36, HORIZONTAL_ALIGNMENT_CENTER)
	_text(column, tr("MERCHANT_PRACTICE"), 18, HORIZONTAL_ALIGNMENT_CENTER)
	_text(column, tr("MERCHANT_HOWTO"), 17, HORIZONTAL_ALIGNMENT_LEFT)
	var options := GridContainer.new()
	options.columns = 2
	options.add_theme_constant_override("h_separation", 18)
	column.add_child(options)
	_text(options, tr("MERCHANT_ESCORTS"), 18, HORIZONTAL_ALIGNMENT_LEFT)
	for skill: int in MerchantConfig.SKILLS:
		_escorts.add_item(tr("MERCHANT_ESCORT_%d" % skill), skill)
	options.add_child(_escorts)
	_text(options, tr("MERCHANT_COMPANIES"), 18, HORIZONTAL_ALIGNMENT_LEFT)
	for count: int in 3:
		_companies.add_item(str(count), count)
	options.add_child(_companies)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	column.add_child(buttons)
	_start.text = tr("MERCHANT_START")
	_start.custom_minimum_size = Vector2(160, 44)
	_start.pressed.connect(
		func() -> void: start_requested.emit(_escorts.get_selected_id(), _companies.get_selected_id())
	)
	buttons.add_child(_start)
	var quit := Button.new()
	quit.text = tr("MERCHANT_RESULT_QUIT")
	quit.custom_minimum_size = Vector2(160, 44)
	quit.pressed.connect(func() -> void: quit_requested.emit())
	buttons.add_child(quit)
	for key: String in ["MERCHANT_KEYS_KEYBOARD", "MERCHANT_KEYS_PAD"]:
		_text(column, tr(key), 14, HORIZONTAL_ALIGNMENT_LEFT)


func open(escort_skill: int, companies: int) -> void:
	_escorts.select(_escorts.get_item_index(escort_skill))
	_companies.select(_companies.get_item_index(companies))
	visible = true
	_start.grab_focus()


func _text(parent: Control, text: String, font_size: int, align: HorizontalAlignment) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	if align == HORIZONTAL_ALIGNMENT_LEFT and parent is VBoxContainer:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = TEXT_WIDTH
	parent.add_child(label)
