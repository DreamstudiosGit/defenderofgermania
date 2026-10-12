class_name ProvincePanel
extends PanelContainer
## The selected province: owner, region and terrain, people against capacity, satisfaction
## against its target Z*, yield, buildings, castle and garrison, features and the armies
## present, each a button that emits army_selected; a button opens the castle view.

signal army_selected(army_id: int)
signal castle_requested(province_id: String)

var _title := CampaignStyle.heading("", 22)
var _owner := CampaignStyle.label("", CampaignStyle.SMALL_SIZE, CampaignStyle.MUTED)
var _population := CampaignStyle.info()
var _satisfaction := CampaignStyle.info()
var _yield := CampaignStyle.info()
var _castle := CampaignStyle.info()
var _buildings := CampaignStyle.paragraph()
var _features := CampaignStyle.paragraph()
var _armies := VBoxContainer.new()
var _view_castle := Button.new()
var _province_id := ""


func _init() -> void:
	theme = CampaignStyle.theme()
	custom_minimum_size = Vector2(340, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	add_child(column)
	for child: Control in [
		_title, _owner, _population, _satisfaction, _yield, _castle, _buildings, _features
	]:
		column.add_child(child)
	_armies.add_theme_constant_override("separation", 4)
	column.add_child(_armies)
	_population.name = "population"
	_satisfaction.name = "satisfaction"
	_yield.name = "yield"
	_castle.name = "castle"
	_view_castle.name = "view_castle"
	_view_castle.text = tr("CAMPAIGN_VIEW_CASTLE")
	_view_castle.pressed.connect(func() -> void: castle_requested.emit(_province_id))
	column.add_child(_view_castle)
	column.move_child(_view_castle, column.get_children().find(_castle) + 1)


func refresh(state: GameState, rules: GameRules, _house: String, province_id: String) -> void:
	var province: ProvinceState = state.provinces.get(province_id)
	_province_id = province_id
	_view_castle.visible = province != null
	for child: Control in [_owner, _population, _satisfaction, _yield, _castle, _buildings]:
		child.visible = province != null
	_features.visible = province != null
	_armies.visible = province != null
	if province == null:
		_title.text = tr("CAMPAIGN_NO_PROVINCE")
		return
	var def := rules.map.provinces[province_id]
	_title.text = CampaignFormat.province_name(province_id)
	_owner.text = "%s · %s · %s" % [
		CampaignFormat.owner_name(province.owner, province_id),
		tr("CAMPAIGN_REGION_" + def.region.to_upper()),
		tr("CAMPAIGN_TERRAIN_" + def.terrain.to_upper()),
	]
	_owner.add_theme_color_override(
		"font_color", CampaignFormat.owner_color(rules.map, province.owner)
	)
	var is_house := state.houses.has(province.owner)
	_show_people(state, rules, province, is_house)
	_yield.visible = is_house
	if is_house:
		_show_yield(state, rules, province)
	_show_castle(state, rules, province)
	_buildings.text = _buildings_text(province)
	_features.text = CampaignFormat.features(def)
	_show_armies(state, rules, province_id)


func _show_people(
	state: GameState, rules: GameRules, province: ProvinceState, is_house: bool
) -> void:
	var cfg := rules.economy
	var capacity := EconomyBreakdown.capacity(state, rules.map, cfg, province.id)
	_population.text = tr("CAMPAIGN_POPULATION") % [
		CampaignFormat.number(province.population, 1),
		CampaignFormat.number(EconomyTerm.sum(capacity)),
	]
	var people := PackedStringArray([
		CampaignFormat.terms_text(tr("CAMPAIGN_CAPACITY"), capacity, 1, false)
	])
	var satisfaction := CampaignFormat.number(province.satisfaction, 1)
	_satisfaction.text = tr("CAMPAIGN_SATISFACTION") % satisfaction
	_satisfaction.tooltip_text = ""
	_satisfaction.remove_theme_color_override("font_color")
	if is_house:
		var growth := EconomyBreakdown.growth(state, cfg, province.owner, province.id)
		people.append(CampaignFormat.term_line(growth, 3))
		people.append(tr("CAMPAIGN_RECRUITS_LEFT") % province.recruits_left)
		_show_target(state, rules, province)
	_population.tooltip_text = "\n".join(people)


func _show_target(state: GameState, rules: GameRules, province: ProvinceState) -> void:
	var cfg := rules.economy
	var terms := EconomyBreakdown.target_satisfaction(
		state, rules.map, cfg, province.owner, province.id
	)
	var target := EconomyTerm.sum(terms)
	var text := tr("CAMPAIGN_SATISFACTION_TARGET") % [
		CampaignFormat.number(province.satisfaction, 1), CampaignFormat.number(target, 1)
	]
	var lines := PackedStringArray([
		CampaignFormat.terms_text(tr("CAMPAIGN_TARGET"), terms, 1, true, false)
	])
	var step := CampaignFormat.percent(cfg.satisfaction_adjust_rate)
	lines.append(tr("CAMPAIGN_SATISFACTION_STEP") % step)
	var chance := PopulationRules.revolt_chance(cfg, province.satisfaction)
	if chance > 0.0:
		lines.append(tr("CAMPAIGN_REVOLT_CHANCE") % CampaignFormat.percent(chance))
	if province.in_revolt:
		text += " · " + tr("CAMPAIGN_IN_REVOLT")
	if province.occupied_rounds > 0:
		text += " · " + tr("CAMPAIGN_OCCUPIED") % province.occupied_rounds
	var warn := province.in_revolt or chance > 0.0
	if warn:
		_satisfaction.add_theme_color_override("font_color", CampaignStyle.BAD)
	_satisfaction.text = text
	_satisfaction.tooltip_text = "\n".join(lines)


func _show_yield(state: GameState, rules: GameRules, province: ProvinceState) -> void:
	var key := EconomyTerm.province_key(province.id)
	var cfg := rules.economy
	var terms: Array[EconomyTerm] = []
	for term: EconomyTerm in EconomyBreakdown.income(state, rules.map, cfg, province.owner):
		if key in term.args:
			terms.append(term)
	var harvest: Array[EconomyTerm] = []
	for term: EconomyTerm in GrainBreakdown.harvest(state, rules.map, cfg, province.owner):
		if key in term.args:
			harvest.append(term)
	_yield.text = tr("CAMPAIGN_YIELD") % [
		CampaignFormat.number(EconomyTerm.sum(terms), 1),
		CampaignFormat.number(EconomyTerm.sum(harvest)),
	]
	_yield.tooltip_text = "%s\n%s" % [
		CampaignFormat.terms_text(tr("CAMPAIGN_INCOME_ROUND"), terms),
		CampaignFormat.terms_text(tr("CAMPAIGN_HARVEST_NORMAL"), harvest, 0, false),
	]


func _show_castle(state: GameState, rules: GameRules, province: ProvinceState) -> void:
	var owner: HouseState = state.houses.get(province.owner)
	var is_home := owner != null and owner.home_province == province.id
	var level := Garrisons.castle(state, rules, province.id)
	var companies := Garrisons.size(state, rules, province.id)
	_castle.text = tr("CAMPAIGN_CASTLE_LINE") % [
		CampaignFormat.castle_name(province.castle_level, is_home),
		level.wall,
		companies,
		CampaignFormat.percent(province.garrison_health),
	]
	var broken := CampaignFormat.percent(rules.map.campaign.disband_health)
	_castle.tooltip_text = tr("CAMPAIGN_CASTLE_HINT") % broken


func _buildings_text(province: ProvinceState) -> String:
	var names := PackedStringArray()
	for id: String in province.buildings:
		names.append(tr(EconomyTerm.building_key(id)))
	for construction: ConstructionState in province.constructions:
		var project := tr("CAMPAIGN_CASTLE")
		if construction.project != ConstructionState.CASTLE:
			project = tr(EconomyTerm.building_key(construction.project))
		names.append(tr("CAMPAIGN_UNDER_CONSTRUCTION") % [project, construction.rounds_left])
	return tr("CAMPAIGN_BUILDINGS") % ("—" if names.is_empty() else ", ".join(names))


func _show_armies(state: GameState, rules: GameRules, province_id: String) -> void:
	var focus := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var focused := String(focus.name) if focus != null and _armies.is_ancestor_of(focus) else ""
	for child: Node in _armies.get_children():
		_armies.remove_child(child)
		child.queue_free()
	for army: ArmyState in state.armies_in(province_id):
		var entry := Button.new()
		entry.name = "army_%d" % army.id
		var owner: HouseState = state.houses.get(army.owner)
		var led := owner != null and owner.leader_army == army.id
		entry.text = tr("CAMPAIGN_ARMY_ENTRY") % [
			CampaignFormat.owner_name(army.owner),
			army.company_count(),
			tr("CAMPAIGN_WITH_LEADER") if led else "",
		]
		entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var color := CampaignFormat.owner_color(rules.map, army.owner)
		entry.add_theme_color_override("font_color", color)
		entry.pressed.connect(army_selected.emit.bind(army.id))
		_armies.add_child(entry)
		if entry.name == focused:
			entry.grab_focus()
