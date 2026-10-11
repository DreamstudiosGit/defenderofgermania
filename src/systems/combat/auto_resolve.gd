class_name AutoResolve
extends RefCounted
## Auto-resolve from docs/design/combat.md: combat strength K, win chance and losses.
## strengths() without chance is also the real-time battle's tiebreak at the time limit.


static func resolve(
	cfg: CombatConfig, setup: BattleSetup, rng: RandomNumberGenerator
) -> BattleResult:
	var result := BattleResult.new()
	result.attacker_health = setup.attacker.health.duplicate()
	result.defender_health = setup.defender.health.duplicate()
	if setup.defender.company_count() == 0 and not setup.defender.has_leader:
		result.attacker_won = true
		return result
	var k := strengths(cfg, setup)
	result.attacker_won = rng.randf() < win_chance(cfg, k[0], k[1])
	var loser_loss := rng.randf_range(cfg.loser_loss_min, cfg.loser_loss_max)
	if result.attacker_won:
		result.attacker_health = _after_loss(result.attacker_health, winner_loss(cfg, k[0], k[1]))
		result.defender_health = _after_loss(result.defender_health, loser_loss)
	else:
		result.attacker_health = _after_loss(result.attacker_health, loser_loss)
		result.defender_health = _after_loss(result.defender_health, winner_loss(cfg, k[1], k[0]))
	return result


## [attacker K, defender K] for the current health of both sides.
static func strengths(cfg: CombatConfig, setup: BattleSetup) -> PackedFloat64Array:
	var attacker_morale := morale(cfg, setup.attacker, setup.is_winter)
	var defender_morale := morale(cfg, setup.defender, false)
	var attacker := strength(cfg, setup.attacker, setup.defender, 1.0, attacker_morale)
	var defender := strength(
		cfg, setup.defender, setup.attacker, terrain_factor(cfg, setup), defender_morale
	)
	return PackedFloat64Array([attacker, defender])


static func strength(
	cfg: CombatConfig, side: BattleSide, enemy: BattleSide, terrain: float, side_morale: float
) -> float:
	var base := 0.0
	for i: int in side.company_count():
		base += cfg.units[side.units[i]].auto_resolve * side.health[i]
	var leadership := 0
	if side.has_leader:
		base += cfg.units["leader"].auto_resolve
		leadership = side.leadership
	var k := (
		base
		* (1.0 + cfg.leadership_bonus * leadership)
		* (cfg.morale_base + side_morale / cfg.morale_divisor)
		* terrain
		* (1.0 + counter_bonus(cfg, side, enemy))
	)
	return k * (1.0 - cfg.human_malus) if side.is_human else k


## Average unit morale plus leadership and side modifiers; attackers lose some in winter.
static func morale(cfg: CombatConfig, side: BattleSide, is_winter_attacker: bool) -> float:
	if side.company_count() == 0:
		return 0.0
	var total := 0.0
	for id: String in side.units:
		total += cfg.units[id].morale
	var value := total / side.company_count() + side.morale_bonus
	if side.has_leader:
		value += cfg.morale_per_leadership * side.leadership
	if is_winter_attacker:
		value *= cfg.winter_attack_morale_multiplier
	return maxf(value, 0.0)


## Applies to the defender only: castle walls beat terrain, otherwise the terrain table.
static func terrain_factor(cfg: CombatConfig, setup: BattleSetup) -> float:
	if setup.defender_wall > 0:
		return 1.0 + cfg.castle_per_wall * setup.defender_wall
	return cfg.terrain_defender.get(setup.terrain, 1.0)


## +counter_bonus for every (own unit type, enemy unit type) pair the own type is strong against.
static func counter_bonus(cfg: CombatConfig, side: BattleSide, enemy: BattleSide) -> float:
	var pairs := 0
	for own: String in _unit_types(side):
		for other: String in _unit_types(enemy):
			if other in cfg.units[own].strong_against:
				pairs += 1
	return minf(cfg.counter_bonus * pairs, cfg.counter_max)


static func win_chance(cfg: CombatConfig, k_a: float, k_b: float) -> float:
	var a := pow(k_a, cfg.exponent)
	var b := pow(k_b, cfg.exponent)
	return 0.5 if a + b <= 0.0 else a / (a + b)


## Share of HP the winner loses; the closer the fight, the higher.
static func winner_loss(cfg: CombatConfig, k_winner: float, k_loser: float) -> float:
	if k_winner <= 0.0:
		return cfg.winner_loss_max
	return clampf(
		cfg.winner_loss_factor * k_loser / k_winner, cfg.winner_loss_min, cfg.winner_loss_max
	)


static func _after_loss(health: PackedFloat64Array, loss: float) -> PackedFloat64Array:
	var result := PackedFloat64Array()
	for value: float in health:
		result.append(value * (1.0 - loss))
	return result


static func _unit_types(side: BattleSide) -> Array[String]:
	var types: Array[String] = []
	for id: String in side.units:
		if id not in types:
			types.append(id)
	return types
