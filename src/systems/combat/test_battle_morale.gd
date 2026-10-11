extends GutTest
## Morale rules of the real-time battle: start value, HP loss, flank shock, flight, rally,
## leader aura and captured leader.

const EPSILON := 1e-6
const MAX_TICKS := 600

var _cfg: CombatConfig


func before_each() -> void:
	_cfg = CombatConfig.load_file()
	_cfg.battle.deploy_seconds = 0.0


func test_start_morale_adds_five_per_leadership() -> void:
	var sim := _sim(["spearmen", "crossbowmen"], ["spearmen"], true)
	assert_almost_eq(sim.state.start_morale[0], 75.0, EPSILON)
	assert_almost_eq(sim.state.start_morale[1], 65.0, EPSILON)
	assert_almost_eq(_sim(["spearmen"], ["spearmen"], false).state.start_morale[0], 60.0, EPSILON)


func test_morale_drops_one_per_two_percent_hp() -> void:
	var sim := _sim(["spearmen"], ["spearmen"], false)
	sim.state.hp[0] = sim.state.max_hp[0] * 0.9
	assert_almost_eq(BattleMorale.value(sim.state, sim.rules, 0), 55.0, EPSILON)
	sim.state.hp[0] = sim.state.max_hp[0] * 0.5
	assert_almost_eq(BattleMorale.value(sim.state, sim.rules, 0), 35.0, EPSILON)


func test_attack_into_the_rear_shocks_once() -> void:
	var sim := _sim(["spearmen"], ["spearmen"], false)
	_place(sim, 0, Vector2(130, 90), 0.0)
	_place(sim, 1, Vector2(145, 90), 0.0)
	_charge_until_contact(sim)
	assert_almost_eq(sim.state.shock[1], -15.0, EPSILON)
	assert_almost_eq(sim.state.shock[0], 0.0, EPSILON)
	_idle(sim, 60)
	assert_almost_eq(sim.state.shock[1], -15.0, EPSILON, "only once per engagement")


func test_frontal_attack_has_no_shock() -> void:
	var sim := _sim(["spearmen"], ["spearmen"], false)
	_place(sim, 0, Vector2(130, 90), 0.0)
	_place(sim, 1, Vector2(145, 90), PI)
	_charge_until_contact(sim)
	assert_almost_eq(sim.state.shock[1], 0.0, EPSILON)


func test_company_flees_below_twenty() -> void:
	var sim := _sim(["spearmen", "spearmen"], ["spearmen"], false)
	sim.state.shock[0] = -40.0
	sim.state.shock[1] = -41.0
	_idle(sim, 1)
	assert_eq(sim.state.status[0], BattleState.Status.ACTIVE, "exactly 20 holds")
	assert_eq(sim.state.status[1], BattleState.Status.FLEEING)
	assert_true(_has_event(sim, BattleEvent.Kind.ROUT))
	_idle(sim, 30)
	assert_lt(sim.state.pos[1].x, sim.state.pos[0].x, "flees towards the own (left) edge")


func test_leader_aura_reaches_thirty_meters() -> void:
	var sim := _sim(["spearmen", "spearmen"], ["spearmen"], true)
	var leader := sim.state.leader[0]
	_place(sim, leader, Vector2(100, 90), 0.0)
	_place(sim, 0, Vector2(129, 90), 0.0)
	_place(sim, 1, Vector2(131, 90), 0.0)
	assert_eq(BattleMorale.aura(sim.state, 0), 15.0)
	assert_eq(BattleMorale.aura(sim.state, 1), 0.0)


func test_rally_brings_back_fleeing_companies_in_radius() -> void:
	var sim := _sim(["spearmen", "spearmen"], ["spearmen"], true)
	var state := sim.state
	var leader := state.leader[0]
	_place(sim, leader, Vector2(100, 90), 0.0)
	_place(sim, 0, Vector2(120, 90), 0.0)
	_place(sim, 1, Vector2(100, 121), 0.0)
	for c: int in [0, 1]:
		state.status[c] = BattleState.Status.FLEEING
		state.shock[c] = -50.0
	var input := BattleInput.new()
	input.rally = true
	sim.step(input, BattleInput.new())
	assert_eq(state.status[0], BattleState.Status.ACTIVE)
	assert_eq(state.status[1], BattleState.Status.FLEEING, "31 m away is out of reach")
	assert_almost_eq(BattleMorale.value(state, sim.rules, 0) - BattleMorale.aura(state, 0), 40.0, 0.1)
	assert_almost_eq(state.rally_cooldown[0], 45.0 - sim.tick_seconds(), EPSILON)
	_place(sim, 1, Vector2(110, 90), 0.0)
	assert_eq(BattleMorale.rally(state, sim.rules, 0), 0, "still cooling down")
	state.rally_cooldown[0] = 0.0
	assert_eq(BattleMorale.rally(state, sim.rules, 0), 1)


func test_captured_leader_shocks_the_army() -> void:
	var sim := _sim(["spearmen", "crossbowmen"], ["spearmen"], true)
	var state := sim.state
	var leader := state.leader[0]
	var damage := PackedFloat64Array()
	damage.resize(state.company_count())
	damage[leader] = state.hp[leader] + 1.0
	BattleMorale.update(state, sim.rules, damage, sim.tick_seconds())
	assert_eq(state.status[leader], BattleState.Status.CAPTURED)
	assert_almost_eq(state.shock[0], -20.0, EPSILON)
	assert_almost_eq(state.shock[1], -20.0, EPSILON)
	assert_almost_eq(state.shock[2], 0.0, EPSILON, "the enemy is not shocked")
	assert_true(_has_event(sim, BattleEvent.Kind.LEADER_CAPTURED))
	assert_true(sim.result().attacker_leader_captured)


func _sim(attacker: Array[String], defender: Array[String], leaders: bool) -> BattleSim:
	var setup := BattleSetup.new()
	for id: String in attacker:
		setup.attacker.add_company(id)
	for id: String in defender:
		setup.defender.add_company(id)
	for side: BattleSide in [setup.attacker, setup.defender]:
		side.has_leader = leaders
		side.leadership = 3
	return BattleSim.new(_cfg, setup, 1)


func _place(sim: BattleSim, company: int, at: Vector2, angle: float) -> void:
	BattleDeployment.place(sim.state, sim.rules, company, at, angle)


## The attacker's active group attacks, then both sides idle until it is in melee.
func _charge_until_contact(sim: BattleSim) -> void:
	var attack := BattleInput.new()
	attack.attack = true
	sim.step(attack, BattleInput.new())
	for i: int in MAX_TICKS:
		if sim.state.contact[0] >= 0:
			break
		sim.step(BattleInput.new(), BattleInput.new())
	assert_true(sim.state.contact[0] >= 0, "reached melee")


func _idle(sim: BattleSim, ticks: int) -> void:
	for i: int in ticks:
		sim.step(BattleInput.new(), BattleInput.new())


func _has_event(sim: BattleSim, kind: BattleEvent.Kind) -> bool:
	for event: BattleEvent in sim.state.events:
		if event.kind == kind:
			return true
	return false
