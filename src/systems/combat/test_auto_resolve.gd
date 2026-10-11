extends GutTest

const EPSILON := 1e-9

var _cfg: CombatConfig


func before_all() -> void:
	_cfg = CombatConfig.load_file()


func test_combat_file_loads() -> void:
	assert_not_null(_cfg)


func test_start_army_strength() -> void:
	var army := _side(["levy", "levy", "spearmen", "spearmen"], true, 3)
	var levy := _side(["levy"])
	var morale := AutoResolve.morale(_cfg, army, false)
	# Average morale 50 + 5 per leadership point.
	assert_almost_eq(morale, 65.0, EPSILON)
	# (1 + 1 + 2 + 2 + leader 2) * (1 + 0.05 * 3) * (0.5 + 65 / 200)
	assert_almost_eq(AutoResolve.strength(_cfg, army, levy, 1.0, morale), 7.59, EPSILON)


func test_strength_scales_with_health() -> void:
	var full := _side(["spearmen"])
	var hurt := _side(["spearmen"])
	hurt.health[0] = 0.5
	var enemy := _side(["levy"])
	var k_full := AutoResolve.strength(_cfg, full, enemy, 1.0, 60.0)
	assert_almost_eq(AutoResolve.strength(_cfg, hurt, enemy, 1.0, 60.0), k_full / 2.0, EPSILON)


func test_morale_modifiers() -> void:
	var spearmen := _side(["spearmen"])
	assert_almost_eq(AutoResolve.morale(_cfg, spearmen, true), 45.0, EPSILON)
	spearmen.morale_bonus = _cfg.morale_leader_captured
	assert_almost_eq(AutoResolve.morale(_cfg, spearmen, false), 50.0, EPSILON)


func test_defender_terrain_and_walls() -> void:
	var setup := BattleSetup.new()
	setup.terrain = "hills"
	assert_almost_eq(AutoResolve.terrain_factor(_cfg, setup), 1.15, EPSILON)
	setup.defender_wall = 3
	assert_almost_eq(AutoResolve.terrain_factor(_cfg, setup), 1.75, EPSILON)
	setup.terrain = "farmland"
	setup.defender_wall = 0
	assert_eq(AutoResolve.terrain_factor(_cfg, setup), 1.0)


func test_counter_bonus_per_pairing_with_cap() -> void:
	var spearmen := _side(["spearmen", "spearmen"])
	var knights := _side(["knights", "knights"])
	assert_almost_eq(AutoResolve.counter_bonus(_cfg, spearmen, knights), 0.1, EPSILON)
	assert_eq(AutoResolve.counter_bonus(_cfg, knights, spearmen), 0.0)
	var mixed := _side(["levy", "crossbowmen"])
	assert_almost_eq(AutoResolve.counter_bonus(_cfg, knights, mixed), 0.2, EPSILON)
	var heavy := _side(["knights", "brabanters"])
	var line := _side(["levy", "spearmen", "crossbowmen"])
	assert_almost_eq(AutoResolve.counter_bonus(_cfg, heavy, line), 0.3, EPSILON)


func test_win_chance() -> void:
	assert_almost_eq(AutoResolve.win_chance(_cfg, 5.0, 5.0), 0.5, EPSILON)
	var expected := pow(2.0, 1.5) / (pow(2.0, 1.5) + 1.0)
	assert_almost_eq(AutoResolve.win_chance(_cfg, 2.0, 1.0), expected, EPSILON)
	assert_eq(AutoResolve.win_chance(_cfg, 3.0, 0.0), 1.0)


func test_human_side_counts_ten_percent_less() -> void:
	var ai := _side(["knights"])
	var human := _side(["knights"])
	human.is_human = true
	var enemy := _side(["levy"])
	var k_ai := AutoResolve.strength(_cfg, ai, enemy, 1.0, 80.0)
	assert_almost_eq(AutoResolve.strength(_cfg, human, enemy, 1.0, 80.0), k_ai * 0.9, EPSILON)


func test_winner_loss_is_clamped() -> void:
	assert_almost_eq(AutoResolve.winner_loss(_cfg, 10.0, 5.0), 0.15, EPSILON)
	assert_almost_eq(AutoResolve.winner_loss(_cfg, 10.0, 0.1), 0.05, EPSILON)
	assert_almost_eq(AutoResolve.winner_loss(_cfg, 1.0, 10.0), 0.7, EPSILON)


func test_resolve_applies_losses_to_every_company() -> void:
	var setup := _setup(["knights", "knights", "spearmen"], ["levy", "levy"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var result := AutoResolve.resolve(_cfg, setup, rng)
	var loser := result.defender_health if result.attacker_won else result.attacker_health
	var winner := result.attacker_health if result.attacker_won else result.defender_health
	for value: float in loser:
		assert_between(value, 1.0 - _cfg.loser_loss_max, 1.0 - _cfg.loser_loss_min)
	for value: float in winner:
		assert_between(value, 1.0 - _cfg.winner_loss_max, 1.0 - _cfg.winner_loss_min)
	assert_eq(result.attacker_health.size(), 3)
	assert_eq(result.defender_health.size(), 2)


func test_resolve_is_deterministic_for_a_seed() -> void:
	var first := _resolve_with_seed(99)
	var second := _resolve_with_seed(99)
	assert_eq(first.attacker_won, second.attacker_won)
	assert_eq(first.attacker_health, second.attacker_health)
	assert_eq(first.defender_health, second.defender_health)


func test_win_rate_follows_win_chance() -> void:
	var setup := _setup(["knights", "spearmen"], ["levy", "levy", "levy"])
	var k := AutoResolve.strengths(_cfg, setup)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var wins := 0
	var trials := 4000
	for i: int in trials:
		if AutoResolve.resolve(_cfg, setup, rng).attacker_won:
			wins += 1
	assert_almost_eq(float(wins) / trials, AutoResolve.win_chance(_cfg, k[0], k[1]), 0.03)


func test_unopposed_attacker_wins_without_losses() -> void:
	var setup := _setup(["levy"], [])
	var result := AutoResolve.resolve(_cfg, setup, RandomNumberGenerator.new())
	assert_true(result.attacker_won)
	assert_eq(result.attacker_health, PackedFloat64Array([1.0]))


func _resolve_with_seed(seed_value: int) -> BattleResult:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return AutoResolve.resolve(_cfg, _setup(["knights", "levy"], ["spearmen", "spearmen"]), rng)


func _setup(attacker: Array[String], defender: Array[String]) -> BattleSetup:
	var setup := BattleSetup.new()
	setup.attacker = _side(attacker, true, 2)
	setup.defender = _side(defender)
	return setup


func _side(units: Array[String], has_leader: bool = false, leadership: int = 0) -> BattleSide:
	var side := BattleSide.new()
	for id: String in units:
		side.add_company(id)
	side.has_leader = has_leader
	side.leadership = leadership
	return side
