extends GutTest
## Golden test: the worked example "Welfen im ersten Herbst" from the GDD (economy section),
## computed from the real data files. Braunschweig and Holstein both at satisfaction 55,
## tax 15 %, weather 1.0.

const EPSILON := 1e-9
const SATISFACTION := 55.0
const TAX_RATE := 15

var _cfg: EconomyConfig
var _map: MapData


func before_all() -> void:
	_cfg = EconomyConfig.load_file()
	_map = MapData.load_file()


func test_tax_braunschweig_and_holstein() -> void:
	var brunswick := IncomeRules.tax(_cfg, _population("BSW"), TAX_RATE, SATISFACTION)
	var holstein := IncomeRules.tax(_cfg, _population("HOL"), TAX_RATE, SATISFACTION)
	assert_almost_eq(brunswick, 20.925, EPSILON)
	assert_almost_eq(holstein, 15.69375, EPSILON)
	assert_eq(roundi(brunswick), 21)
	assert_eq(roundi(holstein), 16)


func test_market_holstein_in_autumn() -> void:
	var market := _holstein_market()
	assert_almost_eq(market, 25.3125, EPSILON)
	assert_eq(roundi(market), 25)


func test_start_army_upkeep_and_balance() -> void:
	var upkeep := IncomeRules.unit_upkeep(_cfg, _map.start_army)
	assert_eq(upkeep, 6.0)
	var income := (
		IncomeRules.tax(_cfg, _population("BSW"), TAX_RATE, SATISFACTION)
		+ IncomeRules.tax(_cfg, _population("HOL"), TAX_RATE, SATISFACTION)
		+ _holstein_market()
	)
	assert_eq(roundi(income - upkeep), 56)


func test_harvest_braunschweig_and_holstein() -> void:
	assert_almost_eq(_harvest("BSW", 1.0), 300.0, EPSILON)
	assert_almost_eq(_harvest("HOL", 1.0), 180.0, EPSILON)


func test_yearly_demand_and_surplus() -> void:
	var yearly := GameState.ROUNDS_PER_YEAR * _round_demand()
	assert_almost_eq(yearly, 363.0, EPSILON)
	assert_almost_eq(_harvest("BSW", 1.0) + _harvest("HOL", 1.0) - yearly, 117.0, EPSILON)


func test_surplus_sells_for_52_65_taler() -> void:
	var price := GrainRules.autumn_price(_cfg, 1.0, 1.0)
	var unit_price := GrainRules.sell_price(price, _cfg.houses["welfen"].grain_spread)
	assert_almost_eq(unit_price, 0.45, EPSILON)
	assert_almost_eq(117.0 * unit_price, 52.65, EPSILON)
	assert_eq(roundi(117.0 * unit_price), 53)


func test_bad_harvest_leaves_75_bushels_missing() -> void:
	var harvest := _harvest("BSW", 0.6) + _harvest("HOL", 0.6)
	var yearly := GameState.ROUNDS_PER_YEAR * _round_demand()
	assert_almost_eq(yearly - harvest, 75.0, EPSILON)


func _population(id: String) -> float:
	return _map.provinces[id].population


func _holstein_market() -> float:
	var level := _cfg.buildings["market_1"].market_level
	var multiplier := _cfg.houses["welfen"].market_multiplier
	return IncomeRules.market(_cfg, _population("HOL"), level, multiplier, true, SATISFACTION)


func _harvest(id: String, weather: float) -> float:
	var def := _map.provinces[id]
	var bonus := 0.0
	for building: String in def.buildings:
		bonus += _cfg.buildings[building].harvest_bonus
	var field_yield := _map.terrains[def.terrain].field_yield
	return GrainRules.harvest(_cfg, def.population, field_yield, weather, bonus, false)


func _round_demand() -> float:
	var troops := 0.0
	for id: String in _map.start_army:
		troops += GrainRules.troop_grain(_cfg, _cfg.units[id].upkeep_grain, false)
	return GrainRules.demand(_population("BSW") + _population("HOL"), 3, troops)
