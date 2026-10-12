extends GutTest
## Whole-battle scenarios for the rock-paper-scissors of the GDD: knight charges beat
## crossbows, the hedgehog stops knights, crossbows beat a spear line at range. Also the
## duration of computer battles (2–4 minutes of fighting).

const SEED := 1198
## A lane of the default field without obstacles between x 40 and 150.
const OPEN_FIELD_Y := 80.0

var _cfg: CombatConfig


func before_each() -> void:
	_cfg = CombatConfig.load_file()
	_cfg.battle.deploy_seconds = 0.0


func test_knight_charge_beats_crossbows() -> void:
	var sim := _scenario(["knights", "knights"], ["crossbowmen", "crossbowmen"], 70.0)
	var charge := BattleInput.new()
	charge.attack = true
	var staggered := BattleInput.new()
	staggered.formation = true
	_run(sim, [charge, staggered])
	assert_true(sim.is_over(), "the battle ends")
	assert_true(sim.result().attacker_won, "the knights win")
	assert_gt(_health(sim, 0), 0.75, "the knights stay mostly intact")


func test_hedgehog_stops_knights() -> void:
	var sim := _scenario(["knights", "knights"], ["spearmen", "spearmen"], 70.0)
	var charge := BattleInput.new()
	charge.attack = true
	var hedgehog := BattleInput.new()
	hedgehog.formation = true
	_run(sim, [charge, hedgehog])
	assert_true(sim.is_over(), "the battle ends")
	assert_false(sim.result().attacker_won, "the hedgehog holds")
	assert_gt(_health(sim, 1), _health(sim, 0), "the spearmen keep more of their strength")


func test_crossbows_beat_a_spear_line_at_range() -> void:
	var sim := _scenario(["crossbowmen", "crossbowmen"], ["spearmen", "spearmen"], 80.0)
	var staggered := BattleInput.new()
	staggered.formation = true
	_run(sim, [staggered, BattleInput.new()])
	assert_true(sim.is_over(), "the battle ends")
	assert_true(sim.result().attacker_won, "the crossbows win")
	assert_eq(_health(sim, 0), 1.0, "the spear line never reaches the crossbows")


func test_computer_battles_last_two_to_four_minutes() -> void:
	_cfg = CombatConfig.load_file()
	var limit := _cfg.battle.deploy_seconds + _cfg.battle.time_limit_seconds
	for seed_value: int in [1, 2, 3, 4]:
		var sim := BattleSim.new(_cfg, _cfg.battle.default_setup(), seed_value)
		var attacker := BattleAI.new(0, seed_value * 2)
		var defender := BattleAI.new(1, seed_value * 2 + 1)
		while not sim.is_over():
			sim.step(attacker.think(sim.state, sim.rules), defender.think(sim.state, sim.rules))
		var duration := sim.result().duration
		assert_between(duration, 120.0, limit + 1e-6, "seed %d lasts %.0f s" % [seed_value, duration])


## Attacker companies on the left facing right, defender companies the given distance ahead
## facing them, both in the open field without deployment time.
func _scenario(attacker: Array[String], defender: Array[String], distance: float) -> BattleSim:
	var setup := BattleSetup.new()
	for id: String in attacker:
		setup.attacker.add_company(id)
	for id: String in defender:
		setup.defender.add_company(id)
	var sim := BattleSim.new(_cfg, setup, SEED)
	var spacing := 22.0
	for i: int in attacker.size():
		var y := OPEN_FIELD_Y + (i - (attacker.size() - 1) * 0.5) * spacing
		BattleDeployment.place(sim.state, sim.rules, i, Vector2(60.0, y), 0.0)
	for i: int in defender.size():
		var y := OPEN_FIELD_Y + (i - (defender.size() - 1) * 0.5) * spacing
		var at := Vector2(60.0 + distance, y)
		BattleDeployment.place(sim.state, sim.rules, attacker.size() + i, at, PI)
	return sim


## First tick with the opening inputs, then no further commands until the battle ends.
func _run(sim: BattleSim, opening: Array[BattleInput]) -> void:
	sim.step(opening[0], opening[1])
	var limit := sim.rules.time_limit_ticks() + 1
	while not sim.is_over() and sim.state.tick < limit:
		sim.step(BattleInput.new(), BattleInput.new())


func _health(sim: BattleSim, side: int) -> float:
	var hp := 0.0
	var max_hp := 0.0
	for c: int in sim.state.company_count():
		if sim.state.side[c] == side:
			hp += sim.state.hp[c]
			max_hp += sim.state.max_hp[c]
	return hp / max_hp
