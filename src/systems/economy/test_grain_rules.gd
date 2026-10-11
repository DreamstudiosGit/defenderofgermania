extends GutTest

const EPSILON := 1e-9

var _cfg: EconomyConfig


func before_all() -> void:
	_cfg = EconomyConfig.load_file()


func test_harvest_halves_in_disrupted_provinces() -> void:
	assert_almost_eq(GrainRules.harvest(_cfg, 40.0, 3.0, 1.0, 0.0, false), 120.0, EPSILON)
	assert_almost_eq(GrainRules.harvest(_cfg, 40.0, 3.0, 1.0, 0.0, true), 60.0, EPSILON)


func test_weather_rolls_follow_weights() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var counts := {}
	var draws := 20000
	for i: int in draws:
		var weather := GrainRules.roll_weather(_cfg, rng)
		counts[weather] = counts.get(weather, 0) + 1
	for i: int in _cfg.weather_values.size():
		var share := float(counts.get(_cfg.weather_values[i], 0)) / draws
		assert_almost_eq(share, _cfg.weather_weights[i] / 100.0, 0.02)


func test_troops_eat_more_abroad_in_winter() -> void:
	assert_eq(GrainRules.troop_grain(_cfg, 6.0, false), 6.0)
	assert_eq(GrainRules.troop_grain(_cfg, 6.0, true), 9.0)


func test_demand_per_round_is_quarter_of_yearly_ration() -> void:
	assert_almost_eq(GrainRules.demand(100.0, 4, 10.0), 110.0, EPSILON)


func test_coverage_is_capped_at_one() -> void:
	assert_eq(GrainRules.coverage(50.0, 100.0), 0.5)
	assert_eq(GrainRules.coverage(500.0, 100.0), 1.0)
	assert_eq(GrainRules.coverage(0.0, 0.0), 1.0)


func test_shortage_effects_scale_with_missing_grain() -> void:
	assert_almost_eq(GrainRules.shortage_satisfaction_loss(_cfg, 0.5), 15.0, EPSILON)
	assert_almost_eq(GrainRules.shortage_population_factor(_cfg, 0.5), 0.95, EPSILON)
	assert_almost_eq(GrainRules.shortage_morale_loss(_cfg, 0.5), 10.0, EPSILON)
	assert_eq(GrainRules.shortage_satisfaction_loss(_cfg, 1.0), 0.0)


func test_granaries_reduce_spoilage_down_to_minimum() -> void:
	var per_granary := _cfg.buildings["granary"].spoilage_reduction
	assert_almost_eq(GrainRules.spoilage_rate(_cfg, 0.0), 0.10, EPSILON)
	assert_almost_eq(GrainRules.spoilage_rate(_cfg, 2 * per_granary), 0.06, EPSILON)
	assert_almost_eq(GrainRules.spoilage_rate(_cfg, 10 * per_granary), 0.02, EPSILON)


func test_autumn_price_falls_with_good_weather() -> void:
	assert_almost_eq(GrainRules.autumn_price(_cfg, 1.0, 1.0), 0.5, EPSILON)
	assert_almost_eq(GrainRules.autumn_price(_cfg, 1.25, 1.0), 0.4, EPSILON)
	assert_almost_eq(GrainRules.autumn_price(_cfg, 0.6, 1.1), 0.5 / 0.6 * 1.1, EPSILON)


func test_price_rises_each_round_after_autumn() -> void:
	assert_almost_eq(GrainRules.price(_cfg, 0.5, 0), 0.5, EPSILON)
	assert_almost_eq(GrainRules.price(_cfg, 0.5, 3), 0.65, EPSILON)


func test_prices_stay_within_bounds() -> void:
	assert_eq(GrainRules.autumn_price(_cfg, 0.1, 1.0), _cfg.price_max)
	assert_eq(GrainRules.price_after_trade(_cfg, 0.2, 0.0, 1000.0), _cfg.price_min)


func test_spread_between_buying_and_selling() -> void:
	assert_almost_eq(GrainRules.buy_price(0.5, 0.2), 0.6, EPSILON)
	assert_almost_eq(GrainRules.sell_price(0.5, 0.2), 0.4, EPSILON)


func test_trades_move_price_two_percent_per_hundred() -> void:
	assert_almost_eq(GrainRules.price_after_trade(_cfg, 1.0, 100.0, 0.0), 1.02, EPSILON)
	assert_almost_eq(GrainRules.price_after_trade(_cfg, 1.0, 0.0, 250.0), 0.95, EPSILON)
