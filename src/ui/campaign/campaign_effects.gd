class_name CampaignEffects
extends RefCounted
## Player-facing descriptions of buildings, castle levels, decorations and units from their
## data rows: cost, upkeep, effects, unlocks and prerequisites (met or missing).


## Cost, build time, upkeep and effects of a building for the house.
static func building(cfg: EconomyConfig, house: String, building_id: String) -> String:
	var def := cfg.buildings[building_id]
	var lines := PackedStringArray([_cost_line(
		BuildingRules.building_cost(cfg, house, building_id), def.build_rounds, def.upkeep
	)])
	var percent := 100.0
	if def.harvest_bonus != 0.0:
		lines.append(_t("CAMPAIGN_EFFECT_HARVEST") % _n(def.harvest_bonus * percent))
	if def.market_level > 0:
		lines.append(_t("CAMPAIGN_EFFECT_MARKET") % def.market_level)
	if def.satisfaction != 0.0:
		lines.append(_t("CAMPAIGN_EFFECT_SATISFACTION") % _n(def.satisfaction))
	if def.growth != 0.0:
		lines.append(_t("CAMPAIGN_EFFECT_GROWTH") % _n(def.growth * percent))
	if def.prestige != 0.0:
		lines.append(_t("CAMPAIGN_EFFECT_PRESTIGE") % _n(def.prestige))
	if def.spoilage_reduction != 0.0:
		lines.append(_t("CAMPAIGN_EFFECT_SPOILAGE") % _n(def.spoilage_reduction * percent))
	if def.siege_starve_multiplier != 1.0:
		lines.append(_t("CAMPAIGN_EFFECT_SIEGE") % _n(def.siege_starve_multiplier))
	if def.income != 0.0:
		var multiplier: float = cfg.houses[house].building_income.get(building_id, 1.0)
		lines.append(_t("CAMPAIGN_EFFECT_INCOME") % _n(def.income * multiplier))
	if def.income_river != 0.0 or def.income_pass != 0.0:
		lines.append(_t("CAMPAIGN_EFFECT_TOLL") % [_n(def.income_river), _n(def.income_pass)])
	if def.castle_cost_multiplier != 1.0:
		var saving := (1.0 - def.castle_cost_multiplier) * percent
		lines.append(_t("CAMPAIGN_EFFECT_CASTLE_COST") % _n(saving))
	var unlocked := PackedStringArray()
	for unit: String in cfg.units:
		if cfg.units[unit].requires == building_id:
			unlocked.append(CampaignFormat.unit_name(unit))
	if not unlocked.is_empty():
		lines.append(_t("CAMPAIGN_EFFECT_UNLOCKS") % ", ".join(unlocked))
	var note := EconomyTerm.building_key(building_id) + "_NOTE"
	if CampaignFormat.has_text(note):
		lines.append(_t(note))
	return "\n".join(lines)


## The building's prerequisites in the province, each marked when missing.
static func building_requirements(
	state: GameState, rules: GameRules, house: String, province_id: String, building_id: String
) -> PackedStringArray:
	var def := rules.economy.buildings[building_id]
	var province := state.provinces[province_id]
	var map_def := rules.map.provinces[province_id]
	var castle := state.home_castle_level(house)
	var lines := PackedStringArray()
	if def.is_home_only:
		var is_home := BuildingRules.is_home(state, house, province_id)
		lines.append(_requirement(_t("CAMPAIGN_REQ_HOME_ONLY"), is_home))
	if def.home_castle > 0:
		var castle_text := _t("CAMPAIGN_REQ_HOME_CASTLE") % def.home_castle
		lines.append(_requirement(castle_text, castle >= def.home_castle))
	if not def.upgrade_of.is_empty():
		var name := _t(EconomyTerm.building_key(def.upgrade_of))
		var stands := def.upgrade_of in province.buildings
		lines.append(_requirement(_t("CAMPAIGN_REQ_BUILDING") % name, stands))
	if not def.features.is_empty():
		var names := PackedStringArray()
		var met := false
		for feature: String in def.features:
			names.append(_t("CAMPAIGN_FEATURE_" + feature.to_upper()))
			met = met or map_def.has_feature(feature)
		lines.append(_requirement(_t("CAMPAIGN_REQ_FEATURE") % " / ".join(names), met))
	return lines


