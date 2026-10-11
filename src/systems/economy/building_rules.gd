class_name BuildingRules
extends RefCounted
## Building slots, prerequisites and costs (docs/design/economy.md, "Building and castles")
## and the construction queue, which finishes orders at the end of settlement.


static func is_home(state: GameState, house: String, province_id: String) -> bool:
	return state.houses[house].home_province == province_id


static func slots(cfg: EconomyConfig, is_home_province: bool, home_castle_level: int) -> int:
	if not is_home_province:
		return cfg.slots_per_province
	var extra := cfg.slots_per_home_castle_level * maxi(home_castle_level - 1, 0)
	return mini(cfg.slots_per_province + extra, cfg.slots_max)


## Buildings standing or under construction; upgrades reuse the slot of what they replace.
static func used_slots(cfg: EconomyConfig, province: ProvinceState) -> int:
	var used := province.buildings.size()
	for construction: ConstructionState in province.constructions:
		var project := construction.project
		if project != ConstructionState.CASTLE and cfg.buildings[project].upgrade_of.is_empty():
			used += 1
	return used


## True if the building stands, is under construction, or an upgrade of it stands.
static func is_present(cfg: EconomyConfig, province: ProvinceState, building_id: String) -> bool:
	if building_id in province.buildings or province.has_project(building_id):
		return true
	for id: String in province.buildings:
		if cfg.buildings[id].upgrade_of == building_id:
			return true
	return false


## True if the province meets the building's map, building and castle requirements.
static func meets_prerequisites(
	building: BuildingDef,
	def: MapData.ProvinceDef,
	province: ProvinceState,
	is_home_province: bool,
	home_castle_level: int
) -> bool:
	if building.is_home_only and not is_home_province:
		return false
	if home_castle_level < building.home_castle:
		return false
	if not building.upgrade_of.is_empty() and building.upgrade_of not in province.buildings:
		return false
	if building.features.is_empty():
		return true
	return building.features.any(func(feature: String) -> bool: return def.has_feature(feature))


static func building_cost(cfg: EconomyConfig, house: String, building_id: String) -> float:
	var multiplier: float = cfg.houses[house].building_cost.get(building_id, 1.0)
	return cfg.buildings[building_id].cost * multiplier


## Cost of a castle level for the house; each kind of building it owns that cheapens castle
## construction (the workshop) counts once, even if conquest brought it a second one.
static func castle_cost(
	state: GameState, cfg: EconomyConfig, house: String, level: CastleLevelDef
) -> float:
	var kinds: Array[String] = []
	for province: ProvinceState in state.provinces_of(house):
		for id: String in province.buildings:
			if id not in kinds:
				kinds.append(id)
	var cost := level.cost
	for id: String in kinds:
		cost *= cfg.buildings[id].castle_cost_multiplier
	return cost


## The castle table that applies to a province of the house.
static func castle_table(
	state: GameState, cfg: EconomyConfig, house: String, province_id: String
) -> Dictionary[int, CastleLevelDef]:
	return cfg.home_castle if is_home(state, house, province_id) else cfg.province_castle


## Counts every construction down by one round and finishes those that are done.
static func advance(state: GameState, cfg: EconomyConfig) -> void:
	for province: ProvinceState in state.provinces.values():
		var running: Array[ConstructionState] = []
		for construction: ConstructionState in province.constructions:
			construction.rounds_left -= 1
			if construction.rounds_left > 0:
				running.append(construction)
			else:
				_finish(cfg, province, construction.project)
		province.constructions = running


static func _finish(cfg: EconomyConfig, province: ProvinceState, project: String) -> void:
	if project == ConstructionState.CASTLE:
		province.castle_level += 1
		return
	province.buildings.erase(cfg.buildings[project].upgrade_of)
	province.buildings.append(project)
