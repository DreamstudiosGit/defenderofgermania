extends GutTest
## Kornvogt forecast against hand-computed numbers: the Welfen start with 300 bushels and eat
## 90.75 per round (105 people × 3/4 + 4 companies × 3); 10 % spoils after each meal.

const EPSILON := 1e-9

var _map: MapData
var _cfg: EconomyConfig
var _state: GameState


func before_all() -> void:
	_map = MapData.load_file()
	_cfg = EconomyConfig.load_file()


func before_each() -> void:
	_state = GameSetup.create(_map, _cfg, 1)


func test_spring_counts_two_meals_before_the_harvest() -> void:
	var forecast := _forecast()
	assert_eq(forecast.rounds_to_harvest, 2)
	assert_eq(forecast.stock, 300.0)
	# (300 − 90.75) × 0.9 = 188.325, then (188.325 − 90.75) × 0.9 = 87.8175.
	assert_almost_eq(forecast.stock_before_harvest, 87.8175, EPSILON)
	assert_almost_eq(forecast.expected_harvest, 480.0, EPSILON)
	assert_almost_eq(forecast.stock_after_harvest, (87.8175 + 480.0 - 90.75) * 0.9, EPSILON)
	assert_eq(forecast.demand.size(), 3)
	assert_almost_eq(forecast.demand[0], 90.75, EPSILON)
	assert_false(forecast.runs_short())


func test_small_stock_runs_short_in_summer() -> void:
	_state.houses["welfen"].grain = 100.0
	var forecast := _forecast()
	# (100 − 90.75) × 0.9 = 8.325 left for the summer meal of 90.75.
	assert_true(forecast.runs_short())
	assert_eq(forecast.shortage_round, 1)
	assert_almost_eq(forecast.shortage, 90.75 - 8.325, EPSILON)
	assert_eq(forecast.stock_before_harvest, 0.0)
	assert_almost_eq(forecast.stock_after_harvest, (480.0 - 90.75) * 0.9, EPSILON)


func test_autumn_harvests_at_this_settlement() -> void:
	_state.turn = GameState.Season.AUTUMN
	_state.houses["welfen"].grain = 0.0
	var forecast := _forecast()
	assert_eq(forecast.rounds_to_harvest, 0)
	assert_eq(forecast.stock_before_harvest, 0.0)
	assert_false(forecast.runs_short())
	assert_almost_eq(forecast.stock_after_harvest, (480.0 - 90.75) * 0.9, EPSILON)


func test_winter_abroad_and_granary() -> void:
	_state.turn = GameState.Season.WINTER
	_state.armies_of("welfen")[0].province = "BRM"
	_state.provinces["HOL"].buildings.append("granary")
	assert_eq(_forecast().shortage_round, 2)
	_state.houses["welfen"].grain = 400.0
	var forecast := _forecast()
	assert_eq(forecast.rounds_to_harvest, 3)
	assert_almost_eq(forecast.demand[0], 78.75 + 18.0, EPSILON)
	assert_almost_eq(forecast.demand[1], 90.75, EPSILON)
	var left := (400.0 - 96.75) * 0.92
	left = (left - 90.75) * 0.92
	left = (left - 90.75) * 0.92
	assert_almost_eq(forecast.stock_before_harvest, left, EPSILON)
	assert_false(forecast.runs_short())


func test_occupation_halves_the_harvest_only_if_it_lasts_until_autumn() -> void:
	_state.provinces["HOL"].occupied_rounds = 2
	assert_almost_eq(_forecast().expected_harvest, 480.0, EPSILON)
	_state.provinces["HOL"].occupied_rounds = 3
	assert_almost_eq(_forecast().expected_harvest, 300.0 + 90.0, EPSILON)


func _forecast() -> EconomyForecast:
	return EconomyForecast.create(_state, _map, _cfg, "welfen")
