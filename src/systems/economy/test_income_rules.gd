extends GutTest

const EPSILON := 1e-9

var _cfg: EconomyConfig


func before_all() -> void:
	_cfg = EconomyConfig.load_file()


func test_tax_scales_with_population_rate_and_satisfaction() -> void:
	assert_almost_eq(IncomeRules.tax(_cfg, 100.0, 10, 0.0), 15.0, EPSILON)
	assert_almost_eq(IncomeRules.tax(_cfg, 100.0, 10, 100.0), 30.0, EPSILON)


func test_tax_cap_limits_rate() -> void:
	assert_eq(IncomeRules.effective_tax_rate(40, 15), 15)
	assert_eq(IncomeRules.effective_tax_rate(10, 15), 10)


func test_market_without_market_building_yields_nothing() -> void:
	assert_eq(IncomeRules.market(_cfg, 60.0, 0, 1.0, true, 80.0), 0.0)


func test_market_halves_below_unrest_threshold() -> void:
	var calm := IncomeRules.market(_cfg, 40.0, 2, 1.0, false, 30.0)
	var restless := IncomeRules.market(_cfg, 40.0, 2, 1.0, false, 29.9)
	assert_almost_eq(calm, 24.0, EPSILON)
	assert_almost_eq(restless, 12.0, EPSILON)


func test_market_autumn_bonus() -> void:
	assert_almost_eq(IncomeRules.market(_cfg, 40.0, 1, 1.0, true, 50.0), 15.0, EPSILON)


func test_toll_pays_more_at_passes_than_rivers() -> void:
	var toll := _cfg.buildings["toll"]
	assert_eq(IncomeRules.building_income(toll, 1.0, true, false), 8.0)
	assert_eq(IncomeRules.building_income(toll, 1.0, false, true), 15.0)
	assert_eq(IncomeRules.building_income(toll, 1.0, false, false), 0.0)


func test_wettin_mines_yield_half_more() -> void:
	var multiplier: float = _cfg.houses["wettiner"].building_income["mine"]
	assert_eq(IncomeRules.building_income(_cfg.buildings["mine"], multiplier, false, false), 45.0)


func test_unit_upkeep_sums_companies() -> void:
	var units: Array[String] = ["levy", "spearmen", "knights"]
	assert_eq(IncomeRules.unit_upkeep(_cfg, units), 11.0)


func test_castle_upkeep_uses_home_or_province_table() -> void:
	assert_eq(IncomeRules.castle_upkeep(_cfg, 1, true), 0.0)
	assert_eq(IncomeRules.castle_upkeep(_cfg, 3, true), 10.0)
	assert_eq(IncomeRules.castle_upkeep(_cfg, 1, false), 2.0)
	assert_eq(IncomeRules.castle_upkeep(_cfg, 0, false), 0.0)


func test_desertion_rounds_up() -> void:
	assert_eq(IncomeRules.deserters(_cfg, 4), 1)
	assert_eq(IncomeRules.deserters(_cfg, 10), 1)
	assert_eq(IncomeRules.deserters(_cfg, 11), 2)
	assert_eq(IncomeRules.deserters(_cfg, 0), 0)
