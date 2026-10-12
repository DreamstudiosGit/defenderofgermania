class_name JoustMenu
extends Control
## Practice joust setup: a short how-to, then house, lance, opponent skill and controls; start
## or quit. The opponent is the next house in the list.

signal start_requested(setup: JoustSetup, device: int)
signal quit_requested

const HOWTO: Array[String] = [
	"JOUST_HOWTO_RUNUP", "JOUST_HOWTO_AIM", "JOUST_HOWTO_STRIKE", "JOUST_HOWTO_SHIELD",
	"JOUST_HOWTO_WIN",
]
## Option ids are device + 1, so the computer (-1) gets id 0.
const CONTROLS: Array[String] = [
	"BATTLE_CONTROL_AI", "BATTLE_CONTROL_KEYBOARD", "BATTLE_CONTROL_PAD", "BATTLE_CONTROL_PAD"
]
const MAX_LANCE := 5
const TEXT_WIDTH := 620.0

var _houses: Array[String] = []
var _house := OptionButton.new()
var _lance := OptionButton.new()
var _skill := OptionButton.new()
var _control := OptionButton.new()
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
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var title := Label.new()
	title.text = tr("JOUST_PRACTICE_TITLE")
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	for key: String in HOWTO:
		var line := Label.new()
		line.text = "• " + tr(key)
		line.add_theme_font_size_override("font_size", 17)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size.x = TEXT_WIDTH
		column.add_child(line)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	column.add_child(grid)
	_row(grid, "JOUST_MENU_HOUSE", _house)
	_row(grid, "JOUST_MENU_LANCE", _lance)
	_row(grid, "JOUST_MENU_OPPONENT", _skill)
	_row(grid, "JOUST_MENU_CONTROL", _control)
	for lance: int in MAX_LANCE + 1:
		_lance.add_item("%d" % lance, lance)
	for skill: int in JoustConfig.SKILLS:
		_skill.add_item(tr("JOUST_SKILL_%d" % skill), skill)
	for id: int in CONTROLS.size():
		var text := tr(CONTROLS[id])
		_control.add_item(text % (id - 1) if id >= 2 else text, id)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	column.add_child(buttons)
	_start.text = tr("JOUST_MENU_START")
	_start.pressed.connect(_on_start_pressed)
	buttons.add_child(_start)
	var quit := Button.new()
	quit.text = tr("JOUST_MENU_QUIT")
	quit.pressed.connect(func() -> void: quit_requested.emit())
	buttons.add_child(quit)


func open(houses: Array[String], setup: JoustSetup, device: int) -> void:
	_houses = houses
	_house.clear()
	for i: int in houses.size():
		_house.add_item(tr("BATTLE_HOUSE_" + houses[i].to_upper()), i)
	_house.select(maxi(houses.find(setup.house), 0))
	_lance.select(clampi(setup.lance, 0, MAX_LANCE))
	_skill.select(clampi(setup.opponent_skill, 0, JoustConfig.SKILLS - 1))
	_control.select(_control.get_item_index(device + 1))
	visible = true
	_start.grab_focus()


func _row(grid: GridContainer, key: String, option: OptionButton) -> void:
	var label := Label.new()
	label.text = tr(key)
	label.add_theme_font_size_override("font_size", 18)
	grid.add_child(label)
	option.custom_minimum_size.x = 300.0
	grid.add_child(option)


func _on_start_pressed() -> void:
	var setup := JoustSetup.practice_default()
	if not _houses.is_empty():
		var index := maxi(_house.selected, 0)
		setup.house = _houses[index]
		setup.opponent = _houses[(index + 1) % _houses.size()]
	setup.lance = maxi(_lance.selected, 0)
	setup.opponent_skill = maxi(_skill.selected, 0)
	visible = false
	start_requested.emit(setup, _control.get_selected_id() - 1)
