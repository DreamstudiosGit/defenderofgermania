class_name GrainBreakdown
extends RefCounted
## The summands behind the grain numbers the UI shows: harvest, demand, spoilage and prices
## (docs/design/economy.md, "Tooltips and forecast"); see EconomyBreakdown for gold.

## Weather factor of an average year. The year's weather is rolled at the autumn settlement,
## after every administration phase, so previews always use this.
const NORMAL_WEATHER := 1.0


## Autumn harvest per own province. weather maps region ids to factors (missing regions:
## NORMAL_WEATHER); rounds_ahead counts the settlements before the harvest, during which
## occupations run out.
static func harvest(
	state: GameState,
	map: MapData,
	cfg: EconomyConfig,
	house_id: String,
	weather: Dictionary[String, float] = {},
	rounds_ahead: int = 0
) -> Array[EconomyTerm]:
	var terms: Array[EconomyTerm] = []
	for province: ProvinceState in state.provinces_of(house_id):
		var def := map.provinces[province.id]
		var factor: float = weather.get(def.region, NORMAL_WEATHER)
		var field := map.terrains[def.terrain].field_yield
		var bonus := EconomySettlement.building_sum(cfg, [province], "harvest_bonus")
		var disrupted := province.occupied_rounds > rounds_ahead or province.in_revolt
		var value := GrainRules.harvest(cfg, province.population, field, factor, bonus, disrupted)
		var formula := "%s × %s × %s" % [_n(province.population), _n(field), _n(factor)]
		if bonus != 0.0:
			formula += " × (1 + %s)" % _n(bonus)
		if disrupted:
			formula += " × %s" % _n(cfg.harvest_disrupted_multiplier)
		var flooded: float = state.events.harvest.get(province.id, 0.0)
		if flooded != 0.0:
			value *= 1.0 + flooded
			formula += " × (1 + %s)" % _n(flooded)
		var key := EconomyTerm.province_key(province.id)
		terms.append(EconomyTerm.create("ECONOMY_TERM_HARVEST", value, formula, [key]))
	return terms


## Grain eaten at a settlement in the given season: the people of each own province, then
## the troops of each army (more in winter outside own provinces), then what an event adds
## to this round's settlement (harsh winter).
static func grain_demand(
	state: GameState,
	cfg: EconomyConfig,
	house_id: String,
	season: GameState.Season,
	ration: int = EconomyBreakdown.CURRENT
) -> Array[EconomyTerm]:
	var house := state.houses[house_id]
	var portion := house.ration if ration == EconomyBreakdown.CURRENT else ration
	var terms: Array[EconomyTerm] = []
	for province: ProvinceState in state.provinces_of(house_id):
		var value := GrainRules.demand(province.population, portion, 0.0)
		var formula := "%s × %d/%d" % [
			_n(province.population), portion, GameState.ROUNDS_PER_YEAR
		]
		var key := EconomyTerm.province_key(province.id)
		terms.append(EconomyTerm.create("ECONOMY_TERM_PEOPLE_GRAIN", value, formula, [key]))
	var is_winter := season == GameState.Season.WINTER
	for army: ArmyState in state.armies_of(house_id):
		var abroad := is_winter and state.provinces[army.province].owner != house_id
		var value := 0.0
		for id: String in army.units:
			value += GrainRules.troop_grain(cfg, cfg.units[id].upkeep_grain, abroad)
		var formula := EconomyTerm.per_unit(cfg, army.units, "upkeep_grain")
		if abroad:
			formula = "(%s) × %s" % [formula, _n(cfg.winter_abroad_multiplier)]
		var where := EconomyTerm.province_key(army.province)
		terms.append(EconomyTerm.create("ECONOMY_TERM_TROOP_GRAIN", value, formula, [where]))
	var extra: float = state.events.grain_demand.get(house_id, 0.0)
	if extra != 0.0 and season == state.season():
		var eaten := EconomyTerm.sum(terms)
		var formula := "%s × %s" % [_n(eaten), _n(extra)]
		terms.append(EconomyTerm.create("ECONOMY_TERM_EVENT_GRAIN", eaten * extra, formula))
	return terms


## Grain the house eats in the four seasons from now on, at today's people and armies.
static func yearly_grain_demand(state: GameState, cfg: EconomyConfig, house_id: String) -> float:
	var total := 0.0
	for season: int in GameState.ROUNDS_PER_YEAR:
		total += EconomyTerm.sum(grain_demand(state, cfg, house_id, season as GameState.Season))
	return total


## Share of the stock that spoils after each settlement's meal.
static func spoilage(state: GameState, cfg: EconomyConfig, house_id: String) -> EconomyTerm:
	var owned := state.provinces_of(house_id)
	var reduction := EconomySettlement.building_sum(cfg, owned, "spoilage_reduction")
	var formula := "max(%s, %s − %s)" % [
		_n(cfg.spoilage_min), _n(cfg.spoilage_base), _n(reduction)
	]
	var rate := GrainRules.spoilage_rate(cfg, reduction)
	return EconomyTerm.create("ECONOMY_TERM_SPOILAGE", rate, formula)


## The grain price of this round, then the house's buy and sell price; three prices, not
## summands.
static func grain_prices(
	state: GameState, cfg: EconomyConfig, house_id: String
) -> Array[EconomyTerm]:
	var price := TradeGrainCommand.current_price(state, cfg)
	var formula := "%s × (1 + %s × %d)" % [
		_n(state.autumn_grain_price), _n(cfg.price_rise_per_round), state.rounds_since_autumn()
	]
	if state.grain_traded != 0.0:
		formula += " × (1 + %s × %s/100)" % [
			_n(cfg.price_impact_per_100), _n(state.grain_traded)
		]
	var spread := cfg.houses[house_id].grain_spread
	var buy := GrainRules.buy_price(price, spread)
	var sell := GrainRules.sell_price(price, spread)
	var terms: Array[EconomyTerm] = [
		EconomyTerm.create("ECONOMY_TERM_GRAIN_PRICE", price, formula),
		EconomyTerm.create("ECONOMY_TERM_BUY_PRICE", buy, "%s × (1 + %s)" % [_n(price), _n(spread)]),
		EconomyTerm.create(
			"ECONOMY_TERM_SELL_PRICE", sell, "%s × (1 − %s)" % [_n(price), _n(spread)]
		),
	]
	return terms


static func _n(number: float) -> String:
	return EconomyTerm.num(number)
