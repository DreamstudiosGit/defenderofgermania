class_name HomageCommand
extends Command
## A neutral secular lord whose favour reached the threshold pays homage: his province joins
## the house for taler, without a fight. Electors and church land never pay homage.

const ERROR_NOT_NEUTRAL := "CROWN_HOMAGE_NOT_NEUTRAL"
const ERROR_FAVOUR := "CROWN_HOMAGE_FAVOUR"

var province: String
var _map: MapData


func _init(map: MapData, house_id: String, province_id: String) -> void:
	_map = map
	house = house_id
	province = province_id


func validate(state: GameState) -> String:
	var error := super(state)
	if not error.is_empty():
		return error
	if not state.provinces.has(province):
		return ERROR_UNKNOWN_PROVINCE
	var def := _map.provinces[province]
	var is_secular_lord := def.owner == CrownRules.NEUTRAL and not def.is_church
	if not is_secular_lord or state.provinces[province].owner != CrownRules.NEUTRAL:
		return ERROR_NOT_NEUTRAL
	if state.crown.favour_of(province, house) < _map.crown.homage_threshold:
		return ERROR_FAVOUR
	return gold_error(state, _map.crown.homage_cost)


func apply(state: GameState) -> void:
	state.houses[house].gold -= _map.crown.homage_cost
	CrownRules.pay_homage(state, province, house)
