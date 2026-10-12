extends GutTest
## EconomyBreakdown and GrainBreakdown: the GDD's worked example "Welfen im ersten Herbst"
## appears in the terms, and the terms add up to what EconomySettlement applies.

const EPSILON := 1e-9

var _map: MapData
var _cfg: EconomyConfig
var _state: GameState


func before_all() -> void:
	_map = MapData.load_file()
	_cfg = EconomyConfig.load_file()


func before_each() -> void:
	_state = GameSetup.create(_map, _cfg, 1)


func test_welfen_first_autumn_income() -> void:
	_state.turn = GameState.Season.AUTUMN
	var terms := EconomyBreakdown.income(_state, _map, _cfg, "welfen")
	var tax := _find(terms, "ECONOMY_TERM_TAX", "PROVINCE_BSW")
	assert_almost_eq(tax.value, 20.925, EPSILON)
	assert_eq(tax.formula, "60 × 15 % × 3 × (0.5 + 55/200)")
	assert_almost_eq(_find(terms, "ECONOMY_TERM_TAX", "PROVINCE_HOL").value, 15.69375, EPSILON)
	var market := _find(terms, "ECONOMY_TERM_MARKET", "PROVINCE_HOL")
	assert_almost_eq(market.value, 25.3125, EPSILON)
	assert_eq(market.formula, "45 × 0.3 × 1 × 1.5 × 1.25")
	assert_eq(terms.size(), 3)


func test_welfen_upkeep_army_mill_and_market() -> void:
	var terms := EconomyBreakdown.upkeep(_state, _cfg, "welfen")
	var army := _find(terms, "ECONOMY_TERM_ARMY_UPKEEP", "PROVINCE_BSW")
	assert_eq(army.value, -6.0)
	assert_eq(army.formula, "2 × 1 + 2 × 2")
	assert_eq(EconomyTerm.sum(terms), -10.0)


func test_welfen_first_autumn_harvest_and_yearly_demand() -> void:
	var harvest := GrainBreakdown.harvest(_state, _map, _cfg, "welfen")
	var brunswick := _find(harvest, "ECONOMY_TERM_HARVEST", "PROVINCE_BSW")
	assert_almost_eq(brunswick.value, 300.0, EPSILON)
	assert_eq(brunswick.formula, "60 × 4 × 1 × (1 + 0.25)")
	assert_almost_eq(_find(harvest, "ECONOMY_TERM_HARVEST", "PROVINCE_HOL").value, 180.0, EPSILON)
	assert_almost_eq(GrainBreakdown.yearly_grain_demand(_state, _cfg, "welfen"), 363.0, EPSILON)
	var bad_year: Dictionary[String, float] = {"north": 0.6}
	var bad := EconomyTerm.sum(GrainBreakdown.harvest(_state, _map, _cfg, "welfen", bad_year))
	assert_almost_eq(363.0 - bad, 75.0, EPSILON)


func test_grain_demand_terms_per_province_and_army() -> void:
	var terms := GrainBreakdown.grain_demand(_state, _cfg, "welfen", GameState.Season.SPRING)
	var people := _find(terms, "ECONOMY_TERM_PEOPLE_GRAIN", "PROVINCE_BSW")
	assert_eq(people.value, 45.0)
	assert_eq(people.formula, "60 × 3/4")
	assert_eq(_find(terms, "ECONOMY_TERM_TROOP_GRAIN", "PROVINCE_BSW").value, 12.0)
	assert_almost_eq(EconomyTerm.sum(terms), 90.75, EPSILON)


func test_troops_abroad_eat_more_in_winter() -> void:
	_state.armies_of("welfen")[0].province = "BRM"
	var terms := GrainBreakdown.grain_demand(_state, _cfg, "welfen", GameState.Season.WINTER)
	var troops := _find(terms, "ECONOMY_TERM_TROOP_GRAIN", "PROVINCE_BRM")
	assert_eq(troops.value, 18.0)
	assert_eq(troops.formula, "(2 × 3 + 2 × 3) × 1.5")


