class_name GrainRules
extends RefCounted
## Harvest, consumption and the grain market as pure functions
## (docs/design/economy.md, "Grain" and "Grain market"). Chance comes in as an RNG argument.


static func harvest(
	cfg: EconomyConfig,
	population: float,
	field_yield: float,
	weather: float,
	harvest_bonus: float,
	is_disrupted: bool
) -> float:
	var disruption := cfg.harvest_disrupted_multiplier if is_disrupted else 1.0
	return population * field_yield * weather * (1.0 + harvest_bonus) * disruption


static func roll_weather(cfg: EconomyConfig, rng: RandomNumberGenerator) -> float:
	return cfg.weather_values[rng.rand_weighted(cfg.weather_weights)]


static func troop_grain(cfg: EconomyConfig, upkeep_grain: float, is_winter_abroad: bool) -> float:
	return upkeep_grain * (cfg.winter_abroad_multiplier if is_winter_abroad else 1.0)


static func demand(population: float, ration: int, troop_grain_total: float) -> float:
	return population * ration / GameState.ROUNDS_PER_YEAR + troop_grain_total


static func coverage(stock: float, needed: float) -> float:
	return 1.0 if needed <= 0.0 else minf(1.0, stock / needed)


static func shortage_satisfaction_loss(cfg: EconomyConfig, covered: float) -> float:
	return cfg.shortage_satisfaction * (1.0 - covered)


static func shortage_population_factor(cfg: EconomyConfig, covered: float) -> float:
	return 1.0 - cfg.shortage_population * (1.0 - covered)


static func shortage_morale_loss(cfg: EconomyConfig, covered: float) -> float:
	return cfg.shortage_morale * (1.0 - covered)


static func spoilage_rate(cfg: EconomyConfig, reduction: float) -> float:
	return maxf(cfg.spoilage_min, cfg.spoilage_base - reduction)


static func roll_price_noise(cfg: EconomyConfig, rng: RandomNumberGenerator) -> float:
	return rng.randf_range(cfg.price_noise_min, cfg.price_noise_max)


static func autumn_price(cfg: EconomyConfig, mean_weather: float, noise: float) -> float:
	return _clamp_price(cfg, cfg.base_grain_price / mean_weather * noise)


static func price(cfg: EconomyConfig, price_in_autumn: float, rounds_since_autumn: int) -> float:
	return _clamp_price(cfg, price_in_autumn * (1.0 + cfg.price_rise_per_round * rounds_since_autumn))


static func buy_price(current_price: float, spread: float) -> float:
	return current_price * (1.0 + spread)


static func sell_price(current_price: float, spread: float) -> float:
	return current_price * (1.0 - spread)


static func price_after_trade(
	cfg: EconomyConfig, current_price: float, bought: float, sold: float
) -> float:
	var shift := cfg.price_impact_per_100 * (bought - sold) / 100.0
	return _clamp_price(cfg, current_price * (1.0 + shift))


static func _clamp_price(cfg: EconomyConfig, value: float) -> float:
	return clampf(value, cfg.price_min, cfg.price_max)
