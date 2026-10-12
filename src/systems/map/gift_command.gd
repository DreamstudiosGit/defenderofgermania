class_name GiftCommand
extends Command
## A gift to an elector or a neutral lord: taler for favour; each further gift to the same lord
## within a year brings less (CrownRules.gift_favour).

const ERROR_NO_FAVOUR_LIST := "CROWN_NO_FAVOUR_LIST"

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
	if not state.crown.has_favour_list(province, house):
		return ERROR_NO_FAVOUR_LIST
	return gold_error(state, CrownRules.gift_cost(_map, house))


func apply(state: GameState) -> void:
	state.houses[house].gold -= CrownRules.gift_cost(_map, house)
	var gain := CrownRules.gift_favour(state, _map, province, house)
	CrownRules.change_favour(state, _map, province, house, gain)
	var key := CrownState.key(province, house)
	state.crown.gifts[key] = state.crown.gifts.get(key, 0) + 1
