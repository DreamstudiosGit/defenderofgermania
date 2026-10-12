extends GutTest
## Merchant train raid: rules of the leader and the escorts, the gate, replays, the computer
## raider's skills and the length of a raid.

const SEEDS := 12
const DEFAULT_ESCORTS := 1

var _cfg: MerchantConfig
var _combat: CombatConfig


func before_all() -> void:
	_cfg = MerchantConfig.load_file()
	_combat = CombatConfig.load_file()


func test_same_setup_seed_and_inputs_replay_identically() -> void:
	var setup := _setup(2, ["spearmen"])
	var first := _raid(setup, 7, 2)
	var second := _raid(setup, 7, 2)
	assert_eq(first.state.checksum(), second.state.checksum())
	assert_eq(first.result().taler, second.result().taler)
	assert_eq(first.result().seconds, second.result().seconds)


func test_cargo_is_fixed_by_the_seed_and_worth_30_to_40_taler() -> void:
	var seen: Dictionary[int, bool] = {}
	for seed_value: int in range(1, 21):
		var sim := MerchantSim.new(_cfg, _combat, _setup(1), seed_value)
		for value: int in sim.state.wagon_value:
			assert_between(value, 30, 40)
			seen[value] = true
		var again := MerchantSim.new(_cfg, _combat, _setup(1), seed_value)
		assert_eq(again.state.wagon_value, sim.state.wagon_value)
	assert_gt(seen.size(), 3, "seeds give different cargo")


func test_wagons_that_reach_the_gate_are_lost() -> void:
	var sim := _raid_scripted(_setup(0), func(_s: MerchantSim) -> MerchantInput: return null)
	var result := sim.result()
	assert_eq(result.wagons_stopped, 0)
	assert_eq(result.taler, 0)
	assert_false(result.leader_captured)
	assert_eq(sim.state.count_wagons(MerchantState.Wagon.ARRIVED), 5)
	assert_almost_eq(result.seconds, _cfg.train_seconds, 0.05, "the rear wagon is in at 90 s")


func test_a_pulled_driver_stops_his_wagon_and_its_cargo_pays() -> void:
	var sim := _after_intro(_setup(0))
	var rear := _cfg.wagons - 1
	sim.state.leader_x = sim.box_x(rear)
	var pull_ticks := ceili(_cfg.pull_seconds * sim.tick_rate)
	var hold := MerchantInput.new()
	hold.pull = true
	for i: int in pull_ticks - 2:
		sim.step(hold)
	assert_true(sim.state.is_rolling(rear), "pulling takes its time")
	for i: int in 3:
		sim.step(hold)
	assert_eq(sim.state.wagon_status[rear], MerchantState.Wagon.STOPPED)
	assert_eq(sim.state.wagon_stop[rear], MerchantState.Stop.DRIVER)
	for e: int in sim.state.escort_count():
		MerchantEscorts.knock_down(sim, e, MerchantState.LEADER)
		sim.state.escort_timer[e] = INF
	while not sim.is_over():
		sim.step(null)
	assert_eq(sim.result().wagons_stopped, 1)
	assert_eq(sim.result().taler, sim.state.wagon_value[rear])


func test_a_calm_aim_cuts_the_harness_and_a_swaying_one_misses() -> void:
	var hit := _aimed_shot(0.0)
	assert_eq(hit.state.wagon_stop[_cfg.wagons - 1], MerchantState.Stop.HARNESS)
	var miss := _aimed_shot(PI / 2)
	assert_true(miss.state.is_rolling(_cfg.wagons - 1))
	assert_eq(miss.state.bolts, _cfg.bolts - 1, "a miss costs a bolt")
	assert_eq(miss.state.reload, _cfg.reload_seconds)


func test_a_timely_parry_staggers_the_escort_and_a_missed_one_hurts() -> void:
	var parried := _blow_at_leader(true)
	assert_eq(parried.state.escort_state[0], MerchantState.Escort.STAGGERED)
	assert_eq(parried.state.composure, _cfg.composure)
	var hit := _blow_at_leader(false)
	assert_eq(hit.state.composure, _cfg.composure - 1)
	assert_gt(hit.state.stun, 0.0)


func test_the_shield_blocks_until_the_escort_opens_up() -> void:
	var sim := _after_intro(_setup(1))
	_place_escort(sim, MerchantState.Escort.COVER, 1.0)
	var strike := MerchantInput.new()
	strike.strike = true
	sim.step(strike)
	assert_eq(sim.state.escort_guard[0], sim.escort.guard, "blocked")
	sim.state.strike_cooldown = 0.0
	_place_escort(sim, MerchantState.Escort.STAGGERED, 1.0)
	sim.step(strike)
	assert_almost_eq(sim.state.escort_guard[0], sim.escort.guard - 2.0 * sim.strike_power(), 1e-9)


func test_blade_widens_the_parry_and_sharpens_the_strike() -> void:
	var dull := MerchantSim.new(_cfg, _combat, _setup(1, [], 1), 1)
	var sharp := MerchantSim.new(_cfg, _combat, _setup(1, [], 5), 1)
	assert_almost_eq(sharp.parry_window() - dull.parry_window(), 0.08, 1e-9)
	assert_almost_eq(dull.strike_power(), 1.1, 1e-9)
	assert_almost_eq(sharp.strike_power(), 1.5, 1e-9)


