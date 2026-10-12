class_name EconomyBreakdown
extends RefCounted
## The summands behind each economy number the UI shows (docs/design/economy.md, "Tooltips
## and forecast"). Values come from IncomeRules, GrainRules and PopulationRules with the
## inputs EconomySettlement uses, so the terms add up to what the next settlement applies.
## Lever arguments left at CURRENT use the house's own setting; grain terms: GrainBreakdown.

const CURRENT := -1


## The next settlement's change of the house's taler: income, then upkeep (negative).
static func gold_change(
	state: GameState, map: MapData, cfg: EconomyConfig, house_id: String
) -> Array[EconomyTerm]:
	var terms := income(state, map, cfg, house_id)
	terms.append_array(upkeep(state, cfg, house_id))
	return terms


## Tax, market, fixed and building income per own province; a province in revolt pays
## nothing and shows as a zero term.
static func income(
	state: GameState, map: MapData, cfg: EconomyConfig, house_id: String, tax_rate: int = CURRENT
) -> Array[EconomyTerm]:
	var house := state.houses[house_id]
	var rate := house.tax_rate if tax_rate == CURRENT else tax_rate
	var terms: Array[EconomyTerm] = []
	for province: ProvinceState in state.provinces_of(house_id):
		var key := EconomyTerm.province_key(province.id)
		if province.in_revolt:
			terms.append(EconomyTerm.create("ECONOMY_TERM_REVOLT", 0.0, "", [key]))
			continue
		var def := map.provinces[province.id]
		terms.append(_tax(cfg, province, IncomeRules.effective_tax_rate(rate, def.tax_cap)))
		if EconomySettlement.market_level(cfg, province) > 0:
			terms.append(_market(state, cfg, house_id, province))
		if def.fixed_income != 0.0:
			terms.append(
				EconomyTerm.create("ECONOMY_TERM_FIXED_INCOME", def.fixed_income, "", [key])
			)
		terms.append_array(_building_income(cfg, house_id, def, province))
	return terms


## Unit upkeep per army (×1.25 while besieging), then castle and building upkeep per own
## province; all values negative.
static func upkeep(state: GameState, cfg: EconomyConfig, house_id: String) -> Array[EconomyTerm]:
	var house := state.houses[house_id]
	var terms: Array[EconomyTerm] = []
	for army: ArmyState in state.armies_of(house_id):
		var siege := cfg.siege_upkeep_multiplier if state.is_besieging(army) else 1.0
		var value := IncomeRules.unit_upkeep(cfg, army.units) * siege
		var formula := EconomyTerm.per_unit(cfg, army.units, "upkeep_gold")
		if siege != 1.0:
			formula = "(%s) × %s" % [formula, _n(siege)]
		var where := EconomyTerm.province_key(army.province)
		terms.append(EconomyTerm.create("ECONOMY_TERM_ARMY_UPKEEP", -value, formula, [where]))
	for province: ProvinceState in state.provinces_of(house_id):
		var key := EconomyTerm.province_key(province.id)
		var is_home := province.id == house.home_province
		var castle := IncomeRules.castle_upkeep(cfg, province.castle_level, is_home)
		if castle != 0.0:
			var name := EconomyTerm.castle_key(province.castle_level, is_home)
			terms.append(EconomyTerm.create("ECONOMY_TERM_CASTLE_UPKEEP", -castle, "", [name, key]))
		for id: String in province.buildings:
			var amount := cfg.buildings[id].upkeep
			if amount != 0.0:
				var building := EconomyTerm.building_key(id)
				terms.append(
					EconomyTerm.create("ECONOMY_TERM_BUILDING_UPKEEP", -amount, "", [building, key])
				)
	return terms


