extends GutTest
## Building orders: costs, slots, prerequisites and the construction queue.

var _map: MapData
var _cfg: EconomyConfig
var _state: GameState


func before_all() -> void:
	_map = MapData.load_file()


func before_each() -> void:
	_cfg = EconomyConfig.load_file()
	_state = GameSetup.create(_map, _cfg, 1)


func test_building_is_paid_now_and_finished_at_settlement() -> void:
	_activate("welfen")
	assert_eq(_build("welfen", "HOL", "granary"), "")
	assert_eq(_state.houses["welfen"].gold, 200.0 - 70.0)
	assert_false("granary" in _state.provinces["HOL"].buildings)
	EconomySettlement.settle(_state, _map, _cfg)
	assert_true("granary" in _state.provinces["HOL"].buildings)
	assert_true(_state.provinces["HOL"].constructions.is_empty())


func test_two_round_building_needs_two_settlements() -> void:
	_activate("welfen")
	assert_eq(_build("welfen", "HOL", "monastery"), "")
	EconomySettlement.settle(_state, _map, _cfg)
	assert_false("monastery" in _state.provinces["HOL"].buildings)
	EconomySettlement.settle(_state, _map, _cfg)
	assert_true("monastery" in _state.provinces["HOL"].buildings)


func test_a_building_stands_once_per_province() -> void:
	_activate("welfen")
	assert_eq(_build("welfen", "HOL", "granary"), "")
	assert_eq(_build("welfen", "HOL", "granary"), BuildCommand.ERROR_ALREADY_BUILT)
	assert_eq(_build("welfen", "BSW", "mill"), BuildCommand.ERROR_ALREADY_BUILT)


func test_a_province_has_two_slots() -> void:
	_activate("welfen")
	_state.houses["welfen"].gold = 1000.0
	assert_eq(_build("welfen", "HOL", "granary"), "")
	assert_eq(_build("welfen", "HOL", "mill"), BuildCommand.ERROR_NO_SLOT)


func test_home_province_gains_a_slot_per_castle_level_up_to_six() -> void:
	assert_eq(BuildingRules.slots(_cfg, true, 1), 2)
	assert_eq(BuildingRules.slots(_cfg, true, 3), 4)
	assert_eq(BuildingRules.slots(_cfg, true, 5), 6)
	assert_eq(BuildingRules.slots(_cfg, true, 9), 6)
	assert_eq(BuildingRules.slots(_cfg, false, 5), 2)


func test_higher_home_castle_opens_slots_in_the_home_province() -> void:
	_activate("welfen")
	_state.houses["welfen"].gold = 1000.0
	assert_eq(_build("welfen", "BSW", "granary"), "")
	assert_eq(_build("welfen", "BSW", "monastery"), BuildCommand.ERROR_NO_SLOT)
	_state.provinces["BSW"].castle_level = 2
	assert_eq(_build("welfen", "BSW", "monastery"), "")


func test_market_two_needs_market_one_and_home_castle_two() -> void:
	_activate("welfen")
	_state.houses["welfen"].gold = 1000.0
	assert_eq(_build("welfen", "HOL", "market_2"), BuildCommand.ERROR_PREREQUISITE)
	_state.provinces["BSW"].castle_level = 2
	assert_eq(_build("welfen", "BSW", "market_2"), BuildCommand.ERROR_PREREQUISITE)
	assert_eq(_build("welfen", "HOL", "market_2"), "")
	assert_eq(_state.houses["welfen"].gold, 1000.0 - 250.0)


func test_market_two_replaces_market_one_in_its_slot() -> void:
	_activate("welfen")
	_state.houses["welfen"].gold = 1000.0
	_state.provinces["BSW"].castle_level = 2
	assert_eq(_build("welfen", "HOL", "granary"), "")
	assert_eq(_build("welfen", "HOL", "market_2"), "")
	EconomySettlement.settle(_state, _map, _cfg)
	EconomySettlement.settle(_state, _map, _cfg)
	assert_eq_deep(_state.provinces["HOL"].buildings, ["granary", "market_2"] as Array[String])
	_activate("welfen")
	assert_eq(_build("welfen", "HOL", "market_1"), BuildCommand.ERROR_ALREADY_BUILT)


func test_mine_needs_ore_and_costs_wettiner_less() -> void:
	_activate("wettiner")
	assert_eq(_build("wettiner", "THU", "mine"), BuildCommand.ERROR_PREREQUISITE)
	assert_eq(_build("wettiner", "MEI", "mine"), "")
	assert_almost_eq(_state.houses["wettiner"].gold, 200.0 - 140.0, 1e-9)


func test_toll_needs_river_or_pass() -> void:
	_activate("wettiner")
	assert_eq(_build("wettiner", "THU", "toll"), BuildCommand.ERROR_PREREQUISITE)
	assert_eq(_build("wettiner", "MEI", "toll"), "")


func test_workshop_needs_home_province_and_home_castle_four() -> void:
	_activate("welfen")
	_state.houses["welfen"].gold = 1000.0
	assert_eq(_build("welfen", "BSW", "workshop"), BuildCommand.ERROR_PREREQUISITE)
	_state.provinces["BSW"].castle_level = 4
	assert_eq(_build("welfen", "HOL", "workshop"), BuildCommand.ERROR_PREREQUISITE)
	assert_eq(_build("welfen", "BSW", "workshop"), "")


func test_tourney_ground_needs_home_province_and_home_castle_three() -> void:
	_activate("welfen")
	_state.houses["welfen"].gold = 1000.0
	assert_eq(_build("welfen", "BSW", "tourney_ground"), BuildCommand.ERROR_PREREQUISITE)
	_state.provinces["BSW"].castle_level = 3
	assert_eq(_build("welfen", "HOL", "tourney_ground"), BuildCommand.ERROR_PREREQUISITE)
	assert_eq(_build("welfen", "BSW", "tourney_ground"), "")
	assert_eq(_state.houses["welfen"].gold, 1000.0 - 120.0)


func test_building_needs_an_own_province_and_gold() -> void:
	_activate("welfen")
	assert_eq(_build("welfen", "HOL", "joust_arena"), BuildCommand.ERROR_UNKNOWN_BUILDING)
	assert_eq(_build("welfen", "BRM", "mill"), Command.ERROR_NOT_OWNER)
	assert_eq(_build("welfen", "XXX", "mill"), Command.ERROR_UNKNOWN_PROVINCE)
	_state.houses["welfen"].gold = 10.0
	assert_eq(_build("welfen", "HOL", "mill"), Command.ERROR_NOT_ENOUGH_GOLD)
	assert_true(_state.provinces["HOL"].constructions.is_empty())


func _build(house: String, province: String, building: String) -> String:
	return BuildCommand.new(_cfg, _map, house, province, building).execute(_state)


func _activate(house: String) -> void:
	_state.active_index = _state.turn_order.find(house)
	_state.phase = GameState.Phase.ADMINISTRATION
