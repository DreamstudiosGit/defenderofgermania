class_name UpgradeCastleCommand
extends Command
## Orders the next castle level in an own province: the home castle table in the home
## province (levels 2–5), the province castle table elsewhere (levels 1–3).

const ERROR_MAX_LEVEL := "TURN_CASTLE_MAX_LEVEL"
const ERROR_UNDER_CONSTRUCTION := "TURN_CASTLE_UNDER_CONSTRUCTION"
const ERROR_PREREQUISITE := "TURN_PREREQUISITE_MISSING"

var province: String
var _config: EconomyConfig


func _init(config: EconomyConfig, house_id: String, province_id: String) -> void:
	_config = config
	house = house_id
	province = province_id


func validate(state: GameState) -> String:
	var error := super(state)
	if error.is_empty():
		error = owned_province_error(state, province)
	if error.is_empty():
		error = _check_level(state)
	if error.is_empty():
		error = gold_error(state, _cost(state))
	return error


func apply(state: GameState) -> void:
	state.houses[house].gold -= _cost(state)
	var rounds := _next_level(state).build_rounds
	var construction := ConstructionState.create(ConstructionState.CASTLE, rounds)
	state.provinces[province].constructions.append(construction)


func _check_level(state: GameState) -> String:
	if state.provinces[province].has_project(ConstructionState.CASTLE):
		return ERROR_UNDER_CONSTRUCTION
	var level := _next_level(state)
	if level == null:
		return ERROR_MAX_LEVEL
	return "" if state.home_castle_level(house) >= level.home_castle else ERROR_PREREQUISITE


func _next_level(state: GameState) -> CastleLevelDef:
	var table := BuildingRules.castle_table(state, _config, house, province)
	return table.get(state.provinces[province].castle_level + 1)


func _cost(state: GameState) -> float:
	return BuildingRules.castle_cost(state, _config, house, _next_level(state))
