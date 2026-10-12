extends GutTest
## Whole castle raids: sneak paths, alarm and reinforcements, outcomes, replays and setups.

const SEED := 1198
const TICK_RATE := 30

var _cfg: RaidConfig


func before_each() -> void:
	_cfg = RaidConfig.load_file()


func test_same_setup_seed_and_inputs_replay_identically() -> void:
	var first := _ai_run(SEED, 2)
	var second := _ai_run(SEED, 2)
	assert_eq(first, second, "every tick's state matches")
	assert_ne(_ai_run(SEED + 1, 2), first, "another seed starts the patterns elsewhere")


func test_skilled_run_with_clean_parries_and_sneak_paths_succeeds_in_time() -> void:
	var setup := _setup(2, 3)
	var sim := RaidSim.new(_cfg, setup, SEED)
	var ai := RaidAI.new(_cfg, 3, SEED, _flawless())
	while not sim.is_over():
		sim.step(ai.think(sim))
	var result := sim.result()
	assert_true(result.success)
	assert_eq(result.outcome, RaidResult.Outcome.SUCCESS)
	assert_lt(result.time_used, _cfg.time_limit_seconds)
	assert_eq(result.guards_avoided, _cfg.castle(false, 3).sneak_paths, "every sneak path taken")
	assert_eq(result.target, "treasury")


func test_careless_run_without_parries_ends_in_the_dungeon() -> void:
	var sim := RaidSim.new(_cfg, _setup(2, 2), SEED)
	var input := RaidInput.new()
	input.move = 1.0
	input.strike = RaidFighter.Height.MID
	while not sim.is_over():
		sim.step(input)
	var result := sim.result()
	assert_false(result.success)
	assert_eq(result.outcome, RaidResult.Outcome.CAPTURED)


func test_sneak_path_passes_a_guard_unseen_but_takes_longer() -> void:
	var sim := RaidSim.new(_cfg, _setup(1, 2), _seed_with_first_post_path())
	var path := sim.layout.sneak_paths[0]
	_walk_to(sim, path.from_x)
	var act := RaidInput.new()
	act.act = true
	sim.step(act)
	assert_true(sim.state.is_sneaking())
	var forward := RaidInput.new()
	forward.move = 1.0
	var ticks := 0
	var engaged := false
	while sim.state.is_sneaking():
		sim.step(forward)
		ticks += 1
		engaged = engaged or sim.state.engaged
	assert_false(engaged, "nobody sees him on the sneak path")
	assert_almost_eq(ticks, roundi(_cfg.layout.sneak_seconds * TICK_RATE), 1)
	var walking := (path.to_x - path.from_x) / _cfg.walk_speed
	assert_gt(_cfg.layout.sneak_seconds, walking + 5.0, "sneaking costs time")
	assert_true(sim.state.guards[path.post].avoided)
	assert_eq(sim.state.leader.x, path.to_x)
	assert_eq(sim.result().guards_avoided, 1)


func test_alarm_sounds_after_60_seconds_and_brings_reinforcements() -> void:
	var sim := RaidSim.new(_cfg, _setup(1, 2), SEED)
	var posts := sim.state.guards.size()
	var alarm_tick := -1
	while sim.state.tick < 60 * TICK_RATE + 2 * TICK_RATE:
		sim.step(RaidInput.new())
		for event: RaidEvent in sim.state.events:
			if event.kind == RaidEvent.Kind.ALARM:
				alarm_tick = sim.state.tick
	assert_eq(alarm_tick, 60 * TICK_RATE)
	assert_true(sim.result().alarm_raised)
	assert_eq(sim.state.guards.size(), posts + 1, "the first reinforcement is in")
	var newcomer := sim.state.guards[posts]
	assert_true(newcomer.reinforcement)
	assert_lt(newcomer.x, sim.layout.end_x, "it marches towards the leader")
	var interval := roundi(_cfg.layout.reinforcement_interval_seconds * TICK_RATE)
	while sim.state.tick < 60 * TICK_RATE + interval:
		sim.step(RaidInput.new())
	assert_eq(sim.state.guards.size(), posts + _cfg.castle(false, 2).reinforcements)


