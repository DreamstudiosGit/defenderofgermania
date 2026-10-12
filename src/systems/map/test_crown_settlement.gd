extends GutTest
## Favour every round: + prestige ÷ 50 (Wittelsbacher × 1.5), + 1 with every elector from the
## imperial palace, then one point back towards 30; gifts are forgotten when a year ends.

var _map: MapData
var _state: GameState


func before_all() -> void:
	_map = MapData.load_file()


func before_each() -> void:
	_state = GameSetup.create(_map, EconomyConfig.load_file(), 1)


func test_favour_grows_with_prestige_and_drifts_towards_thirty() -> void:
	CrownSettlement.settle(_state, _map)
	assert_almost_eq(_state.crown.favour_of("KOE", "welfen"), 54.4, 1e-9, "55 + 20/50 − 1")
	assert_almost_eq(_state.crown.favour_of("BOH", "wittelsbacher"), 39.6, 1e-9, "40 + 0.6 − 1")
	assert_almost_eq(_state.crown.favour_of("TRI", "staufer"), 30.0, 1e-9, "30.4 drifts to 30")
	_state.crown.set_favour("TRI", "staufer", 10.0, 100.0)
	CrownSettlement.settle(_state, _map)
	assert_almost_eq(_state.crown.favour_of("TRI", "staufer"), 11.4, 1e-9, "from below too")


func test_the_imperial_palace_courts_every_elector() -> void:
	_state.provinces["BSW"].castle_level = 5
	CrownSettlement.settle(_state, _map)
	assert_almost_eq(_state.crown.favour_of("KOE", "welfen"), 55.4, 1e-9, "55 + 0.4 + 1 − 1")
	assert_almost_eq(_state.crown.favour_of("ELS", "welfen"), 30.0, 1e-9, "not neutral lords")


func test_gifts_are_forgotten_after_winter_only() -> void:
	_state.crown.gifts[CrownState.key("KOE", "welfen")] = 2
	_state.turn = 2
	CrownSettlement.settle(_state, _map)
	assert_false(_state.crown.gifts.is_empty(), "autumn keeps the year's gifts")
	_state.turn = 3
	CrownSettlement.settle(_state, _map)
	assert_true(_state.crown.gifts.is_empty())


func test_eliminated_houses_keep_their_favour_frozen() -> void:
	_state.houses["welfen"].is_eliminated = true
	CrownSettlement.settle(_state, _map)
	assert_eq(_state.crown.favour_of("KOE", "welfen"), 55.0)