func test_lower_tax_previews_lower_income_and_higher_target() -> void:
	var low := EconomyBreakdown.income(_state, _map, _cfg, "welfen", 5)
	assert_almost_eq(_find(low, "ECONOMY_TERM_TAX", "PROVINCE_BSW").value, 6.975, EPSILON)
	var target := EconomyBreakdown.target_satisfaction(_state, _map, _cfg, "welfen", "HOL", 5)
	assert_eq(_find(target, "ECONOMY_Z_TAX", "").formula, "−1.5 × (5 − 10)")
	assert_almost_eq(EconomyTerm.sum(target), 60.0 + 7.5 + 5.0 + 2.0, EPSILON)
	assert_eq(_state.houses["welfen"].tax_rate, 15)


func test_projected_gold_change_matches_settlement() -> void:
	_complicate()
	for season: int in GameState.ROUNDS_PER_YEAR:
		_state.turn = season
		for house: String in _state.houses:
			var projected := EconomyTerm.sum(EconomyBreakdown.gold_change(_state, _map, _cfg, house))
			var copy := _settled_copy()
			var change := copy.houses[house].gold - _state.houses[house].gold
			assert_almost_eq(change, projected, EPSILON, "%s in season %d" % [house, season])


func test_target_satisfaction_matches_settlement() -> void:
	_complicate()
	for house: String in _state.houses:
		for province: ProvinceState in _state.provinces_of(house):
			var terms := EconomyBreakdown.target_satisfaction(
				_state, _map, _cfg, house, province.id
			)
			var expected := PopulationRules.next_satisfaction(
				_cfg, province.satisfaction, EconomyTerm.sum(terms)
			)
			var settled := _settled_copy().provinces[province.id].satisfaction
			assert_almost_eq(settled, expected, EPSILON, province.id)


func test_target_satisfaction_names_every_summand() -> void:
	_complicate()
	var terms := EconomyBreakdown.target_satisfaction(_state, _map, _cfg, "welfen", "FRS")
	var labels: Array[String] = []
	for term: EconomyTerm in terms:
		labels.append(term.label_key)
	assert_eq(labels, [
		"ECONOMY_Z_BASE", "ECONOMY_Z_TAX", "ECONOMY_Z_RATION", "ECONOMY_Z_BUILDING",
		"ECONOMY_Z_PROVINCE", "ECONOMY_Z_PRESTIGE", "ECONOMY_Z_OCCUPATION", "ECONOMY_Z_BAN"
	] as Array[String])
	var home := EconomyBreakdown.target_satisfaction(_state, _map, _cfg, "welfen", "BSW")
	assert_eq(_find(home, "ECONOMY_Z_DECORATION", "ECONOMY_DECORATION_FOUNTAIN").value, 3.0)
	assert_eq(_find(home, "ECONOMY_Z_HOME_CASTLE", "").value, 10.0)


func test_target_satisfaction_is_clamped_by_a_last_term() -> void:
	var house := _state.houses["welfen"]
	house.is_banned = true
	house.prestige = 0.0
	_state.provinces["HOL"].occupied_rounds = 2
	var terms := EconomyBreakdown.target_satisfaction(_state, _map, _cfg, "welfen", "HOL", 40, 2)
	assert_eq(terms[-1].label_key, "ECONOMY_Z_LIMIT")
	assert_almost_eq(EconomyTerm.sum(terms), 0.0, EPSILON)


func test_projected_prestige_matches_settlement() -> void:
	_complicate()
	for house: String in _state.houses:
		var projected := EconomyTerm.sum(EconomyBreakdown.prestige(_state, _cfg, house))
		var change := _settled_copy().houses[house].prestige - _state.houses[house].prestige
		assert_almost_eq(change, projected, EPSILON, house)