## Name, cost, upkeep, wall, garrison, prestige, unlocks and prerequisite of a castle level.
static func castle_level(
	cfg: EconomyConfig, number: int, is_home: bool, cost: float, home_castle_level: int
) -> String:
	var table := cfg.home_castle if is_home else cfg.province_castle
	var level := table[number]
	var lines := PackedStringArray([
		"%s (%s)" % [CampaignFormat.castle_name(number, is_home), _t("CAMPAIGN_LEVEL") % number],
		_cost_line(cost, level.build_rounds, level.upkeep),
		_t("CAMPAIGN_CASTLE_DEFENCE") % [level.wall, level.garrison],
	])
	if level.prestige != 0.0:
		lines.append(_t("CAMPAIGN_EFFECT_PRESTIGE") % _n(level.prestige))
	if is_home:
		var unlocked := _unlocked_by_home_castle(cfg, number)
		if not unlocked.is_empty():
			lines.append(_t("CAMPAIGN_EFFECT_UNLOCKS") % ", ".join(unlocked))
	if level.home_castle > 0:
		var met := home_castle_level >= level.home_castle
		lines.append(_requirement(_t("CAMPAIGN_REQ_HOME_CASTLE") % level.home_castle, met))
	return "\n".join(lines)


static func decoration(cfg: EconomyConfig, decoration_id: String, home_castle_level: int) -> String:
	var def := cfg.decorations[decoration_id]
	var lines := PackedStringArray([_t("CAMPAIGN_COST") % _n(def.cost)])
	if def.prestige != 0.0:
		lines.append(_t("CAMPAIGN_EFFECT_PRESTIGE") % _n(def.prestige))
	if def.satisfaction != 0.0:
		lines.append(_t("CAMPAIGN_EFFECT_HOME_SATISFACTION") % _n(def.satisfaction))
	if def.home_castle > 0:
		var met := home_castle_level >= def.home_castle
		lines.append(_requirement(_t("CAMPAIGN_REQ_HOME_CASTLE") % def.home_castle, met))
	return "\n".join(lines)


## Cost in taler, people and satisfaction, upkeep and unlock of a unit for the house.
static func unit(
	state: GameState, cfg: EconomyConfig, house: String, unit_id: String, province_id: String
) -> String:
	var def := cfg.units[unit_id]
	var lines := PackedStringArray([
		_t("CAMPAIGN_UNIT_COST") % [
			_n(RecruitCommand.unit_cost(cfg, house, unit_id)),
			_n(def.population),
			_n(cfg.recruit_satisfaction_cost),
		],
		_t("CAMPAIGN_UNIT_UPKEEP") % [_n(def.upkeep_gold), _n(def.upkeep_grain)],
	])
	var castle := state.home_castle_level(house)
	var castle_text := _t("CAMPAIGN_REQ_HOME_CASTLE") % def.home_castle
	lines.append(_requirement(castle_text, castle >= def.home_castle))
	if not def.requires.is_empty():
		var name := _t(EconomyTerm.building_key(def.requires))
		var province: ProvinceState = state.provinces.get(province_id)
		var stands := province != null and def.requires in province.buildings
		lines.append(_requirement(_t("CAMPAIGN_REQ_BUILDING") % name, stands))
	if def.is_mercenary:
		lines.append(_t("CAMPAIGN_UNIT_MERCENARY"))
	return "\n".join(lines)


static func _unlocked_by_home_castle(cfg: EconomyConfig, level: int) -> PackedStringArray:
	var names := PackedStringArray()
	for id: String in cfg.units:
		if cfg.units[id].home_castle == level and level > 1:
			names.append(CampaignFormat.unit_name(id))
	for id: String in cfg.buildings:
		if cfg.buildings[id].home_castle == level:
			names.append(_t(EconomyTerm.building_key(id)))
	for id: String in cfg.decorations:
		if cfg.decorations[id].home_castle == level:
			names.append(_t(EconomyTerm.decoration_key(id)))
	for number: int in cfg.province_castle:
		if cfg.province_castle[number].home_castle == level:
			names.append(CampaignFormat.castle_name(number, false))
	return names


static func _cost_line(cost: float, rounds: int, upkeep: float) -> String:
	return _t("CAMPAIGN_COST_LINE") % [_n(cost), rounds, _n(upkeep)]


static func _requirement(text: String, is_met: bool) -> String:
	var line := _t("CAMPAIGN_REQUIRES") % text
	return line if is_met else "%s (%s)" % [line, _t("CAMPAIGN_MISSING")]


static func _n(value: float) -> String:
	return CampaignFormat.formula(EconomyTerm.num(value))


static func _t(key: String) -> String:
	return CampaignFormat.t(key)
