class_name JoustResultPanel
extends Control
## End of a joust: victory or defeat, why, points and stance of both riders, passes ridden; in
## practice the buttons to ride again, change the setup or quit, in a campaign "continue".

signal retry_requested
signal setup_requested
signal quit_requested
signal continue_requested

const REASONS: Dictionary[int, String] = {
	JoustResult.Decision.POINTS: "JOUST_REASON_POINTS",
	JoustResult.Decision.STANCE: "JOUST_REASON_STANCE",
	JoustResult.Decision.STATUS_QUO: "JOUST_REASON_STATUS_QUO",
}

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
	for entry: Array in [
		[_retry, "JOUST_RETRY", retry_requested], [_setup, "JOUST_SETUP", setup_requested],
		[_quit, "JOUST_MENU_QUIT", quit_requested],
		[_continue, "BATTLE_RESULT_CONTINUE", continue_requested],
	]:
		var button: Button = entry[0]
		var pressed: Signal = entry[2]
		button.text = tr(entry[1])
		button.pressed.connect(func() -> void: pressed.emit())
		buttons.add_child(button)
	set_practice(true)


## Practice offers again / setup / quit; a campaign joust only "continue".
func set_practice(practice: bool) -> void:
	_retry.visible = practice
	_setup.visible = practice
	_quit.visible = practice
	_continue.visible = not practice


func show_result(
	result: JoustResult, names: Array[String], colors: Array[PackedColorArray]
) -> void:
	for child: Node in _column.get_children():
		child.queue_free()
	var title := _label(tr("JOUST_RESULT_WIN" if result.won else "JOUST_RESULT_LOSS"), 40)
	title.modulate = colors[0 if result.won else 1][0].lightened(0.4)
	var reason := ""
	if result.decided_by == JoustResult.Decision.UNSEATED:
		var fallen := result.unseated == JoustResult.OPPONENT
		reason = tr("JOUST_REASON_UNSEATED_OPPONENT" if fallen else "JOUST_REASON_UNSEATED_PLAYER")
	else:
		reason = tr(REASONS[result.decided_by])
	_label(reason, 20)
	_label("%s – %s" % [names[0], names[1]], 18)
	_label(tr("JOUST_RESULT_SCORE") % [result.player_points, result.opponent_points], 24)
	var stances := [roundi(result.player_stance), roundi(result.opponent_stance)]
	_label(tr("JOUST_RESULT_STANCE") % stances, 18)
	_label(tr("JOUST_RESULT_PASSES") % result.passes, 16)
	visible = true
	(_continue if _continue.visible else _retry).grab_focus()


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	_column.add_child(label)
	return label
