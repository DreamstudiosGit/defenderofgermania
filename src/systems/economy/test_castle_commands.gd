extends GutTest
## Castle upgrades and home castle decorations.

var _map: MapData
var _cfg: EconomyConfig
var _state: GameState


func before_all() -> void:
	_map = MapData.load_file()


func before_each() -> void:
	_cfg = EconomyConfig.load_file()
	_state = GameSetup.create(_map, _cfg, 1)
	_activate("welfen")
	_state.houses["welfen"].gold = 2000.0


func test_home_castle_upgrade_takes_its_build_time() -> void:
	assert_eq(_upgrade("BSW"), "")
	assert_eq(_state.houses["welfen"].gold, 2000.0 - 300.0)
	EconomySettlement.settle(_state, _map, _cfg)
	assert_eq(_state.provinces["BSW"].castle_level, 1)
	EconomySettlement.settle(_state, _map, _cfg)
	assert_eq(_state.provinces["BSW"].castle_level, 2)


func test_one_castle_upgrade_at_a_time() -> void:
	assert_eq(_upgrade("BSW"), "")
	assert_eq(_upgrade("BSW"), UpgradeCastleCommand.ERROR_UNDER_CONSTRUCTION)


func test_home_castle_stops_at_level_five() -> void:
	_state.provinces["BSW"].castle_level = 5
	assert_eq(_upgrade("BSW"), UpgradeCastleCommand.ERROR_MAX_LEVEL)


func test_workshop_makes_castles_fifteen_percent_cheaper() -> void:
	_state.provinces["BSW"].castle_level = 4
	_state.provinces["BSW"].buildings.append("workshop")
	assert_eq(_upgrade("BSW"), "")
	assert_almost_eq(_state.houses["welfen"].gold, 2000.0 - 1800.0 * 0.85, 1e-9)


func test_province_castle_is_built_from_the_province_table() -> void:
	assert_eq(_upgrade("HOL"), "")
	assert_eq(_state.houses["welfen"].gold, 2000.0 - 80.0)
	EconomySettlement.settle(_state, _map, _cfg)
	assert_eq(_state.provinces["HOL"].castle_level, 1)


func test_fortress_needs_home_castle_three() -> void:
	_activate("wittelsbacher")
	_state.houses["wittelsbacher"].gold = 2000.0
	assert_eq(_upgrade("NUE", "wittelsbacher"), UpgradeCastleCommand.ERROR_PREREQUISITE)
	_state.provinces["BAY"].castle_level = 3
	assert_eq(_upgrade("NUE", "wittelsbacher"), "")
	assert_eq(_state.houses["wittelsbacher"].gold, 2000.0 - 500.0)


func test_castle_upgrade_needs_own_province_and_gold() -> void:
	assert_eq(_upgrade("SPT"), Command.ERROR_NOT_OWNER)
	_state.houses["welfen"].gold = 100.0
	assert_eq(_upgrade("BSW"), Command.ERROR_NOT_ENOUGH_GOLD)


func test_decoration_is_bought_once() -> void:
	assert_eq(_decorate("banners"), "")
	assert_eq(_state.houses["welfen"].gold, 2000.0 - 50.0)
	assert_eq(_decorate("banners"), BuyDecorationCommand.ERROR_ALREADY_OWNED)
	assert_eq(_decorate("dragon"), BuyDecorationCommand.ERROR_UNKNOWN_DECORATION)


func test_stained_glass_needs_home_castle_four() -> void:
	assert_eq(_decorate("stained_glass"), BuyDecorationCommand.ERROR_PREREQUISITE)
	_state.provinces["BSW"].castle_level = 4
	assert_eq(_decorate("stained_glass"), "")


func test_decorations_are_limited() -> void:
	_cfg.decoration_limit = 1
	assert_eq(_decorate("banners"), "")
	assert_eq(_decorate("fountain"), BuyDecorationCommand.ERROR_LIMIT)


func test_decorations_need_the_home_castle() -> void:
	_state.provinces["BSW"].owner = "staufer"
	assert_eq(_decorate("banners"), BuyDecorationCommand.ERROR_PREREQUISITE)


func _upgrade(province: String, house: String = "welfen") -> String:
	return UpgradeCastleCommand.new(_cfg, house, province).execute(_state)


func _decorate(decoration: String) -> String:
	return BuyDecorationCommand.new(_cfg, "welfen", decoration).execute(_state)


func _activate(house: String) -> void:
	_state.active_index = _state.turn_order.find(house)
	_state.phase = GameState.Phase.ADMINISTRATION
