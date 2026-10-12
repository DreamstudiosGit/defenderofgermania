class_name VictoryScreen
extends Control
## End of the game: the winning house, why it won (subjugation or the time limit, "the Pope
## decides") and every house's legitimacy. A coronation shows its illuminated page
## (CoronationPlate) in place of the house's title. Emits new_game_requested.

signal new_game_requested

var _plate := CoronationPlate.new()
var _badge := HouseBadge.new(Vector2(96, 114))
var _title := CampaignStyle.heading("", 40)
var _reason := CampaignStyle.label("", 18, CampaignStyle.MUTED)
var _table := GridContainer.new()
var _again := CampaignStyle.modal_button("")


func _init() -> void:
	var column := CampaignStyle.modal(self, Color(0.07, 0.05, 0.04, 0.92))
	_plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_plate)
	_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_badge)
	for label: Label in [_title, _reason]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(label)
	_table.columns = 4
	_table.add_theme_constant_override("h_separation", 28)
	_table.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_table)
	_again.text = tr("CAMPAIGN_NEW_GAME")
	_again.pressed.connect(func() -> void: new_game_requested.emit())
	column.add_child(_again)
	visible = false


func open(state: GameState, rules: GameRules) -> void:
	var winner := state.winner
	var crowned := not state.crown.crowned_at.is_empty() and rules.map.house_colors.has(winner)
	_plate.visible = crowned
	if crowned:
		_plate.show_coronation(state, rules)
	_title.visible = not crowned
	_reason.visible = not crowned
	_badge.visible = not crowned and rules.map.house_colors.has(winner)
	if _badge.visible:
		_badge.colors = rules.map.house_colors[winner]
	_title.text = tr("CAMPAIGN_VICTORY_NOBODY")
	if not winner.is_empty():
		_title.text = tr("CAMPAIGN_VICTORY") % CampaignFormat.house_name(winner)
		_title.add_theme_color_override("font_color", CampaignFormat.owner_color(rules.map, winner))
	var alive := 0
	for house: HouseState in state.houses.values():
		alive += 0 if house.is_eliminated else 1
	_reason.text = tr("CAMPAIGN_VICTORY_SUBJUGATION" if alive <= 1 else "CAMPAIGN_VICTORY_TIME")
	_fill_table(state, rules)
	visible = true
	_again.grab_focus()


func _fill_table(state: GameState, rules: GameRules) -> void:
	for child: Node in _table.get_children():
		_table.remove_child(child)
		child.queue_free()
	for key: String in [
		"CAMPAIGN_HOUSE", "CAMPAIGN_PROVINCES", "CAMPAIGN_PRESTIGE", "CAMPAIGN_LEGITIMACY"
	]:
		_table.add_child(CampaignStyle.label(tr(key), CampaignStyle.SMALL_SIZE, CampaignStyle.GOLD))
	for house: HouseState in state.houses.values():
		var name := CampaignStyle.label(CampaignFormat.house_name(house.id))
		name.add_theme_color_override("font_color", CampaignFormat.owner_color(rules.map, house.id))
		_table.add_child(name)
		_table.add_child(CampaignStyle.label(str(state.provinces_of(house.id).size())))
		_table.add_child(CampaignStyle.label(CampaignFormat.number(house.prestige, 1)))
		var legitimacy := tr("CAMPAIGN_ELIMINATED")
		if not house.is_eliminated:
			legitimacy = CampaignFormat.number(Victory.legitimacy(state, rules, house.id), 1)
		_table.add_child(CampaignStyle.label(legitimacy))
