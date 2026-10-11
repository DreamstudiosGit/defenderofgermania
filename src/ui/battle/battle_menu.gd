class_name BattleMenu
extends Control
## Start screen of the battle prototype: choose who commands each side (computer, keyboard and
## mouse, controller 1 or 2), then start. Emits devices per side, -1 for the computer.

signal start_requested(devices: PackedInt32Array)

## Option ids are device + 1, so the computer (-1) gets id 0.
const CHOICES: Array[String] = [
	"BATTLE_CONTROL_AI", "BATTLE_CONTROL_KEYBOARD", "BATTLE_CONTROL_PAD", "BATTLE_CONTROL_PAD"
]

const HINT_WIDTH := 560.0

var _options: Array[OptionButton] = []
var _houses: Array[Label] = []
var _warning := Label.new()
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
	var title := Label.new()
	title.text = tr("BATTLE_MENU_TITLE")
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", 40)
	column.add_child(sides)
	for s: int in BattleState.SIDES:
		var side_column := VBoxContainer.new()
		sides.add_child(side_column)
		var house := Label.new()
		house.add_theme_font_size_override("font_size", 22)
		side_column.add_child(house)
		_houses.append(house)
		var option := OptionButton.new()
		for id: int in CHOICES.size():
			var text := tr(CHOICES[id])
			if id >= 2:
				text = text % (id - 1)
			option.add_item(text, id)
		option.item_selected.connect(_on_choice_changed)
		side_column.add_child(option)
		_options.append(option)
	_warning.text = tr("BATTLE_MENU_CONFLICT")
	_warning.modulate = Color(1.0, 0.5, 0.4)
	column.add_child(_warning)
	_start.text = tr("BATTLE_MENU_START")
	_start.pressed.connect(_on_start_pressed)
	column.add_child(_start)
	for key: String in ["BATTLE_HINT_KEYBOARD", "BATTLE_HINT_PAD"]:
		var hint := Label.new()
		hint.text = tr(key)
		hint.add_theme_font_size_override("font_size", 14)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size.x = HINT_WIDTH
		column.add_child(hint)


func open(armies: Array[BattleRules.ArmyPreset], devices: PackedInt32Array) -> void:
	for s: int in BattleState.SIDES:
		var role := tr("BATTLE_ROLE_ATTACKER" if s == 0 else "BATTLE_ROLE_DEFENDER")
		_houses[s].text = "%s (%s)" % [tr("BATTLE_HOUSE_" + armies[s].house.to_upper()), role]
		_houses[s].modulate = armies[s].color.lightened(0.35)
		_options[s].select(_options[s].get_item_index(devices[s] + 1))
	visible = true
	_on_choice_changed(0)
	_start.grab_focus()


func devices() -> PackedInt32Array:
	var result := PackedInt32Array()
	for option: OptionButton in _options:
		result.append(option.get_selected_id() - 1)
	return result


func _on_choice_changed(_index: int) -> void:
	var chosen := devices()
	var conflict := chosen[0] >= 0 and chosen[0] == chosen[1]
	_warning.visible = conflict
	_start.disabled = conflict


func _on_start_pressed() -> void:
	visible = false
	start_requested.emit(devices())
