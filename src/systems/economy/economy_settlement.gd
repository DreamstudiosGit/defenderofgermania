class_name EconomySettlement
extends RefCounted
## Round phase 4 ("settlement"): applies the economy rules to every house at once.
## All chance comes from state.rng, so the same seed and commands give the same state.


static func settle(state: GameState, map: MapData, cfg: EconomyConfig) -> void:
	if state.season() == GameState.Season.AUTUMN:
		_roll_harvest_year(state, map, cfg)
	for house: HouseState in state.houses.values():
		_settle_house(state, map, cfg, house)
	BuildingRules.advance(state, cfg)
	state.grain_traded = 0.0
	state.turn += 1
	if state.season() == GameState.Season.SPRING:
		for province: ProvinceState in state.provinces.values():
			province.recruits_left = PopulationRules.recruit_limit(cfg, province.population)


static func _roll_harvest_year(state: GameState, map: MapData, cfg: EconomyConfig) -> void:
	var total := 0.0
	for region: String in map.regions:
		var weather := GrainRules.roll_weather(cfg, state.rng)
		state.weather[region] = weather
		total += weather
	var noise := GrainRules.roll_price_noise(cfg, state.rng)
	state.autumn_grain_price = GrainRules.autumn_price(cfg, total / map.regions.size(), noise)


static func _settle_house(
	state: GameState, map: MapData, cfg: EconomyConfig, house: HouseState
) -> void:
	var season := state.season()
	var owned := state.provinces_of(house.id)
	var prestige_delta := house.pending_prestige - (cfg.ban_prestige if house.is_banned else 0.0)
	house.pending_prestige = 0.0

	house.gold += _income(state, map, cfg, house, owned) - _upkeep(state, cfg, house, owned)
	if house.gold < 0.0:
		_desert(state, cfg, house)
		for province: ProvinceState in owned:
			province.satisfaction = maxf(
				0.0, province.satisfaction - cfg.treasury_satisfaction_penalty
			)

	if season == GameState.Season.AUTUMN:
		house.grain += _harvest(state, map, cfg, owned)
	var needed := _grain_demand(state, cfg, house, owned)
	var covered := GrainRules.coverage(house.grain, needed)
	house.grain = maxf(0.0, house.grain - needed)
	if covered < 1.0:
		prestige_delta -= cfg.shortage_prestige
		for province: ProvinceState in owned:
			province.satisfaction = maxf(
				0.0, province.satisfaction - GrainRules.shortage_satisfaction_loss(cfg, covered)
			)
			province.population *= GrainRules.shortage_population_factor(cfg, covered)
	var reduction := building_sum(cfg, owned, "spoilage_reduction")
	house.grain *= 1.0 - GrainRules.spoilage_rate(cfg, reduction)

	for province: ProvinceState in owned:
		var target := _target_satisfaction(map, cfg, house, province)
		province.satisfaction = PopulationRules.next_satisfaction(
			cfg, province.satisfaction, target
		)
		var chance := PopulationRules.revolt_chance(cfg, province.satisfaction)
		if not province.in_revolt and chance > 0.0 and state.rng.randf() < chance:
			province.in_revolt = true
			prestige_delta -= cfg.revolt_prestige

	var running := _running_prestige(cfg, house, owned)
	house.prestige = PopulationRules.next_prestige(cfg, house.prestige, running + prestige_delta)

	if season == GameState.Season.SPRING:
		_census(map, cfg, house, owned)
	for province: ProvinceState in owned:
		province.occupied_rounds = maxi(0, province.occupied_rounds - 1)


static func _income(
	state: GameState,
	map: MapData,
	cfg: EconomyConfig,
	house: HouseState,
	owned: Array[ProvinceState]
) -> float:
	var modifiers := cfg.houses[house.id]
	var is_autumn := state.season() == GameState.Season.AUTUMN
	var total := 0.0
	for province: ProvinceState in owned:
		if province.in_revolt:
			continue
		var def := map.provinces[province.id]
		var rate := IncomeRules.effective_tax_rate(house.tax_rate, def.tax_cap)
		total += IncomeRules.tax(cfg, province.population, rate, province.satisfaction)
		total += IncomeRules.market(
			cfg,
			province.population,
			market_level(cfg, province),
			modifiers.market_multiplier,
			is_autumn,
			province.satisfaction
		)
		total += def.fixed_income
		for id: String in province.buildings:
			var multiplier: float = modifiers.building_income.get(id, 1.0)
			total += IncomeRules.building_income(
				cfg.buildings[id], multiplier, not def.river.is_empty(), def.has_pass
			)
	return total


