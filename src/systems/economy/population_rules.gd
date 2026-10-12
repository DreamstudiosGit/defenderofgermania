class_name PopulationRules
extends RefCounted
## Satisfaction, revolts, growth, prestige and recruitment limits as pure functions
## (docs/design/economy.md, "Satisfaction and revolt", "Population and prestige").


## home_castle_level is 0 for provinces that are not the house's home province.
static func target_satisfaction(
	cfg: EconomyConfig,
	tax_percent: int,
	ration: int,
	bonus: float,
	prestige: float,
	home_castle_level: int,
	is_occupied: bool,
	is_banned: bool
) -> float:
	var target := (
		cfg.satisfaction_base
		- cfg.tax_weight * (tax_percent - cfg.tax_pivot)
		+ cfg.ration_weight * (ration - cfg.normal_ration)
		+ bonus
		+ prestige / cfg.prestige_divisor
		+ cfg.home_castle_bonus * maxi(home_castle_level - 1, 0)
	)
	if is_occupied:
		target -= cfg.occupation_penalty
	if is_banned:
		target -= cfg.ban_penalty
	return clampf(target, 0.0, cfg.satisfaction_max)


static func next_satisfaction(cfg: EconomyConfig, current: float, target: float) -> float:
	var next := current + cfg.satisfaction_adjust_rate * (target - current)
	return clampf(next, 0.0, cfg.satisfaction_max)


static func revolt_chance(cfg: EconomyConfig, satisfaction: float) -> float:
	return maxf(0.0, (cfg.revolt_threshold - satisfaction) * cfg.revolt_chance_per_point)


## Levy companies of the rebels when a province revolts: ⌈V / 15⌉.
static func rebel_companies(cfg: EconomyConfig, population: float) -> int:
	return ceili(population / cfg.rebel_population_divisor)


static func growth_rate(
	cfg: EconomyConfig, satisfaction: float, ration: int, bonus: float, plague: float
) -> float:
	return (
		cfg.growth_base * (satisfaction - cfg.growth_pivot) / cfg.growth_span
		+ cfg.ration_growth * (ration - cfg.normal_ration)
		+ bonus
		- plague
	)


static func capacity(
	cfg: EconomyConfig, start_population: float, castle_level: int, market_level: int
) -> float:
	return (
		cfg.capacity_start_factor * start_population
		+ cfg.capacity_per_castle_level * castle_level
		+ cfg.capacity_per_market_level * market_level
	)


static func next_population(population: float, growth: float, limit: float) -> float:
	return minf(limit, population * (1.0 + growth))


static func next_prestige(cfg: EconomyConfig, prestige: float, delta: float) -> float:
	return clampf(cfg.prestige_decay * prestige + delta, 0.0, cfg.prestige_max)


static func recruit_limit(cfg: EconomyConfig, population: float) -> int:
	return floori(population / cfg.recruit_population_per_unit)
