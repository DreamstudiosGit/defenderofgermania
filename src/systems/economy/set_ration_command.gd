class_name SetRationCommand
extends Command
## Sets the grain ration a house hands out per population unit and year.

const ERROR_INVALID_RATION := "ERROR_INVALID_RATION"

var ration: int
var _config: EconomyConfig


func _init(config: EconomyConfig, house_id: String, value: int) -> void:
	_config = config
	house = house_id
	ration = value


func validate(state: GameState) -> String:
	var error := super(state)
	if not error.is_empty():
		return error
	return "" if ration in _config.rations else ERROR_INVALID_RATION


func apply(state: GameState) -> void:
	state.houses[house].ration = ration