func test_a_skilled_raid_stops_most_wagons_and_a_careless_one_few() -> void:
	var skilled := 0.0
	var careless := 0.0
	for seed_value: int in range(1, SEEDS + 1):
		skilled += _raid(_setup(DEFAULT_ESCORTS), seed_value, 3).result().wagons_stopped
		var reckless := func(_s: MerchantSim) -> MerchantInput:
			var input := MerchantInput.new()
			input.move = 1.0
			input.pull = true
			return input
		var sim := MerchantSim.new(_cfg, _combat, _setup(DEFAULT_ESCORTS), seed_value)
		careless += _play(sim, reckless).result().wagons_stopped
	assert_gte(skilled / SEEDS, 4.0, "parrying, fighting and shooting pays")
	assert_lte(careless / SEEDS, 1.0, "grabbing past the escorts does not")


func test_companies_in_ambush_help() -> void:
	var alone := 0.0
	var helped := 0.0
	for seed_value: int in range(1, SEEDS + 1):
		alone += _raid(_setup(3), seed_value, 2).result().wagons_stopped
		helped += _raid(_setup(3, ["spearmen", "levy"]), seed_value, 2).result().wagons_stopped
	assert_gt(helped, alone + SEEDS * 0.5)


func test_computer_raider_skills_differ_clearly() -> void:
	var stopped: Array[float] = []
	for skill: int in MerchantConfig.SKILLS:
		var total := 0.0
		for seed_value: int in range(1, SEEDS + 1):
			total += _raid(_setup(DEFAULT_ESCORTS), seed_value, skill).result().wagons_stopped
		stopped.append(total / SEEDS)
	for skill: int in range(1, MerchantConfig.SKILLS):
		assert_gt(stopped[skill], stopped[skill - 1], str(stopped))
	assert_gt(stopped[3] - stopped[0], 3.0, str(stopped))


func test_a_raid_lasts_one_to_three_minutes() -> void:
	for skill: int in range(1, MerchantConfig.SKILLS):
		for seed_value: int in range(1, 7):
			var result := _raid(_setup(DEFAULT_ESCORTS), seed_value, skill).result()
			var total := _cfg.intro_seconds + result.seconds + _cfg.outro_seconds
			assert_between(total, 60.0, 180.0, "skill %d seed %d" % [skill, seed_value])
			assert_lte(result.seconds, _cfg.train_seconds + 0.05)


func test_a_captured_leader_brings_no_loot() -> void:
	var sim := _after_intro(_setup(1))
	sim.stop_wagon(_cfg.wagons - 1, MerchantState.Stop.DRIVER, MerchantState.LEADER)
	sim.state.composure = 1
	MerchantLeader.take_blow(sim, 0)
	sim.step(null)
	assert_true(sim.is_over())
	var result := sim.result()
	assert_true(result.leader_captured)
	assert_eq(result.wagons_stopped, 1)
	assert_eq(result.taler, 0)


func _setup(
	escort_skill: int, companies: Array[String] = [], blade: int = 2
) -> MerchantSetup:
	var setup := MerchantSetup.new()
	setup.escort_skill = escort_skill
	setup.companies = companies
	setup.blade = blade
	return setup


func _raid(setup: MerchantSetup, seed_value: int, skill: int) -> MerchantSim:
	var ai := MerchantAI.new(_cfg, skill)
	return _play(MerchantSim.new(_cfg, _combat, setup, seed_value), ai.think)


func _raid_scripted(setup: MerchantSetup, script: Callable) -> MerchantSim:
	return _play(MerchantSim.new(_cfg, _combat, setup, 1), script)


func _play(sim: MerchantSim, script: Callable) -> MerchantSim:
	var limit := sim.intro_ticks() + roundi(_cfg.train_seconds * sim.tick_rate) + 2
	while not sim.is_over() and sim.state.tick < limit:
		sim.step(script.call(sim) as MerchantInput)
	assert_true(sim.is_over(), "the raid ends by the time the gate closes")
	return sim


func _after_intro(setup: MerchantSetup) -> MerchantSim:
	var sim := MerchantSim.new(_cfg, _combat, setup, 1)
	while sim.state.phase == MerchantState.Phase.INTRO:
		sim.step(null)
	return sim


## Shoots at the rear wagon's horses with the sway at sin(phase) in the shot's tick.
func _aimed_shot(phase: float) -> MerchantSim:
	var sim := _after_intro(_setup(0))
	var rear := _cfg.wagons - 1
	sim.state.leader_x = sim.horses_x(rear) - (_cfg.range_min + _cfg.range_max) * 0.5
	var next_seconds := (sim.state.raid_ticks + 1) * sim.tick_seconds()
	sim.state.sway_phase = phase - TAU * next_seconds / _cfg.sway_period
	var shoot := MerchantInput.new()
	shoot.shoot = true
	sim.step(shoot)
	return sim


## Escort 0 winds up beside the leader; the blow lands in six ticks.
func _blow_at_leader(parry: bool) -> MerchantSim:
	var sim := _after_intro(_setup(1))
	_place_escort(sim, MerchantState.Escort.WINDUP, 0.2)
	var input := MerchantInput.new()
	input.parry = parry
	sim.step(input)
	for i: int in 8:
		sim.step(null)
	return sim


func _place_escort(sim: MerchantSim, state: MerchantState.Escort, timer: float) -> void:
	var s := sim.state
	s.escort_x[0] = s.leader_x + 1.5
	s.escort_state[0] = state
	s.escort_timer[0] = timer
	s.escort_target[0] = MerchantState.LEADER
	s.escort_guard[0] = sim.escort.guard
