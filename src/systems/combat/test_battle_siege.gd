extends GutTest
## Siege engines: deployed or packed, the target circle, flight time, area damage, reloading
## and the computer's use of them.

const EPSILON := 1e-6
const SEED := 1198

var _cfg: CombatConfig


func before_each() -> void:
	_cfg = CombatConfig.load_file()
	_cfg.battle.deploy_seconds = 0.0


func test_deployed_engine_stands_while_the_stick_moves_its_target_circle() -> void:
	var sim := _engine_against("spearmen", Vector2(200, 80))
	var start := sim.state.pos[0]
	var aim := sim.state.aim_point[0]
	_hold_stick(sim, Vector2.DOWN, 30)
	assert_eq(sim.state.pos[0], start, "a deployed engine does not move")
	var moved := sim.state.aim_point[0] - aim
	assert_almost_eq(moved.y, _cfg.battle.siege_aim_speed * 30 / _cfg.battle.tick_rate, EPSILON)


func test_packed_engine_drives_and_cannot_throw() -> void:
	var sim := _engine_against("spearmen", Vector2(200, 80))
	var pack := BattleInput.new()
	pack.formation = true
	sim.step(pack, BattleInput.new())
	var start := sim.state.pos[0]
	_hold_stick(sim, Vector2.DOWN, 30)
	assert_gt(sim.state.pos[0].y, start.y, "a packed engine drives")
	var attack := BattleInput.new()
	attack.attack = true
	sim.step(attack, BattleInput.new())
	assert_false(_has_event(sim, BattleEvent.Kind.SHOT), "a packed engine does not throw")
	assert_eq(sim.state.shot_timer[0], -1.0)


func test_target_circle_stays_within_range() -> void:
	var sim := _engine_against("spearmen", Vector2(200, 80))
	var aim := BattleInput.new()
	aim.command_point = true
	aim.point = Vector2(299, 80)
	sim.step(aim, BattleInput.new())
	var reach := sim.state.stats[0].attack_range
	assert_almost_eq(sim.state.pos[0].distance_to(sim.state.aim_point[0]), reach, EPSILON)


func test_stone_lands_after_its_flight_and_hits_every_figure_in_the_circle() -> void:
	var target_at := Vector2(200, 80)
	var sim := _engine_against("spearmen", target_at)
	var throw := BattleInput.new()
	throw.command_point = true
	throw.point = target_at
	throw.attack = true
	sim.step(throw, BattleInput.new())
	assert_true(_has_event(sim, BattleEvent.Kind.SHOT), "a loaded engine throws at once")
	var before := sim.state.hp[1]
	var flight := roundi(_cfg.battle.siege_flight_seconds * _cfg.battle.tick_rate)
	for i: int in flight - 1:
		sim.step(BattleInput.new(), BattleInput.new())
	assert_eq(sim.state.hp[1], before, "nothing hits before the stone lands")
	sim.step(BattleInput.new(), BattleInput.new())
	assert_true(_has_event(sim, BattleEvent.Kind.BLAST))
	# 60 - armor 3, all twelve spearmen stand inside the 6 m circle.
	assert_almost_eq(before - sim.state.hp[1], 57.0, EPSILON)


func test_half_a_company_in_the_circle_takes_half_the_damage() -> void:
	var target_at := Vector2(200, 80)
	var sim := _engine_against("spearmen", target_at)
	var throw := BattleInput.new()
	throw.command_point = true
	var figures := sim.state.fig_count[1]
	var reach := sim.state.stats[0].splash_radius
	# Aim beside the company so only the near half of its figures is inside.
	throw.point = target_at + Vector2(0, reach + 0.2)
	throw.attack = true
	var before := sim.state.hp[1]
	sim.step(throw, BattleInput.new())
	var inside := 0
	for k: int in figures:
		var at := sim.state.fig_pos[sim.state.fig_start[1] + k]
		if at.distance_to(sim.state.aim_point[0]) <= reach:
			inside += 1
	for i: int in roundi(_cfg.battle.siege_flight_seconds * _cfg.battle.tick_rate):
		sim.step(BattleInput.new(), BattleInput.new())
	assert_between(inside, 1, figures - 1, "the circle covers part of the company")
	assert_almost_eq(before - sim.state.hp[1], 57.0 * inside / figures, 0.01)


func test_engine_reloads_for_twenty_seconds() -> void:
	var sim := _engine_against("spearmen", Vector2(200, 80))
	var throw := BattleInput.new()
	throw.attack = true
	sim.step(throw, BattleInput.new())
	var shots := 1
	var reload_ticks := roundi(sim.state.stats[0].reload * _cfg.battle.tick_rate)
	for i: int in reload_ticks + 2:
		var again := BattleInput.new()
		again.attack = true
		sim.step(again, BattleInput.new())
		if _has_event(sim, BattleEvent.Kind.SHOT):
			shots += 1
			assert_gte(i, reload_ticks - 2, "the second stone waits for the reload")
	assert_eq(shots, 2)


func test_computer_deploys_its_engine_and_throws() -> void:
	var sim := _engine_against("spearmen", Vector2(200, 80))
	var ai := BattleAI.new(0, SEED)
	var thrown := false
	for i: int in 300:
		sim.step(ai.think(sim.state, sim.rules), BattleInput.new())
		thrown = thrown or _has_event(sim, BattleEvent.Kind.SHOT)
	assert_true(thrown)


func _engine_against(enemy: String, enemy_at: Vector2) -> BattleSim:
	var setup := BattleSetup.new()
	setup.attacker.add_company("trebuchet")
	setup.defender.add_company(enemy)
	var sim := BattleSim.new(_cfg, setup, SEED)
	BattleDeployment.place(sim.state, sim.rules, 0, Vector2(40, 80), 0.0)
	BattleDeployment.place(sim.state, sim.rules, 1, enemy_at, PI)
	return sim


func _hold_stick(sim: BattleSim, direction: Vector2, ticks: int) -> void:
	for i: int in ticks:
		var input := BattleInput.new()
		input.move = direction
		sim.step(input, BattleInput.new())


func _has_event(sim: BattleSim, kind: BattleEvent.Kind) -> bool:
	for event: BattleEvent in sim.state.events:
		if event.kind == kind:
			return true
	return false
