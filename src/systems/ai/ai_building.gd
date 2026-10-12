class_name AiBuilding
extends RefCounted
## Goal options for land and castle: buildings, the next home castle level and decorations,
## each valued as taler earned (or worth) over the payback horizon per taler spent.


static func options(turn: AiTurn) -> Array[AiOption]:
	var result: Array[AiOption] = []
	var state := turn.state
	var cfg := turn.rules.economy
	for province: ProvinceState in state.provinces_of(turn.house):
		for id: String in cfg.buildings:
			var command := BuildCommand.new(cfg, turn.rules.map, turn.house, province.id, id)
			if not command.validate(state).is_empty():
				continue
			var cost := BuildingRules.building_cost(cfg, turn.house, id)
			var worth := _building_worth(turn, province, id)
			var label := "build %s in %s" % [id, province.id]
			result.append(AiOption.create(label, worth / maxf(cost, 1.0), command, cost))
	_castle(turn, result)
	_decorations(turn, result)
	return result


## Taler worth over the payback horizon: income, harvest, people and prestige.
static func _building_worth(turn: AiTurn, province: ProvinceState, id: String) -> float:
	var rules := turn.rules
	var cfg := rules.economy
	var def := cfg.buildings[id]
	var map_def := rules.map.provinces[province.id]
	var modifiers := cfg.houses[turn.house]
	var per_round: float = def.income * modifiers.building_income.get(id, 1.0)
	if not map_def.river.is_empty():
		per_round += def.income_river
	if map_def.has_pass:
		per_round += def.income_pass
	if def.market_level > 0:
		var levels := def.market_level - EconomySettlement.market_level(cfg, province)
		per_round += IncomeRules.market(
			cfg, province.population, levels, modifiers.market_multiplier, false, 60.0
		)
	var field := rules.map.terrains[map_def.terrain].field_yield
	per_round += def.harvest_bonus * province.population * field * 0.4 / 4.0
	per_round += def.satisfaction * turn.value("satisfaction") * 0.2
	per_round += def.prestige * turn.value("prestige")
	per_round += def.spoilage_reduction * turn.owner().grain * 0.4
	per_round -= def.upkeep
	var category := "economy"
	if def.prestige > 0.0 or def.satisfaction > 0.0:
		category = "court"
	if id == cfg.tournament_building:
		per_round += 12.0
		category = "court"
	if def.castle_cost_multiplier < 1.0:
		per_round += 8.0
		category = "castle"
	return per_round * turn.cfg.goals["payback_rounds"] * turn.weight(category)


## The next home castle level: prestige every round and what it unlocks (forged regalia from
## level 3 matter most to a house without the true ones).
static func _castle(turn: AiTurn, result: Array[AiOption]) -> void:
	var state := turn.state
	var cfg := turn.rules.economy
	var home := turn.owner().home_province
	var command := UpgradeCastleCommand.new(cfg, turn.house, home)
	if not command.validate(state).is_empty():
		return
	var level := state.home_castle_level(turn.house) + 1
	if not cfg.home_castle.has(level):
		return
	var def := cfg.home_castle[level]
	var worth := def.prestige * turn.value("prestige") * turn.cfg.goals["payback_rounds"]
	if level == turn.rules.map.crown.forged_regalia_home_castle:
		if not CrownRules.holds_true_regalia(state, turn.house):
			worth += turn.value("legitimacy") * turn.rules.map.campaign.legitimacy_forged_regalia
	worth += def.wall * turn.value("province") * 0.5
	var campaign := turn.rules.map.campaign
	if campaign.max_armies(level) > campaign.max_armies(level - 1):
		worth += turn.value("province") * 2.0 * turn.weight("military")
	var cost := BuildingRules.castle_cost(state, cfg, turn.house, def)
	var utility := worth * turn.weight("castle") / maxf(cost, 1.0)
	var option := AiOption.create("castle level %d" % level, utility, command, cost)
	result.append(option)


static func _decorations(turn: AiTurn, result: Array[AiOption]) -> void:
	var cfg := turn.rules.economy
	for id: String in cfg.decorations:
		var command := BuyDecorationCommand.new(cfg, turn.house, id)
		if not command.validate(turn.state).is_empty():
			continue
		var def := cfg.decorations[id]
		var per_round := def.prestige * turn.value("prestige")
		per_round += def.satisfaction * turn.value("satisfaction") * 0.2
		var worth := per_round * turn.cfg.goals["payback_rounds"] * turn.weight("court")
		var utility := worth / maxf(def.cost, 1.0)
		result.append(AiOption.create("decorate " + id, utility, command, def.cost))