func test_grain_prices_rise_after_autumn_and_with_trade() -> void:
	var prices := GrainBreakdown.grain_prices(_state, _cfg, "welfen")
	assert_almost_eq(prices[0].value, 0.6, EPSILON)
	assert_eq(prices[0].formula, "0.5 × (1 + 0.1 × 2)")
	assert_almost_eq(prices[1].value, 0.66, EPSILON)
	assert_almost_eq(prices[2].value, 0.54, EPSILON)
	_state.grain_traded = 100.0
	var shifted := GrainBreakdown.grain_prices(_state, _cfg, "staufer")
	assert_almost_eq(shifted[0].value, 0.612, EPSILON)
	assert_almost_eq(shifted[1].value, 0.612 * 1.2, EPSILON)


func test_spoilage_falls_with_granaries() -> void:
	assert_almost_eq(GrainBreakdown.spoilage(_state, _cfg, "welfen").value, 0.1, EPSILON)
	_state.provinces["HOL"].buildings.append("granary")
	assert_almost_eq(GrainBreakdown.spoilage(_state, _cfg, "welfen").value, 0.08, EPSILON)


func test_capacity_and_growth() -> void:
	var brunswick := EconomyBreakdown.capacity(_state, _map, _cfg, "BSW")
	assert_almost_eq(EconomyTerm.sum(brunswick), 95.0, EPSILON)
	var holstein := EconomyBreakdown.capacity(_state, _map, _cfg, "HOL")
	assert_eq(_find(holstein, "ECONOMY_CAPACITY_MARKET", "").value, 10.0)
	assert_almost_eq(EconomyTerm.sum(holstein), 77.5, EPSILON)
	var growth := EconomyBreakdown.growth(_state, _cfg, "welfen", "BSW")
	assert_almost_eq(growth.value, 0.03 * 15.0 / 60.0, EPSILON)


func test_formula_numbers_drop_trailing_zeros() -> void:
	assert_eq(EconomyTerm.num(60.0), "60")
	assert_eq(EconomyTerm.num(0.775), "0.775")
	assert_eq(EconomyTerm.num(1.25), "1.25")
	assert_eq(EconomyTerm.num(-0.0), "0")
	assert_eq(EconomyTerm.num(-7.5), "-7.5")


func test_revolt_pays_nothing() -> void:
	_state.provinces["HOL"].in_revolt = true
	var terms := EconomyBreakdown.income(_state, _map, _cfg, "welfen")
	assert_eq(_find(terms, "ECONOMY_TERM_REVOLT", "PROVINCE_HOL").value, 0.0)
	assert_null(_find(terms, "ECONOMY_TERM_MARKET", "PROVINCE_HOL"))


## Mines, tolls, salt, a siege, a revolt, an occupied province with its own bonus, the ban,
## decorations and pending prestige, with enough taler and grain to avoid debt and hunger.
func _complicate() -> void:
	var wettiner := _state.houses["wettiner"]
	_state.provinces["MEI"].buildings.append_array(["mine", "toll"])
	_state.provinces["SAL"].owner = "wettiner"
	wettiner.tax_rate = 30
	_state.provinces["BRM"].castle_level = 1
	_state.armies_of("welfen")[0].province = "BRM"
	_state.provinces["HOL"].in_revolt = true
	_state.provinces["HOL"].buildings.append("monastery")
	_state.provinces["FRS"].owner = "welfen"
	_state.provinces["FRS"].occupied_rounds = 3
	_state.provinces["FRS"].buildings.append("market_1")
	_state.provinces["BSW"].castle_level = 3
	var welfen := _state.houses["welfen"]
	welfen.is_banned = true
	welfen.decorations.append_array(["fountain", "banners"] as Array[String])
	welfen.pending_prestige = 3.0
	welfen.ration = 4
	welfen.tax_rate = 20
	for house: HouseState in _state.houses.values():
		house.grain = 5000.0
		house.gold = 1000.0


func _settled_copy() -> GameState:
	var copy := GameState.from_dict(_state.to_dict())
	EconomySettlement.settle(copy, _map, _cfg)
	return copy


func _find(terms: Array[EconomyTerm], label: String, arg: String) -> EconomyTerm:
	for term: EconomyTerm in terms:
		if term.label_key == label and (arg.is_empty() or arg in term.args):
			return term
	return null
