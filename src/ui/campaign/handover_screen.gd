class_name HandoverScreen
extends Control
## Hot-seat handover: an opaque full-screen cover naming the house whose turn it is, so the
## previous player's screen stays hidden until the next player confirms. Below, the other houses
## with who plays them (human, or computer and difficulty).

signal confirmed

var _badge := HouseBadge.new(Vector2(96, 114))
var _title := CampaignStyle.heading("", 36)
var _date := CampaignStyle.label("", 18, CampaignStyle.MUTED)
var _others := HBoxContainer.new()
var _ready_button := CampaignStyle.modal_button("")


func _init() -> void:
	var column := CampaignStyle.modal(self, Color(0.07, 0.05, 0.04))
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_badge)
	for label: Label in [_title, _date]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
	_others.alignment = BoxContainer.ALIGNMENT_CENTER
	_others.add_theme_constant_override("separation", 22)
	column.add_child(_others)
	var hint := CampaignStyle.paragraph(tr("CAMPAIGN_HANDOVER_HINT"), CampaignStyle.FONT_SIZE)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.custom_minimum_size.x = 460
	column.add_child(hint)
	_ready_button.text = tr("CAMPAIGN_HANDOVER_READY")
	_ready_button.pressed.connect(_on_ready_pressed)
	column.add_child(_ready_button)
	visible = false


## Covers the screen for the house and focuses the confirm button (ui_accept).
func open(state: GameState, rules: GameRules, house: String) -> void:
	_badge.colors = rules.map.house_colors[house]
	_title.text = tr("CAMPAIGN_HANDOVER_TITLE") % CampaignFormat.house_name(house)
	_title.add_theme_color_override("font_color", CampaignFormat.owner_color(rules.map, house))
	_date.text = "%s · %s" % [
		CampaignFormat.date(state, rules), CampaignFormat.phase_name(state.phase)
	]
	_show_others(state, rules, house)
	visible = true
	_ready_button.grab_focus()


func _show_others(state: GameState, rules: GameRules, house: String) -> void:
	for child: Node in _others.get_children():
		_others.remove_child(child)
		child.queue_free()
	for id: String in state.turn_order:
		var other := state.houses[id]
		if id == house or other.is_eliminated:
			continue
		var entry := HBoxContainer.new()
		entry.name = "house_" + id
		entry.add_theme_constant_override("separation", 6)
		var badge := HouseBadge.new(Vector2(20, 24))
		badge.colors = rules.map.house_colors[id]
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		entry.add_child(badge)
		var text := "%s\n%s" % [CampaignFormat.house_name(id), AiFormat.player(other)]
		entry.add_child(CampaignStyle.label(text, CampaignStyle.SMALL_SIZE, CampaignStyle.MUTED))
		_others.add_child(entry)


func _on_ready_pressed() -> void:
	visible = false
	confirmed.emit()
