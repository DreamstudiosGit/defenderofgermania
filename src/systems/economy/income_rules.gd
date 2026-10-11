class_name IncomeRules
extends RefCounted
## Gold income and upkeep per round as pure functions (docs/design/economy.md, "Income").


static func tax(
	cfg: EconomyConfig, population: float, tax_percent: int, satisfaction: float
) -> float:
	var collection := cfg.tax_base + satisfaction / cfg.tax_satisfaction_divisor
	return population * tax_percent / 100.0 * cfg.tax_factor * collection


static func effective_tax_rate(tax_percent: int, tax_cap: int) -> int:
	return mini(tax_percent, tax_cap)


static func market(
	cfg: EconomyConfig,
	population: float,
	market_level: int,
	house_multiplier: float,
	is_autumn: bool,
	satisfaction: float
) -> float:
	var season := cfg.market_autumn_multiplier if is_autumn else 1.0
	var unrest := (
		cfg.market_unrest_multiplier if satisfaction < cfg.market_unrest_threshold else 1.0
	)
	return population * cfg.market_factor * market_level * house_multiplier * season * unrest


static func building_income(
	building: BuildingDef, multiplier: float, has_river: bool, has_pass: bool
) -> float:
	var toll := 0.0
	if has_pass:
		toll = building.income_pass
	elif has_river:
		toll = building.income_river
	return (building.income + toll) * multiplier


static func unit_upkeep(cfg: EconomyConfig, unit_ids: Array[String]) -> float:
	var total := 0.0
	for id: String in unit_ids:
		total += cfg.units[id].upkeep_gold
	return total


static func castle_upkeep(cfg: EconomyConfig, castle_level: int, is_home: bool) -> float:
	var table := cfg.home_castle if is_home else cfg.province_castle
	return table[castle_level].upkeep if table.has(castle_level) else 0.0


static func deserters(cfg: EconomyConfig, unit_count: int) -> int:
	return ceili(unit_count * cfg.desertion_share)
