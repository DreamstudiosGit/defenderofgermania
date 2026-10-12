class_name GameSetup
extends RefCounted
## Builds the starting GameState of a new game from the static data and a seed and starts
## the first round.


static func create(map: MapData, economy: EconomyConfig, seed_value: int) -> GameState:
	var state := GameState.new()
	state.rng.seed = seed_value
	state.autumn_grain_price = economy.base_grain_price
	for def: MapData.ProvinceDef in map.provinces.values():
		var province := ProvinceState.new()
		province.id = def.id
		province.owner = def.owner
		province.population = def.population
		province.satisfaction = economy.start_satisfaction
		province.castle_level = def.castle_level
		province.buildings = def.buildings.duplicate()
		province.recruits_left = PopulationRules.recruit_limit(economy, def.population)
		state.provinces[def.id] = province
	for id: String in map.houses:
		var house := HouseState.new()
		house.id = id
		house.gold = economy.start_gold
		house.grain = economy.start_grain
		house.prestige = economy.start_prestige
		house.tax_rate = economy.start_tax_rate
		house.ration = economy.start_ration
		house.home_province = map.home_province(id)
		var skills := map.campaign.roll_leader(id, state.rng)
		house.leadership = skills["leadership"]
		house.lance = skills["lance"]
		house.blade = skills["blade"]
		state.houses[id] = house
		var army := state.add_army(id, house.home_province)
		for unit: String in map.start_army:
			army.add_company(unit)
		house.leader_army = army.id
	_setup_crown(state, map)
	TurnLoop.start_round(state)
	return state


static func _setup_crown(state: GameState, map: MapData) -> void:
	var crown := state.crown
	for def: MapData.ProvinceDef in map.provinces.values():
		if "imperial_regalia" in def.tags:
			crown.regalia_province = def.id
		if def.owner not in ["elector", "neutral"]:
			continue
		for house: String in map.houses:
			crown.set_favour(def.id, house, map.start_favour(def.id, house), map.crown.favour_max)
	for house: String in map.houses:
		crown.patron_cards[house] = map.crown.patron_cards
	for patron: String in map.crown.camp_patrons.values():
		crown.patron_strength[patron] = 1.0