func test_no_alarm_before_60_seconds() -> void:
	var sim := RaidSim.new(_cfg, _setup(1, 2), SEED)
	while sim.state.tick < 60 * TICK_RATE - 1:
		sim.step(RaidInput.new())
	assert_false(sim.state.alarm)


func test_time_runs_out_and_the_leader_slips_away_wounded() -> void:
	var sim := RaidSim.new(_cfg, _setup(1, 2), _seed_with_first_post_path())
	_walk_to(sim, sim.layout.sneak_paths[0].from_x)
	var act := RaidInput.new()
	act.act = true
	sim.step(act)
	while not sim.is_over():
		sim.step(RaidInput.new())
	var result := sim.result()
	assert_false(result.success)
	assert_eq(result.outcome, RaidResult.Outcome.ESCAPED_WOUNDED)
	assert_almost_eq(result.time_used, 120.0, 1e-6)


func test_giving_up_means_escaping_with_a_wound() -> void:
	var sim := RaidSim.new(_cfg, _setup(1, 2), SEED)
	var flee := RaidInput.new()
	flee.flee = true
	sim.step(flee)
	assert_true(sim.is_over())
	assert_eq(sim.result().outcome, RaidResult.Outcome.ESCAPED_WOUNDED)


func test_device_garbage_is_ignored() -> void:
	var sim := RaidSim.new(_cfg, _setup(1, 2), SEED)
	var input := RaidInput.new()
	input.move = INF
	input.strike = 7
	input.parry = -3
	sim.step(input)
	assert_eq(sim.state.leader.x, RaidLayout.START_X)
	assert_eq(sim.state.leader.action, RaidFighter.Action.READY)


func test_broken_setup_is_refused() -> void:
	var setup := _setup(1, 0)
	setup.blade = 9
	setup.target = "kitchen"
	var sim := RaidSim.new(_cfg, setup, SEED)
	assert_true(sim.is_over())
	assert_eq(sim.errors.size(), 3)
	assert_false(sim.result().success)
	assert_push_error("blade must be")
	assert_push_error("unknown target")
	assert_push_error("no raid rules for castle level 0")


func test_a_house_cannot_raid_itself() -> void:
	var setup := _setup(1, 2)
	setup.defender_owner = setup.raider_house
	assert_eq(setup.validate(_cfg).size(), 1)


func _setup(guard_skill: int, level: int) -> RaidSetup:
	var setup := RaidSetup.new()
	setup.guard_skill = guard_skill
	setup.castle_level = level
	setup.blade = 3
	return setup


func _flawless() -> RaidRules.AiSkill:
	var skill := RaidRules.AiSkill.new()
	skill.parries = PackedInt32Array([RaidAI.OK])
	skill.reads_stance = true
	skill.strikes = PackedInt32Array([0, 1, 2])
	skill.riposte = true
	skill.sneaks.assign([true])
	return skill


func _ai_run(seed_value: int, ai_skill: int) -> Array[int]:
	var sim := RaidSim.new(_cfg, _setup(2, 2), seed_value)
	var ai := RaidAI.new(_cfg, ai_skill, seed_value)
	var checksums: Array[int] = []
	while not sim.is_over():
		sim.step(ai.think(sim))
		checksums.append(sim.state.checksum())
	return checksums


func _walk_to(sim: RaidSim, x: float) -> void:
	var walk := RaidInput.new()
	walk.move = 1.0
	while sim.state.leader.x < x - 0.05 and sim.state.tick < 30 * TICK_RATE:
		sim.step(walk)
	assert_almost_eq(sim.state.leader.x, x, 0.2, "walked to %.1f" % x)


## A seed whose first sneak path leads round the first guard, so nobody blocks the way there.
func _seed_with_first_post_path() -> int:
	for seed_value: int in range(SEED, SEED + 50):
		if RaidSim.new(_cfg, _setup(1, 2), seed_value).layout.sneak_paths[0].post == 0:
			return seed_value
	fail_test("no seed puts a sneak path at the first post")
	return SEED
