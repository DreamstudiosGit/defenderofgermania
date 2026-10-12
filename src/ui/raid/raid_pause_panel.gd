class_name RaidPausePanel
extends Control
## Pause during a raid: go on, flee with a wound, or (practice only) leave the practice.

signal resume_requested
signal flee_requested
signal quit_requested

var _resume := Button.new()
var _quit := Button.new()


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
	var flee := Button.new()
	var entries: Array = [
		[_resume, "RAID_MENU_RESUME", resume_requested], [flee, "RAID_MENU_FLEE", flee_requested],
		[_quit, "RAID_MENU_QUIT", quit_requested]
	]
	for entry: Array in entries:
		var button: Button = entry[0]
		var requested: Signal = entry[2]
		button.text = tr(str(entry[1]))
		button.pressed.connect(func() -> void: requested.emit())
		column.add_child(button)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resume_requested.emit()


func open(practice: bool) -> void:
	_quit.visible = practice
	visible = true
	_resume.grab_focus()
