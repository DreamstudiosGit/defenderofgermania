extends GutTest

const EPSILON := 1e-9
const SEED := 1198

var _map: MapData
var _cfg: EconomyConfig
var _state: GameState


func before_all() -> void:
	_map = MapData.load_file()


func before_each() -> void:
	_cfg = EconomyConfig.load_file()
	_state = GameSetup.create(_map, _cfg, SEED)


func test_first_spring_pays_income_minus_upkeep() -> void:
	EconomySettlement.settle(_state, _map, _cfg)
	# Taxes 20.925 + 15.69375, Holstein market 20.25; upkeep 6 army + 2 mill + 2 market.
	assert_almost_eq(_state.houses["welfen"].gold, 200.0 + 56.86875 - 10.0, EPSILON)
	assert_eq(_state.turn, 1)


func test_autumn_harvest_fills_the_granary() -> void:
	_state.turn = GameState.Season.AUTUMN
	EconomySettlement.settle(_state, _map, _cfg)
	var weather: float = _state.weather["north"]
	var harvest := (300.0 + 180.0) * weather
	var expected := (300.0 + harvest - 90.75) * (1.0 - 0.1)
	assert_almost_eq(_state.houses["welfen"].grain, expected, 1e-6)
	assert_eq(_state.weather.size(), 3)


func test_autumn_sets_new_grain_price_from_weather() -> void:
	_state.turn = GameState.Season.AUTUMN
	EconomySettlement.settle(_state, _map, _cfg)
	var mean := 0.0
	for region: String in _map.regions:
		mean += _state.weather[region] / _map.regions.size()
	var price := _state.autumn_grain_price
	assert_between(price, 0.5 / mean * 0.9 - EPSILON, 0.5 / mean * 1.1 + EPSILON)


func test_debt_makes_companies_desert_mercenaries_first() -> void:
	var army := _state.armies_of("welfen")[0]
	army.add_company("brabanters")
	_state.houses["welfen"].gold = -500.0
	EconomySettlement.settle(_state, _map, _cfg)
	assert_eq(army.units.size(), 4)
	assert_false("brabanters" in army.units)


func test_hunger_costs_population_and_prestige() -> void:
	var house := _state.houses["welfen"]
	house.grain = 0.0
	var before := _state.provinces["BSW"].population
	EconomySettlement.settle(_state, _map, _cfg)
	assert_lt(_state.provinces["BSW"].population, before * 0.9 + EPSILON)
	# Decay, motte prestige +0.5, hunger -3.
	assert_almost_eq(house.prestige, 20.0 * 0.95 + 0.5 - 3.0, EPSILON)


func test_spring_census_grows_population() -> void:
	_state.provinces["BSW"].satisfaction = 100.0
	EconomySettlement.settle(_state, _map, _cfg)
	assert_gt(_state.provinces["BSW"].population, 60.0)


func test_revolt_stops_income() -> void:
	_cfg.revolt_chance_per_point = 1.0
	_state.provinces["HOL"].satisfaction = 0.0
	_state.houses["welfen"].tax_rate = 40
	EconomySettlement.settle(_state, _map, _cfg)
	assert_true(_state.provinces["HOL"].in_revolt)
	var house := _state.houses["welfen"]
	var brunswick := _state.provinces["BSW"]
	house.tax_rate = 5
	var expected := (
		house.gold
		+ IncomeRules.tax(_cfg, brunswick.population, 5, brunswick.satisfaction)
		- 10.0
	)
	EconomySettlement.settle(_state, _map, _cfg)
	assert_almost_eq(house.gold, expected, EPSILON)


func test_neutral_provinces_are_not_settled() -> void:
	var frisia := _state.provinces["FRS"].to_dict()
	EconomySettlement.settle(_state, _map, _cfg)
	assert_eq_deep(_state.provinces["FRS"].to_dict(), frisia)
