class_name BuildCommand
extends Command
## Orders a building in an own province: paid now, finished after its build time.

const ERROR_UNKNOWN_BUILDING := "TURN_UNKNOWN_BUILDING"
const ERROR_ALREADY_BUILT := "TURN_ALREADY_BUILT"
const ERROR_NO_SLOT := "TURN_NO_FREE_SLOT"
const ERROR_PREREQUISITE := "TURN_PREREQUISITE_MISSING"

var province: String
var building: String
var _config: EconomyConfig
var _map: MapData


func _init(
	config: EconomyConfig, map: MapData, house_id: String, province_id: String, building_id: String
) -> void:
	_config = config
	_map = map
	house = house_id
	province = province_id
	building = building_id


func validate(state: GameState) -> String:
	var error := super(state)
	if error.is_empty():
		error = owned_province_error(state, province)
	if error.is_empty():
		error = _check_building(state)
	if error.is_empty():
		error = gold_error(state, BuildingRules.building_cost(_config, house, building))
	return error


func apply(state: GameState) -> void:
	state.houses[house].gold -= BuildingRules.building_cost(_config, house, building)
	var rounds := _config.buildings[building].build_rounds
	state.provinces[province].constructions.append(ConstructionState.create(building, rounds))


func _check_building(state: GameState) -> String:
	if not _config.buildings.has(building):
		return ERROR_UNKNOWN_BUILDING
	var target := state.provinces[province]
	if BuildingRules.is_present(_config, target, building):
		return ERROR_ALREADY_BUILT
	var def := _config.buildings[building]
	var is_home := BuildingRules.is_home(state, house, province)
	var castle := state.home_castle_level(house)
	if not BuildingRules.meets_prerequisites(def, _map.provinces[province], target, is_home, castle):
		return ERROR_PREREQUISITE
	var free := (
		BuildingRules.slots(_config, is_home, castle) - BuildingRules.used_slots(_config, target)
	)
	return "" if free > 0 or not def.upgrade_of.is_empty() else ERROR_NO_SLOT
