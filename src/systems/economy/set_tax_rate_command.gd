class_name SetTaxRateCommand
extends Command
## Sets the tax rate a house collects in all its provinces.

const ERROR_INVALID_TAX_RATE := "ERROR_INVALID_TAX_RATE"

var tax_rate: int
var _config: EconomyConfig


func _init(config: EconomyConfig, house_id: String, rate: int) -> void:
	_config = config
	house = house_id
	tax_rate = rate


func validate(state: GameState) -> String:
	var error := super(state)
	if not error.is_empty():
		return error
	return "" if tax_rate in _config.tax_rates else ERROR_INVALID_TAX_RATE


func apply(state: GameState) -> void:
	state.houses[house].tax_rate = tax_rate
