extends GutTest

const EPSILON := 1e-9
## GDD table "Steuersatz auf einen Blick": equilibrium without buildings, ration 3, prestige 20.
## Columns: tax %, target satisfaction, tax per 10 population, growth per year in %.
const TAX_TABLE := [
	[5, 70, 1.3, 1.5],
	[10, 62, 2.4, 1.1],
	[15, 55, 3.5, 0.7],
	[20, 47, 4.4, 0.4],
	[25, 40, 5.2, 0.0],
	[30, 32, 5.9, -0.4],
	[40, 17, 7.0, -1.2],
]

var _cfg: EconomyConfig


func before_all() -> void:
	_cfg = EconomyConfig.load_file()


func test_tax_table_from_gdd() -> void:
	for row: Array in TAX_TABLE:
		var rate: int = row[0]
		var target := PopulationRules.target_satisfaction(_cfg, rate, 3, 0.0, 20.0, 0, false, false)
		var tax := IncomeRules.tax(_cfg, 10.0, rate, target)
		var growth := PopulationRules.growth_rate(_cfg, target, 3, 0.0, 0.0) * 100.0
		# The GDD rounds to whole points and one decimal; allow half a rounding step.
		assert_almost_eq(target, float(row[1]), 0.5 + EPSILON, "target at %d %%" % rate)
		assert_almost_eq(tax, float(row[2]), 0.05 + EPSILON, "tax at %d %%" % rate)
		assert_almost_eq(growth, float(row[3]), 0.05 + EPSILON, "growth at %d %%" % rate)


func test_tax_40_percent_means_24_percent_revolt_risk() -> void:
	var target := PopulationRules.target_satisfaction(_cfg, 40, 3, 0.0, 20.0, 0, false, false)
	assert_almost_eq(PopulationRules.revolt_chance(_cfg, target), 0.24, EPSILON)


func test_target_satisfaction_modifiers() -> void:
	var base := PopulationRules.target_satisfaction(_cfg, 10, 3, 0.0, 0.0, 0, false, false)
	assert_almost_eq(base, 60.0, EPSILON)
	var rich := PopulationRules.target_satisfaction(_cfg, 10, 4, 10.0, 0.0, 3, false, false)
	assert_almost_eq(rich, 60.0 + 10.0 + 10.0 + 10.0, EPSILON)
	var oppressed := PopulationRules.target_satisfaction(_cfg, 10, 3, 0.0, 0.0, 0, true, true)
	assert_almost_eq(oppressed, 30.0, EPSILON)


func test_target_satisfaction_is_clamped() -> void:
	assert_eq(PopulationRules.target_satisfaction(_cfg, 40, 2, 0.0, 0.0, 0, true, true), 0.0)
	assert_eq(PopulationRules.target_satisfaction(_cfg, 5, 4, 50.0, 100.0, 5, false, false), 100.0)


func test_satisfaction_moves_a_quarter_towards_target() -> void:
	assert_almost_eq(PopulationRules.next_satisfaction(_cfg, 40.0, 60.0), 45.0, EPSILON)
	assert_almost_eq(PopulationRules.next_satisfaction(_cfg, 60.0, 40.0), 55.0, EPSILON)


func test_no_revolt_risk_at_or_above_threshold() -> void:
	assert_eq(PopulationRules.revolt_chance(_cfg, 25.0), 0.0)
	assert_almost_eq(PopulationRules.revolt_chance(_cfg, 15.0), 0.30, EPSILON)


func test_monastery_and_rich_rations_add_growth() -> void:
	var growth := PopulationRules.growth_rate(_cfg, 40.0, 4, 0.01, 0.0)
	assert_almost_eq(growth, 0.03, EPSILON)
	assert_almost_eq(PopulationRules.growth_rate(_cfg, 40.0, 3, 0.0, 0.1), -0.1, EPSILON)


func test_capacity_from_start_population_castle_and_market() -> void:
	assert_almost_eq(PopulationRules.capacity(_cfg, 60.0, 2, 1), 90.0 + 10.0 + 10.0, EPSILON)


func test_population_growth_is_capped() -> void:
	assert_almost_eq(PopulationRules.next_population(50.0, 0.1, 100.0), 55.0, EPSILON)
	assert_eq(PopulationRules.next_population(99.0, 0.1, 100.0), 100.0)


func test_prestige_settles_at_twenty_times_running_sources() -> void:
	var prestige := 0.0
	for i: int in 400:
		prestige = PopulationRules.next_prestige(_cfg, prestige, 1.5)
	assert_almost_eq(prestige, 30.0, 1e-6)


func test_prestige_is_clamped() -> void:
	assert_eq(PopulationRules.next_prestige(_cfg, 100.0, 50.0), 100.0)
	assert_eq(PopulationRules.next_prestige(_cfg, 1.0, -10.0), 0.0)


func test_recruit_limit_per_year() -> void:
	assert_eq(PopulationRules.recruit_limit(_cfg, 59.0), 2)
	assert_eq(PopulationRules.recruit_limit(_cfg, 60.0), 3)
