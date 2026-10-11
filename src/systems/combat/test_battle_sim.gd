extends GutTest
## Real-time battle simulation: charges, hedgehog, time limit, result order and replays.

const EPSILON := 1e-6
const MAX_TICKS := 900
const SEED := 1198

var _cfg: CombatConfig


func before_each() -> void:
	_cfg = CombatConfig.load_file()


func test_long_charge_hits_with_full_impact() -> void:
	var loss := _charge_loss(["crossbowmen"], 60.0, false)
	# (14 * 2 wedge * 2 charge - 1) * 3 s, plus one tick of melee (14 - 1) at standstill.
	assert_almost_eq(loss, 165.0 + 13.0 / 30.0, EPSILON)


func test_short_charge_lacks_runup() -> void:
	var loss := _charge_loss(["crossbowmen"], 16.0, false)
	assert_gt(loss, 1.0)
	assert_lt(loss, 165.0 * 0.6)


func test_hedgehog_halves_cavalry_damage() -> void:
	var line := _charge_loss(["spearmen"], 60.0, false)
	var hedgehog := _charge_loss(["spearmen"], 60.0, true)
	# Line: (56 - 3) * 3 + (14 - 3) / 30.
	assert_almost_eq(line, 159.0 + 11.0 / 30.0, EPSILON)
	assert_almost_eq(hedgehog, line / 2.0, EPSILON)


func test_time_limit_goes_to_the_stronger_side() -> void:
	_cfg.battle.deploy_seconds = 0.0
	_cfg.battle.time_limit_seconds = 1.0
	var sim := _timeout_sim(1.0, 0.5)
	assert_true(sim.is_over())
	assert_true(sim.state.timed_out)
	assert_true(sim.result().attacker_won)
	assert_false(_timeout_sim(0.5, 1.0).result().attacker_won)
	assert_false(_timeout_sim(1.0, 1.0).result().attacker_won, "a tie keeps the defender")


func test_result_follows_setup_order() -> void:
	_cfg.battle.deploy_seconds = 0.0
	var setup := BattleSetup.new()
	setup.attacker.add_company("spearmen", 1.0)
	setup.attacker.add_company("crossbowmen", 0.25)
	setup.attacker.add_company("knights", 0.5)
	setup.attacker.has_leader = true
	setup.defender.add_company("knights", 0.75)
	setup.defender.add_company("spearmen", 0.0)
	var sim := BattleSim.new(_cfg, setup, SEED)
	for i: int in 30:
		sim.step(BattleInput.new(), BattleInput.new())
	var result := sim.result()
	assert_eq(result.attacker_health, PackedFloat64Array([1.0, 0.25, 0.5]))
	assert_eq(result.defender_health, PackedFloat64Array([0.75, 0.0]))
	assert_almost_eq(result.duration, 1.0, EPSILON)
	assert_false(result.attacker_leader_captured)


func test_replay_gives_the_same_battle() -> void:
	var played := _play_ai(SEED)
	var sim: BattleSim = played["sim"]
	assert_true(sim.is_over(), "the battle ends")
	var limit := _cfg.battle.deploy_seconds + _cfg.battle.time_limit_seconds
	assert_lte(sim.result().duration, limit + EPSILON)
	var replayed := _replay(SEED, played["log"])
	assert_eq(replayed.state.checksum(), sim.state.checksum())
	_assert_same_result(replayed.result(), sim.result())
	var again: BattleSim = _play_ai(SEED)["sim"]
	assert_eq(again.state.checksum(), sim.state.checksum(), "the AI is deterministic too")


func test_seed_changes_the_battle() -> void:
	var a := BattleSim.new(_cfg, _cfg.battle.default_setup(), SEED)
	var b := BattleSim.new(_cfg, _cfg.battle.default_setup(), SEED + 1)
	assert_ne(a.state.checksum(), b.state.checksum())


## HP the defender's first company loses in the tick the attacker's knights hit it.
func _charge_loss(defender: Array[String], distance: float, hedgehog: bool) -> float:
	_cfg.battle.deploy_seconds = 0.0
	var setup := BattleSetup.new()
	setup.attacker.add_company("knights")
	for id: String in defender:
		setup.defender.add_company(id)
	var sim := BattleSim.new(_cfg, setup, SEED)
	BattleDeployment.place(sim.state, sim.rules, 0, Vector2(100, 90), 0.0)
	BattleDeployment.place(sim.state, sim.rules, 1, Vector2(100 + distance, 90), PI)
	var attack := BattleInput.new()
	attack.attack = true
	var defend := BattleInput.new()
	defend.formation = hedgehog
	var before := sim.state.hp[1]
	sim.step(attack, defend)
	for i: int in MAX_TICKS:
		for event: BattleEvent in sim.state.events:
			if event.kind == BattleEvent.Kind.IMPACT:
				return before - sim.state.hp[1]
		before = sim.state.hp[1]
		sim.step(BattleInput.new(), BattleInput.new())
	fail_test("no charge impact")
	return 0.0


func _timeout_sim(attacker_health: float, defender_health: float) -> BattleSim:
	var setup := BattleSetup.new()
	for i: int in 2:
		setup.attacker.add_company("spearmen", attacker_health)
		setup.defender.add_company("spearmen", defender_health)
	var sim := BattleSim.new(_cfg, setup, SEED)
	for i: int in MAX_TICKS:
		if sim.is_over():
			break
		sim.step(BattleInput.new(), BattleInput.new())
	return sim


func _play_ai(seed_value: int) -> Dictionary:
	var sim := BattleSim.new(_cfg, _cfg.battle.default_setup(), seed_value)
	var attacker := BattleAI.new(0, seed_value + 1)
	var defender := BattleAI.new(1, seed_value + 2)
	var log: Array[Array] = []
	var limit := _cfg.battle.deploy_ticks() + _cfg.battle.time_limit_ticks() + 1
	while not sim.is_over() and sim.state.tick < limit:
		var inputs: Array = [attacker.think(sim.state, sim.rules), defender.think(sim.state, sim.rules)]
		log.append(inputs)
		sim.step(inputs[0], inputs[1])
	return {"sim": sim, "log": log}


func _replay(seed_value: int, log: Array[Array]) -> BattleSim:
	var sim := BattleSim.new(_cfg, _cfg.battle.default_setup(), seed_value)
	for inputs: Array in log:
		sim.step(inputs[0], inputs[1])
	return sim


func _assert_same_result(a: BattleResult, b: BattleResult) -> void:
	assert_eq(a.attacker_won, b.attacker_won)
	assert_eq(a.attacker_health, b.attacker_health)
	assert_eq(a.defender_health, b.defender_health)
	assert_eq(a.attacker_leader_captured, b.attacker_leader_captured)
	assert_eq(a.defender_leader_captured, b.defender_leader_captured)
	assert_eq(a.duration, b.duration)
