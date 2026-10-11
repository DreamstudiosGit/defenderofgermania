class_name RecruitCommand
extends Command
## Recruits one company in an own province with a castle. It joins the given army there, or
## with AUTO_ARMY the first own army there with room, or else forms a new army.

const AUTO_ARMY := -1
const ERROR_UNKNOWN_UNIT := "TURN_UNKNOWN_UNIT"
const ERROR_NO_CASTLE := "TURN_NO_CASTLE"
const ERROR_UNIT_LOCKED := "TURN_UNIT_LOCKED"
const ERROR_RECRUIT_LIMIT := "TURN_RECRUIT_LIMIT"
const ERROR_ENEMY_PRESENT := "TURN_ENEMY_PRESENT"
const ERROR_NO_ARMY_ROOM := "TURN_NO_ARMY_ROOM"

var province: String
var unit: String
var army_id: int
var _config: EconomyConfig
var _map: MapData


func _init(
	config: EconomyConfig,
	map: MapData,
	house_id: String,
	province_id: String,
	unit_id: String,
	target_army: int = AUTO_ARMY
) -> void:
	_config = config
	_map = map
	house = house_id
	province = province_id
	unit = unit_id
	army_id = target_army


func validate(state: GameState) -> String:
	var error := super(state)
	if error.is_empty():
		error = owned_province_error(state, province)
	if error.is_empty():
		error = _check_unit(state)
	if error.is_empty():
		error = _check_province(state)
	if error.is_empty():
		error = _check_army(state)
	if error.is_empty():
		error = gold_error(state, _cost())
	return error


func apply(state: GameState) -> void:
	var target := state.provinces[province]
	state.houses[house].gold -= _cost()
	target.population = maxf(0.0, target.population - _config.units[unit].population)
	target.satisfaction = maxf(0.0, target.satisfaction - _config.recruit_satisfaction_cost)
	target.recruits_left -= 1
	var army := _target_army(state)
	if army == null:
		army = state.add_army(house, province)
	army.add_company(unit)


func _cost() -> float:
	var multiplier: float = _config.houses[house].unit_cost.get(unit, 1.0)
	return _config.units[unit].cost * multiplier


func _check_unit(state: GameState) -> String:
	if not _config.units.has(unit):
		return ERROR_UNKNOWN_UNIT
	var def := _config.units[unit]
	if state.home_castle_level(house) < def.home_castle:
		return ERROR_UNIT_LOCKED
	var has_building := def.requires.is_empty() or def.requires in state.provinces[province].buildings
	return "" if has_building else ERROR_UNIT_LOCKED


func _check_province(state: GameState) -> String:
	var target := state.provinces[province]
	if target.castle_level < 1:
		return ERROR_NO_CASTLE
	if target.recruits_left <= 0:
		return ERROR_RECRUIT_LIMIT
	return ERROR_ENEMY_PRESENT if Movement.has_hostile_army(state, province, house) else ""


func _check_army(state: GameState) -> String:
	if _target_army(state) != null:
		return ""
	if army_id != AUTO_ARMY:
		return ERROR_NO_ARMY_ROOM
	var limit := _map.campaign.max_armies(state.home_castle_level(house))
	return "" if state.armies_of(house).size() < limit else ERROR_NO_ARMY_ROOM


func _target_army(state: GameState) -> ArmyState:
	for army: ArmyState in state.armies_in(province):
		var wanted := army_id == AUTO_ARMY or army.id == army_id
		if wanted and army.owner == house and _has_room(state, army):
			return army
	return null


func _has_room(state: GameState, army: ArmyState) -> bool:
	var owner := state.houses[house]
	var has_leader := owner.leader_army == army.id
	return army.company_count() < _map.campaign.max_companies(has_leader, owner.leadership)
