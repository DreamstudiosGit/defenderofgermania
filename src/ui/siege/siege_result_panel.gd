class_name SiegeResultPanel
extends Control
## End of the bombardment: breach or not, what follows, the damage to wall and garrison and the
## shots; "again" and "quit" in practice, "continue" in a campaign.

signal retry_requested
signal quit_requested
signal continue_requested

var _column := VBoxContainer.new()
var _retry := Button.new()
var _quit := Button.new()
var _continue := Button.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
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
	for entry: Array in [[_retry, "SIEGE_RETRY", retry_requested], [_quit, "SIEGE_QUIT",
			quit_requested], [_continue, "SIEGE_CONTINUE", continue_requested]]:
		var button: Button = entry[0]
		button.text = tr(str(entry[1]))
		var done: Signal = entry[2]
		button.pressed.connect(func() -> void: done.emit())
		buttons.add_child(button)


func show_result(result: TrebuchetResult, part_name: String, practice: bool) -> void:
	for child: Node in _column.get_children():
		child.queue_free()
	var title := tr("SIEGE_RESULT_HOLDS")
	if result.breach:
		title = tr("SIEGE_RESULT_BREACH") % part_name
	_label(title, 38).modulate = GroupShield.GOLD if result.breach else Color(0.9, 0.85, 0.75)
	_label(tr("SIEGE_RESULT_STORM" if result.breach else "SIEGE_RESULT_NEXT_ROUND"), 18)
	_label(tr("SIEGE_RESULT_WALL") % roundi(result.wall_damage * 100.0), 18)
	_label(tr("SIEGE_RESULT_GARRISON") % roundi(result.garrison_damage * 100.0), 18)
	_label(tr("SIEGE_RESULT_SHOTS") % [result.shots_fired, result.hits], 18)
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
