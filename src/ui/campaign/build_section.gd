class_name BuildSection
extends AdministrationSection
## Building orders and the castle upgrade in the selected own province: every building with
## its cost, upkeep and effect, and why it cannot be ordered.

var _title := CampaignStyle.heading("", 18)
var _hint := CampaignStyle.paragraph()
var _slots := CampaignStyle.paragraph()
var _standing := CampaignStyle.paragraph()
var _buildings := GridContainer.new()
var _castle := VBoxContainer.new()


func _init() -> void:
	super()
	for child: Control in [_title, _hint, _slots, _standing, _buildings]:
		column.add_child(child)
	_buildings.columns = 2
	_buildings.add_theme_constant_override("h_separation", 6)
	_buildings.add_theme_constant_override("v_separation", 6)
	_castle.add_theme_constant_override("separation", 6)
	_castle.add_child(HSeparator.new())
	column.add_child(_castle)


func refresh(state: GameState, rules: GameRules, house: String, province_id: String) -> void:
	var province: ProvinceState = state.provinces.get(province_id)
	var own := province != null and province.owner == house
	_hint.visible = not own
	for part: Control in [_slots, _standing, _buildings, _castle]:
		part.visible = own
	if not own:
		_title.text = tr("CAMPAIGN_BUILD")
		_hint.text = tr("CAMPAIGN_SELECT_OWN_PROVINCE")
		return
	_title.text = tr("CAMPAIGN_BUILD_IN") % CampaignFormat.province_name(province_id)
	_show_slots(state, rules, house, province)
	var cfg := rules.economy
	for id: String in cfg.buildings:
		var choice := button(_buildings, "building_" + id)
		var name := tr(EconomyTerm.building_key(id))
		var cost := BuildingRules.building_cost(cfg, house, id)
		var details := PackedStringArray([CampaignEffects.building(cfg, house, id)])
		details.append_array(
			CampaignEffects.building_requirements(state, rules, house, province_id, id)
		)
		var command := BuildCommand.new(cfg, rules.map, house, province_id, id)
		var caption := "%s · %s T" % [name, CampaignFormat.number(cost)]
		if BuildingRules.is_present(cfg, province, id):
			caption = "%s · %s" % [name, tr("CAMPAIGN_PRESENT")]
		offer(choice, caption, command, state, "\n".join(details))
	_show_castle(state, rules, house, province)


func _show_slots(
	state: GameState, rules: GameRules, house: String, province: ProvinceState
) -> void:
	var cfg := rules.economy
	var is_home := BuildingRules.is_home(state, house, province.id)
	var total := BuildingRules.slots(cfg, is_home, state.home_castle_level(house))
	var used := BuildingRules.used_slots(cfg, province)
	_slots.text = tr("CAMPAIGN_SLOTS") % [used, total]
	var names := PackedStringArray()
	for id: String in province.buildings:
		names.append(tr(EconomyTerm.building_key(id)))
	for construction: ConstructionState in province.constructions:
		if construction.project != ConstructionState.CASTLE:
			names.append(tr("CAMPAIGN_UNDER_CONSTRUCTION") % [
				tr(EconomyTerm.building_key(construction.project)), construction.rounds_left
			])
	_standing.text = tr("CAMPAIGN_BUILDINGS") % ("—" if names.is_empty() else ", ".join(names))


func _show_castle(
	state: GameState, rules: GameRules, house: String, province: ProvinceState
) -> void:
	var cfg := rules.economy
	var is_home := BuildingRules.is_home(state, house, province.id)
	var level := province.castle_level
	heading(_castle, "title").text = tr("CAMPAIGN_CASTLE")
	var current := note(_castle, "current", CampaignStyle.TEXT)
	current.text = "%s (%s)" % [
		CampaignFormat.castle_name(level, is_home), tr("CAMPAIGN_LEVEL") % level
	]
	var upgrade := button(_castle, "upgrade")
	var command := UpgradeCastleCommand.new(cfg, house, province.id)
	var table := BuildingRules.castle_table(state, cfg, house, province.id)
	if not table.has(level + 1):
		offer(upgrade, tr("CAMPAIGN_CASTLE_MAX"), command, state, "")
		return
	var cost := BuildingRules.castle_cost(state, cfg, house, table[level + 1])
	var details := CampaignEffects.castle_level(
		cfg, level + 1, is_home, cost, state.home_castle_level(house)
	)
	var caption := tr("CAMPAIGN_CASTLE_UPGRADE") % [
		CampaignFormat.castle_name(level + 1, is_home), CampaignFormat.number(cost)
	]
	if province.has_project(ConstructionState.CASTLE):
		caption = tr("CAMPAIGN_CASTLE_BUILDING") % CampaignFormat.castle_name(level + 1, is_home)
	offer(upgrade, caption, command, state, details)