## The summands of a province's target satisfaction Z*; a last term clamps them to 0–100.
static func target_satisfaction(
	state: GameState,
	map: MapData,
	cfg: EconomyConfig,
	house_id: String,
	province_id: String,
	tax_rate: int = CURRENT,
	ration: int = CURRENT
) -> Array[EconomyTerm]:
	var house := state.houses[house_id]
	var province := state.provinces[province_id]
	var def := map.provinces[province_id]
	var wanted := house.tax_rate if tax_rate == CURRENT else tax_rate
	var rate := IncomeRules.effective_tax_rate(wanted, def.tax_cap)
	var portion := house.ration if ration == CURRENT else ration
	var castle := province.castle_level if province_id == house.home_province else 0
	var bonus_terms := _satisfaction_bonus(cfg, house, def, province)
	var bonus := EconomyTerm.sum(bonus_terms)
	var occupied := province.occupied_rounds > 0
	var parts := PopulationRules.target_satisfaction_parts(
		cfg, rate, portion, bonus, house.prestige, castle, occupied, house.is_banned
	)
	var formulas: Dictionary[String, String] = {
		"tax": "−%s × (%d − %s)" % [_n(cfg.tax_weight), rate, _n(cfg.tax_pivot)],
		"ration": "%s × (%d − %d)" % [_n(cfg.ration_weight), portion, cfg.normal_ration],
		"prestige": "%s/%s" % [_n(house.prestige), _n(cfg.prestige_divisor)],
		"home_castle": "%s × (%d − 1)" % [_n(cfg.home_castle_bonus), castle],
	}
	var terms: Array[EconomyTerm] = []
	for part: String in parts:
		if part == "bonus":
			terms.append_array(bonus_terms)
		elif parts[part] != 0.0 or part in ["base", "tax", "ration", "prestige"]:
			var label := "ECONOMY_Z_" + part.to_upper()
			terms.append(EconomyTerm.create(label, parts[part], formulas.get(part, "")))
	var total := PopulationRules.target_satisfaction(
		cfg, rate, portion, bonus, house.prestige, castle, occupied, house.is_banned
	)
	var raw := EconomyTerm.sum(terms)
	if not is_equal_approx(total, raw):
		terms.append(EconomyTerm.create("ECONOMY_Z_LIMIT", total - raw))
	return terms


## The change of the house's prestige at the next settlement: decay, running sources and
## the collected one-offs; hunger and revolts, decided by the settlement itself, are left out.
static func prestige(state: GameState, cfg: EconomyConfig, house_id: String) -> Array[EconomyTerm]:
	var house := state.houses[house_id]
	var current := house.prestige
	var decay := PopulationRules.next_prestige(cfg, current, 0.0) - current
	var decay_formula := "−(1 − %s) × %s" % [_n(cfg.prestige_decay), _n(current)]
	var terms: Array[EconomyTerm] = [
		EconomyTerm.create("ECONOMY_PRESTIGE_DECAY", decay, decay_formula)
	]
	var sources: Array[EconomyTerm] = []
	for province: ProvinceState in state.provinces_of(house_id):
		for id: String in province.buildings:
			var amount := cfg.buildings[id].prestige
			if amount != 0.0:
				var names: Array[String] = [
					EconomyTerm.building_key(id), EconomyTerm.province_key(province.id)
				]
				sources.append(EconomyTerm.create("ECONOMY_PRESTIGE_BUILDING", amount, "", names))
	var level := state.home_castle_level(house_id)
	if cfg.home_castle.has(level):
		var castle_name := EconomyTerm.castle_key(level, true)
		var amount := cfg.home_castle[level].prestige
		sources.append(EconomyTerm.create("ECONOMY_PRESTIGE_CASTLE", amount, "", [castle_name]))
	for id: String in house.decorations:
		var amount := cfg.decorations[id].prestige
		if amount != 0.0:
			var name := EconomyTerm.decoration_key(id)
			sources.append(EconomyTerm.create("ECONOMY_PRESTIGE_DECORATION", amount, "", [name]))
	if house.pending_prestige != 0.0:
		sources.append(EconomyTerm.create("ECONOMY_PRESTIGE_PENDING", house.pending_prestige))
	if house.is_banned:
		sources.append(EconomyTerm.create("ECONOMY_PRESTIGE_BAN", -cfg.ban_prestige))
	terms.append_array(sources)
	var change := PopulationRules.next_prestige(cfg, current, EconomyTerm.sum(sources)) - current
	var raw := EconomyTerm.sum(terms)
	if not is_equal_approx(change, raw):
		terms.append(EconomyTerm.create("ECONOMY_PRESTIGE_LIMIT", change - raw))
	return terms


## Population limit K of a province: start population, castle level and market level.
static func capacity(
	state: GameState, map: MapData, cfg: EconomyConfig, province_id: String
) -> Array[EconomyTerm]:
	var province := state.provinces[province_id]
	var start := map.provinces[province_id].population
	var market := EconomySettlement.market_level(cfg, province)
	var castle := province.castle_level
	var terms: Array[EconomyTerm] = [
		EconomyTerm.create(
			"ECONOMY_CAPACITY_START",
			PopulationRules.capacity(cfg, start, 0, 0),
			"%s × %s" % [_n(cfg.capacity_start_factor), _n(start)]
		)
	]
	if castle > 0:
		var value := PopulationRules.capacity(cfg, 0.0, castle, 0)
		var formula := "%s × %d" % [_n(cfg.capacity_per_castle_level), castle]
		terms.append(EconomyTerm.create("ECONOMY_CAPACITY_CASTLE", value, formula))
	if market > 0:
		var value := PopulationRules.capacity(cfg, 0.0, 0, market)
		var formula := "%s × %d" % [_n(cfg.capacity_per_market_level), market]
		terms.append(EconomyTerm.create("ECONOMY_CAPACITY_MARKET", value, formula))
	return terms


