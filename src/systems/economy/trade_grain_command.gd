class_name TradeGrainCommand
extends Command
## Buys (positive bushels) or sells (negative) grain at the current price plus or minus the
## house's spread; every trade then moves the price for the rest of the round.

const ERROR_INVALID_AMOUNT := "TURN_INVALID_AMOUNT"
const ERROR_NOT_ENOUGH_GRAIN := "TURN_NOT_ENOUGH_GRAIN"

var bushels: int
var _config: EconomyConfig


func _init(config: EconomyConfig, house_id: String, amount: int) -> void:
	_config = config
	house = house_id
	bushels = amount


static func current_price(state: GameState, cfg: EconomyConfig) -> float:
	var base := GrainRules.price(cfg, state.autumn_grain_price, state.rounds_since_autumn())
	return GrainRules.price_after_trade(cfg, base, state.grain_traded, 0.0)


func validate(state: GameState) -> String:
	var error := super(state)
	if not error.is_empty():
		return error
	if bushels == 0:
		return ERROR_INVALID_AMOUNT
	if bushels < 0:
		return "" if state.houses[house].grain >= -bushels else ERROR_NOT_ENOUGH_GRAIN
	return gold_error(state, _value(state))


func apply(state: GameState) -> void:
	var owner := state.houses[house]
	var value := _value(state)
	owner.gold += value if bushels < 0 else -value
	owner.grain += bushels
	state.grain_traded += bushels


## Taler the trade costs (buying) or earns (selling).
func _value(state: GameState) -> float:
	var price := current_price(state, _config)
	var spread := _config.houses[house].grain_spread
	if bushels > 0:
		return bushels * GrainRules.buy_price(price, spread)
	return -bushels * GrainRules.sell_price(price, spread)
