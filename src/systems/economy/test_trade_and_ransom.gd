extends GutTest
## Grain trade at the round's price and the ransom for a captured leader.

const EPSILON := 1e-9

var _map: MapData
var _cfg: EconomyConfig
var _state: GameState


func before_all() -> void:
	_map = MapData.load_file()


func before_each() -> void:
	_cfg = EconomyConfig.load_file()
	_state = GameSetup.create(_map, _cfg, 1)


func test_buying_pays_price_plus_spread_and_raises_the_price() -> void:
	_activate("wittelsbacher")
	# First spring: 0.5 last autumn, two rounds later 0.6.
	assert_almost_eq(TradeGrainCommand.current_price(_state, _cfg), 0.6, EPSILON)
	assert_eq(_trade("wittelsbacher", 100), "")
	var house := _state.houses["wittelsbacher"]
	assert_almost_eq(house.gold, 200.0 - 100.0 * 0.72, EPSILON)
	assert_eq(house.grain, 400.0)
	assert_almost_eq(TradeGrainCommand.current_price(_state, _cfg), 0.612, EPSILON)


func test_selling_earns_price_minus_spread_and_lowers_the_price() -> void:
	_activate("wittelsbacher")
	assert_eq(_trade("wittelsbacher", -100), "")
	var house := _state.houses["wittelsbacher"]
	assert_almost_eq(house.gold, 200.0 + 100.0 * 0.48, EPSILON)
	assert_eq(house.grain, 200.0)
	assert_almost_eq(TradeGrainCommand.current_price(_state, _cfg), 0.588, EPSILON)


func test_welfen_trade_with_half_the_spread() -> void:
	_activate("welfen")
	assert_eq(_trade("welfen", 100), "")
	assert_almost_eq(_state.houses["welfen"].gold, 200.0 - 100.0 * 0.66, EPSILON)


func test_trades_of_all_houses_move_the_price_until_settlement() -> void:
	_activate("welfen")
	_trade("welfen", 100)
	_activate("staufer")
	assert_almost_eq(TradeGrainCommand.current_price(_state, _cfg), 0.612, EPSILON)
	EconomySettlement.settle(_state, _map, _cfg)
	assert_eq(_state.grain_traded, 0.0)


func test_price_stays_within_bounds() -> void:
	_state.grain_traded = 100000.0
	assert_eq(TradeGrainCommand.current_price(_state, _cfg), _cfg.price_max)
	_state.grain_traded = -100000.0
	assert_eq(TradeGrainCommand.current_price(_state, _cfg), _cfg.price_min)


func test_invalid_trades_are_rejected() -> void:
	_activate("staufer")
	assert_eq(_trade("staufer", 0), TradeGrainCommand.ERROR_INVALID_AMOUNT)
	assert_eq(_trade("staufer", -301), TradeGrainCommand.ERROR_NOT_ENOUGH_GRAIN)
	assert_eq(_trade("staufer", 1000), Command.ERROR_NOT_ENOUGH_GOLD)
	assert_eq(_state.houses["staufer"].grain, 300.0)
	assert_eq(_state.grain_traded, 0.0)


func test_ransom_frees_the_leader_and_pays_the_captor() -> void:
	_activate("welfen")
	_capture("welfen", "staufer")
	assert_eq(PayRansomCommand.new(_cfg, "welfen").execute(_state), "")
	var house := _state.houses["welfen"]
	assert_eq(house.gold, 200.0 - 200.0)
	assert_eq(_state.houses["staufer"].gold, 200.0 + 200.0)
	assert_false(house.is_leader_captured())
	assert_eq(house.leader_army, HouseState.NO_ARMY)


func test_ransom_grows_with_the_home_castle() -> void:
	_state.provinces["BSW"].castle_level = 3
	assert_eq(PayRansomCommand.ransom(_state, _cfg, "welfen"), 300.0)


func test_ransom_to_a_neutral_captor_is_just_paid() -> void:
	_activate("welfen")
	_capture("welfen", "neutral")
	assert_eq(PayRansomCommand.new(_cfg, "welfen").execute(_state), "")
	assert_eq(_state.houses["welfen"].gold, 0.0)


func test_ransom_needs_a_captured_leader_and_the_gold() -> void:
	_activate("welfen")
	var error := PayRansomCommand.new(_cfg, "welfen").execute(_state)
	assert_eq(error, PayRansomCommand.ERROR_NOT_CAPTURED)
	_capture("welfen", "staufer")
	_state.houses["welfen"].gold = 100.0
	assert_eq(PayRansomCommand.new(_cfg, "welfen").execute(_state), Command.ERROR_NOT_ENOUGH_GOLD)


func _trade(house: String, bushels: int) -> String:
	return TradeGrainCommand.new(_cfg, house, bushels).execute(_state)


func _capture(house: String, captor: String) -> void:
	_state.houses[house].leader_captor = captor
	_state.houses[house].leader_army = HouseState.NO_ARMY


func _activate(house: String) -> void:
	_state.active_index = _state.turn_order.find(house)
	_state.phase = GameState.Phase.ADMINISTRATION
