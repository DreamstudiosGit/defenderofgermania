class_name RaidResultPanel
extends Control
## End of a raid: how it went, what it brings, time, guards and alarm. Practice offers again,
## back to the setup and quit; a campaign raid only continues.

signal retry_requested
signal setup_requested
signal quit_requested
signal continue_requested

var _column := VBoxContainer.new()
var _retry := Button.new()
var _setup := Button.new()
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
	var entries: Array = [
		[_retry, "RAID_RESULT_RETRY", retry_requested],
		[_setup, "RAID_RESULT_SETUP", setup_requested],
		[_quit, "RAID_RESULT_QUIT", quit_requested],
		[_continue, "BATTLE_RESULT_CONTINUE", continue_requested]
	]
	for entry: Array in entries:
		var button: Button = entry[0]
		var requested: Signal = entry[2]
		button.text = tr(str(entry[1]))
		button.pressed.connect(func() -> void: requested.emit())
		buttons.add_child(button)
	set_campaign(false)


func set_campaign(campaign: bool) -> void:
	_retry.visible = not campaign
	_setup.visible = not campaign
	_quit.visible = not campaign
	_continue.visible = campaign


func show_result(result: RaidResult, cfg: RaidConfig) -> void:
	for child: Node in _column.get_children():
		child.queue_free()
	var outcome := ""
	var detail := ""
	var color := Color(1.0, 0.82, 0.3)
	match result.outcome:
		RaidResult.Outcome.SUCCESS:
			outcome = tr("RAID_RESULT_SUCCESS")
			detail = tr("RAID_RESULT_DONE_" + result.target.to_upper())
		RaidResult.Outcome.CAPTURED:
			outcome = tr("RAID_RESULT_CAPTURED")
			detail = tr("RAID_RESULT_CAPTURED_TEXT")
			color = Color(0.9, 0.35, 0.3)
		_:
			outcome = tr("RAID_RESULT_ESCAPED")
			detail = tr("RAID_RESULT_ESCAPED_TEXT")
			color = Color(0.85, 0.75, 0.6)
	_label(outcome, 40).modulate = color
	_label(detail, 18)
	if result.success:
		_label(tr("RAID_RESULT_PRESTIGE") % roundi(cfg.prestige(result.target)), 20)
	var seconds := roundi(result.time_used)
	_label(tr("RAID_RESULT_TIME") % ("%d:%02d" % [floori(seconds / 60.0), seconds % 60]), 18)
	_label(tr("RAID_RESULT_GUARDS") % [result.guards_defeated, result.guards_avoided], 18)
	_label(tr("RAID_RESULT_ALARM" if result.alarm_raised else "RAID_RESULT_QUIET"), 18)
	if result.practice:
		_label(tr("RAID_PRACTICE_NOTE"), 14)
	visible = true
	(_continue if _continue.visible else _retry).grab_focus()


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	_column.add_child(label)
	return label