## Yearly growth rate g of an own province at its current satisfaction (spring census).
static func growth(
	state: GameState, cfg: EconomyConfig, house_id: String, province_id: String
) -> EconomyTerm:
	var province := state.provinces[province_id]
	var portion := state.houses[house_id].ration
	var bonus := EconomySettlement.building_sum(cfg, [province], "growth")
	var rate := PopulationRules.growth_rate(cfg, province.satisfaction, portion, bonus, 0.0)
	var formula := "%s × (%s − %s)/%s + %s × (%d − %d)" % [
		_n(cfg.growth_base), _n(province.satisfaction), _n(cfg.growth_pivot),
		_n(cfg.growth_span), _n(cfg.ration_growth), portion, cfg.normal_ration
	]
	if bonus != 0.0:
		formula += " + %s" % _n(bonus)
	return EconomyTerm.create("ECONOMY_TERM_GROWTH", rate, formula)


static func _tax(cfg: EconomyConfig, province: ProvinceState, rate: int) -> EconomyTerm:
	var value := IncomeRules.tax(cfg, province.population, rate, province.satisfaction)
	var formula := "%s × %d %% × %s × (%s + %s/%s)" % [
		_n(province.population), rate, _n(cfg.tax_factor), _n(cfg.tax_base),
		_n(province.satisfaction), _n(cfg.tax_satisfaction_divisor)
	]
	var key := EconomyTerm.province_key(province.id)
	return EconomyTerm.create("ECONOMY_TERM_TAX", value, formula, [key])


static func _market(
	state: GameState, cfg: EconomyConfig, house_id: String, province: ProvinceState
) -> EconomyTerm:
	var level := EconomySettlement.market_level(cfg, province)
	var multiplier := cfg.houses[house_id].market_multiplier
	var is_autumn := state.season() == GameState.Season.AUTUMN
	var value := IncomeRules.market(
		cfg, province.population, level, multiplier, is_autumn, province.satisfaction
	)
	var factors := PackedStringArray([_n(province.population), _n(cfg.market_factor), str(level)])
	if multiplier != 1.0:
		factors.append(_n(multiplier))
	if is_autumn:
		factors.append(_n(cfg.market_autumn_multiplier))
	if province.satisfaction < cfg.market_unrest_threshold:
		factors.append(_n(cfg.market_unrest_multiplier))
	var key := EconomyTerm.province_key(province.id)
	return EconomyTerm.create("ECONOMY_TERM_MARKET", value, " × ".join(factors), [key])


static func _building_income(
	cfg: EconomyConfig, house_id: String, def: MapData.ProvinceDef, province: ProvinceState
) -> Array[EconomyTerm]:
	var terms: Array[EconomyTerm] = []
	for id: String in province.buildings:
		var multiplier: float = cfg.houses[house_id].building_income.get(id, 1.0)
		var value := IncomeRules.building_income(
			cfg.buildings[id], multiplier, not def.river.is_empty(), def.has_pass
		)
		if value == 0.0:
			continue
		var formula := "" if multiplier == 1.0 else "%s × %s" % [
			_n(value / multiplier), _n(multiplier)
		]
		var names: Array[String] = [
			EconomyTerm.building_key(id), EconomyTerm.province_key(province.id)
		]
		terms.append(EconomyTerm.create("ECONOMY_TERM_BUILDING_INCOME", value, formula, names))
	return terms


## Bonus summands of Z* in the order EconomySettlement adds them: buildings, the province's
## own bonus, decorations of the home castle.
static func _satisfaction_bonus(
	cfg: EconomyConfig, house: HouseState, def: MapData.ProvinceDef, province: ProvinceState
) -> Array[EconomyTerm]:
	var terms: Array[EconomyTerm] = []
	for id: String in province.buildings:
		var amount := cfg.buildings[id].satisfaction
		if amount != 0.0:
			var name := EconomyTerm.building_key(id)
			terms.append(EconomyTerm.create("ECONOMY_Z_BUILDING", amount, "", [name]))
	if def.satisfaction_bonus != 0.0:
		terms.append(EconomyTerm.create("ECONOMY_Z_PROVINCE", def.satisfaction_bonus))
	if province.id == house.home_province:
		for id: String in house.decorations:
			var amount := cfg.decorations[id].satisfaction
			if amount != 0.0:
				var name := EconomyTerm.decoration_key(id)
				terms.append(EconomyTerm.create("ECONOMY_Z_DECORATION", amount, "", [name]))
	return terms


static func _n(number: float) -> String:
	return EconomyTerm.num(number)
