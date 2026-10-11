class_name BattleResultPanel
extends Control
## End-of-battle banner: winner, why, duration, losses per company, captured leaders, and the
## buttons to play again or go back to the setup.

signal play_again_requested
signal setup_requested

var _column := VBoxContainer.new()
var _again := Button.new()
var _setup := Button.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style())
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
	_again.text = tr("BATTLE_RESULT_PLAY_AGAIN")
	_again.pressed.connect(func() -> void: play_again_requested.emit())
	buttons.add_child(_again)
	_setup.text = tr("BATTLE_RESULT_SETUP")
	_setup.pressed.connect(func() -> void: setup_requested.emit())
	buttons.add_child(_setup)


func show_result(sim: BattleSim, armies: Array[BattleRules.ArmyPreset]) -> void:
	for child: Node in _column.get_children():
		child.queue_free()
	var result := sim.result()
	var winner := 0 if result.attacker_won else 1
	var title := _label(tr("BATTLE_RESULT_VICTORY") % _house(armies, winner), 38)
	title.modulate = armies[winner].accent
	var reason := "BATTLE_RESULT_TIMEOUT" if sim.state.timed_out else "BATTLE_RESULT_ROUT"
	_label(tr(reason), 18)
	var seconds := roundi(result.duration)
	_label(tr("BATTLE_RESULT_DURATION") % ("%d:%02d" % [floori(seconds / 60.0), seconds % 60]), 18)
	var sides := HBoxContainer.new()
	sides.add_theme_constant_override("separation", 48)
	_column.add_child(sides)
	for s: int in BattleState.SIDES:
		sides.add_child(_losses(sim, armies, s))
	var captured := PackedStringArray()
	if result.attacker_leader_captured:
		captured.append(tr("BATTLE_RESULT_CAPTURED") % _house(armies, 0))
	if result.defender_leader_captured:
		captured.append(tr("BATTLE_RESULT_CAPTURED") % _house(armies, 1))
	if captured.is_empty():
		captured.append(tr("BATTLE_RESULT_NO_CAPTIVES"))
	_label("\n".join(captured), 18)
	visible = true
	_again.grab_focus()


func _losses(sim: BattleSim, armies: Array[BattleRules.ArmyPreset], s: int) -> VBoxContainer:
	var column := VBoxContainer.new()
	var header := Label.new()
	header.text = "%s – %s" % [_house(armies, s), tr("BATTLE_RESULT_LOSSES")]
	header.add_theme_font_size_override("font_size", 20)
	column.add_child(header)
	var state := sim.state
	var side := sim.setup.attacker if s == 0 else sim.setup.defender
	for c: int in state.company_count():
		if state.side[c] != s or state.is_leader(c):
			continue
		var start := side.health[state.setup_index[c]]
		var lost := roundi((start - state.hp[c] / state.max_hp[c]) * 100.0)
		var line := Label.new()
		line.text = "%s: −%d %%" % [tr("BATTLE_UNIT_" + state.unit_ids[c].to_upper()), lost]
		match state.status[c]:
			BattleState.Status.DESTROYED:
				line.text += " (%s)" % tr("BATTLE_STATUS_DESTROYED")
			BattleState.Status.FLED, BattleState.Status.FLEEING:
				line.text += " (%s)" % tr("BATTLE_STATUS_FLED")
		column.add_child(line)
	return column


## Opaque parchment-brown panel with a gold rim, shared by the battle menus.
static func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.12, 0.08, 0.96)
	style.border_color = GroupShield.GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(24)
	return style


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	_column.add_child(label)
	return label


func _house(armies: Array[BattleRules.ArmyPreset], s: int) -> String:
	return tr("BATTLE_HOUSE_" + armies[s].house.to_upper())