static func _upkeep(
	state: GameState, cfg: EconomyConfig, house: HouseState, owned: Array[ProvinceState]
) -> float:
	var total := 0.0
	for army: ArmyState in state.armies_of(house.id):
		var siege := cfg.siege_upkeep_multiplier if state.is_besieging(army) else 1.0
		total += IncomeRules.unit_upkeep(cfg, army.units) * siege
	for province: ProvinceState in owned:
		var is_home := province.id == house.home_province
		total += IncomeRules.castle_upkeep(cfg, province.castle_level, is_home)
		for id: String in province.buildings:
			total += cfg.buildings[id].upkeep
	return total


static func _desert(state: GameState, cfg: EconomyConfig, house: HouseState) -> void:
	for army: ArmyState in state.armies_of(house.id):
		for _i: int in IncomeRules.deserters(cfg, army.units.size()):
			var index := army.units.size() - 1
			for j: int in army.units.size():
				if cfg.units[army.units[j]].is_mercenary:
					index = j
					break
			army.remove_company(index)
		if army.company_count() == 0:
			state.remove_army(army)


static func _harvest(
	state: GameState, map: MapData, cfg: EconomyConfig, owned: Array[ProvinceState]
) -> float:
	var total := 0.0
	for province: ProvinceState in owned:
		var def := map.provinces[province.id]
		var harvest := GrainRules.harvest(
			cfg,
			province.population,
			map.terrains[def.terrain].field_yield,
			state.weather[def.region],
			building_sum(cfg, [province], "harvest_bonus"),
			province.occupied_rounds > 0 or province.in_revolt
		)
		total += harvest * (1.0 + state.events.harvest.get(province.id, 0.0))
	return total


static func _grain_demand(
	state: GameState, cfg: EconomyConfig, house: HouseState, owned: Array[ProvinceState]
) -> float:
	var population := 0.0
	for province: ProvinceState in owned:
		population += province.population
	var troops := 0.0
	var is_winter := state.season() == GameState.Season.WINTER
	for army: ArmyState in state.armies_of(house.id):
		var abroad := is_winter and state.provinces[army.province].owner != house.id
		for id: String in army.units:
			troops += GrainRules.troop_grain(cfg, cfg.units[id].upkeep_grain, abroad)
	var extra: float = state.events.grain_demand.get(house.id, 0.0)
	return GrainRules.demand(population, house.ration, troops) * (1.0 + extra)


static func _target_satisfaction(
	map: MapData, cfg: EconomyConfig, house: HouseState, province: ProvinceState
) -> float:
	var def := map.provinces[province.id]
	var is_home := province.id == house.home_province
	var bonus := building_sum(cfg, [province], "satisfaction") + def.satisfaction_bonus
	if is_home:
		for id: String in house.decorations:
			bonus += cfg.decorations[id].satisfaction
	return PopulationRules.target_satisfaction(
		cfg,
		IncomeRules.effective_tax_rate(house.tax_rate, def.tax_cap),
		house.ration,
		bonus,
		house.prestige,
		province.castle_level if is_home else 0,
		province.occupied_rounds > 0,
		house.is_banned
	)


static func _running_prestige(
	cfg: EconomyConfig, house: HouseState, owned: Array[ProvinceState]
) -> float:
	var total := building_sum(cfg, owned, "prestige")
	var home := owned.filter(
		func(province: ProvinceState) -> bool: return province.id == house.home_province
	)
	if not home.is_empty():
		var level: int = (home[0] as ProvinceState).castle_level
		if cfg.home_castle.has(level):
			total += cfg.home_castle[level].prestige
	for id: String in house.decorations:
		total += cfg.decorations[id].prestige
	return total


static func _census(
	map: MapData, cfg: EconomyConfig, house: HouseState, owned: Array[ProvinceState]
) -> void:
	for province: ProvinceState in owned:
		var growth := PopulationRules.growth_rate(
			cfg,
			province.satisfaction,
			house.ration,
			building_sum(cfg, [province], "growth"),
			0.0
		)
		var limit := PopulationRules.capacity(
			cfg,
			map.provinces[province.id].population,
			province.castle_level,
			market_level(cfg, province)
		)
		province.population = PopulationRules.next_population(province.population, growth, limit)


## Highest market level among the province's finished buildings (0 without a market).
static func market_level(cfg: EconomyConfig, province: ProvinceState) -> int:
	var level := 0
	for id: String in province.buildings:
		level = maxi(level, cfg.buildings[id].market_level)
	return level


## Sum of a BuildingDef property over the finished buildings of the provinces.
static func building_sum(
	cfg: EconomyConfig, provinces: Array[ProvinceState], property: StringName
) -> float:
	var total := 0.0
	for province: ProvinceState in provinces:
		for id: String in province.buildings:
			total += float(cfg.buildings[id].get(property))
	return total
