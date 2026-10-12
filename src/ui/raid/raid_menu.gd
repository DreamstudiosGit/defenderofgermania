class_name RaidMenu
extends Control
## Practice start screen of the castle raid: target, guards, castle, blade and who plays the
## leader, a short how-to, then start or quit.

signal start_requested(setup: RaidSetup, device: int)
signal quit_requested

## Option ids are device + 1, so the computer (-1) gets id 0.
const CONTROLS: Array[String] = [
	"BATTLE_CONTROL_AI", "BATTLE_CONTROL_KEYBOARD", "BATTLE_CONTROL_PAD", "BATTLE_CONTROL_PAD"
]
## (home castle, level) per castle choice.
const CASTLES: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3),
	Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 3), Vector2i(1, 4), Vector2i(1, 5)
]
const TEXT_WIDTH := 600.0
const MAX_BLADE := 5

var _target := OptionButton.new()
var _guards := OptionButton.new()
var _castle := OptionButton.new()
var _blade := OptionButton.new()
var _control := OptionButton.new()
var _start := Button.new()
var _howto := Label.new()
var _base := RaidSetup.new()


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
	title.text = tr("RAID_PRACTICE_TITLE")
	title.add_theme_font_size_override("font_size", 38)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	column.add_child(grid)
	for target: String in RaidConfig.TARGETS:
		_target.add_item(tr("RAID_TARGET_" + target.to_upper()))
	for skill: int in RaidConfig.SKILLS:
		_guards.add_item(tr("RAID_SKILL_%d" % skill))
	for castle: Vector2i in CASTLES:
		_castle.add_item(tr("RAID_CASTLE_HOME" if castle.x == 1 else "RAID_CASTLE_PROVINCE") % castle.y)
	for blade: int in range(1, MAX_BLADE + 1):
		_blade.add_item(str(blade), blade)
	for id: int in CONTROLS.size():
		var text := tr(CONTROLS[id])
		_control.add_item(text % (id - 1) if id >= 2 else text, id)
	var rows: Array = [
		["RAID_SETUP_TARGET", _target], ["RAID_SETUP_GUARDS", _guards],
		["RAID_SETUP_CASTLE", _castle], ["RAID_SETUP_BLADE", _blade],
		["RAID_SETUP_CONTROL", _control]
	]
	for row: Array in rows:
		var label := Label.new()
		label.text = tr(str(row[0]))
		grid.add_child(label)
		grid.add_child(row[1] as Control)
	for key: String in ["RAID_HOWTO", "RAID_HINT_KEYBOARD", "RAID_HINT_PAD"]:
		var text := _howto if key == "RAID_HOWTO" else Label.new()
		text.text = tr(key)
		text.add_theme_font_size_override("font_size", 16 if key == "RAID_HOWTO" else 14)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size.x = TEXT_WIDTH
		column.add_child(text)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	column.add_child(buttons)
	_start.text = tr("RAID_SETUP_START")
	_start.pressed.connect(_on_start_pressed)
	buttons.add_child(_start)
	var quit := Button.new()
	quit.text = tr("RAID_SETUP_QUIT")
	quit.pressed.connect(func() -> void: quit_requested.emit())
	buttons.add_child(quit)


func open(setup: RaidSetup, device: int, cfg: RaidConfig) -> void:
	_base = setup.copy()
	_howto.text = tr("RAID_HOWTO") % [
		roundi(cfg.parry_window_base_ms), roundi(cfg.parry_window_per_blade_ms),
		roundi(cfg.alarm_seconds), roundi(cfg.time_limit_seconds)
	]
	_target.select(maxi(RaidConfig.TARGETS.find(setup.target), 0))
	_guards.select(clampi(setup.guard_skill, 0, RaidConfig.SKILLS - 1))
	_castle.select(maxi(CASTLES.find(Vector2i(1 if setup.home_castle else 0, setup.castle_level)), 0))
	_blade.select(_blade.get_item_index(clampi(setup.blade, 1, MAX_BLADE)))
	_control.select(_control.get_item_index(device + 1))
	visible = true
	_start.grab_focus()


func _on_start_pressed() -> void:
	var setup := _base.copy()
	setup.target = RaidConfig.TARGETS[_target.selected]
	setup.guard_skill = _guards.selected
	var castle := CASTLES[_castle.selected]
	setup.home_castle = castle.x == 1
	setup.castle_level = castle.y
	setup.blade = _blade.get_selected_id()
	setup.practice = true
	visible = false
	start_requested.emit(setup, _control.get_selected_id() - 1)
