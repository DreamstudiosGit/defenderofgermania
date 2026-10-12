extends GutTest
## The trebuchet minigame played headless: shots and counterfire, determinism, breaches from
## good aim, fire pots against the garrison and wood, and damage carried into a second round.

var _cfg: SiegeConfig


func before_all() -> void:
	_cfg = SiegeConfig.load_file()


func test_one_trebuchet_throws_five_shots() -> void:
	var sim := TrebuchetSim.new(_cfg, _setup("province_2", 2), 1)
	_play(sim, func(_s: TrebuchetSim) -> TrebuchetShot: return _short())
	var result := sim.result()
	assert_eq(result.shots_fired, 5)
	assert_eq(result.shots_lost, 0)
	assert_false(result.breach)
	assert_eq(result.wall_damage, 0.0, "stones that fall short do no harm")


func test_counterfire_costs_every_third_shot_from_wall_three() -> void:
	var one := TrebuchetSim.new(_cfg, _setup("province_3", 3, 1), 1)
	_play(one, func(_s: TrebuchetSim) -> TrebuchetShot: return _short())
	assert_eq(one.result().shots_fired, 4, "5 shots, the third lost")
	assert_eq(one.result().shots_lost, 1)
	var two := TrebuchetSim.new(_cfg, _setup("province_3", 3, 2), 1)
	assert_eq(two.shots_left(), 5, "7 shots, the third and sixth lost")
	_play(two, func(_s: TrebuchetSim) -> TrebuchetShot: return _short())
	assert_eq(two.result().shots_fired, 5)
	assert_eq(two.result().shots_lost, 2)


func test_same_seed_and_inputs_give_the_same_siege() -> void:
	var results: Array[TrebuchetResult] = []
	var hp: Array[PackedInt32Array] = []
	var winds: Array[PackedFloat64Array] = []
	for run: int in 2:
		var sim := TrebuchetSim.new(_cfg, _setup("home_3", 3, 2), 77)
		var aimer := TrebuchetAimer.new(_cfg, 1)
		var seen := PackedFloat64Array()
		while not sim.is_over():
			seen.append(sim.wind())
			if sim.is_counterfire_slot():
				sim.endure_counterfire()
			else:
				sim.fire(aimer.aim(sim))
		results.append(sim.result())
		hp.append(sim.castle.hp)
		winds.append(seen)
	assert_eq(winds[0], winds[1])
	assert_eq(hp[0], hp[1])
	assert_eq(results[0].breach, results[1].breach)
	assert_eq(results[0].wall_damage, results[1].wall_damage)
	assert_eq(results[0].hits, results[1].hits)
	assert_eq(results[0].duration_seconds, results[1].duration_seconds)


func test_wind_comes_from_the_seed_within_its_range() -> void:
	var differs := false
	var first := TrebuchetSim.new(_cfg, _setup("province_2", 2), 1).wind()
	for seed_value: int in range(2, 12):
		var wind := TrebuchetSim.new(_cfg, _setup("province_2", 2), seed_value).wind()
		assert_between(wind, _cfg.wind_min, _cfg.wind_max)
		differs = differs or wind != first
	assert_true(differs, "different seeds blow different winds")


func test_well_aimed_stones_breach_wall_one_and_two() -> void:
	for case: Array in [["province_1", 1], ["home_1", 1], ["province_2", 2], ["home_2", 2]]:
		var sim := TrebuchetSim.new(_cfg, _setup(case[0], case[1]), 5)
		_play(sim, _at_gate)
		var result := sim.result()
		assert_true(result.breach, "%s wall %d" % case)
		assert_eq(result.breach_kind, "gate")
		assert_eq(result.breach_part, "gate")
		assert_lt(result.shots_fired, 5, "a breach ends the bombardment early")


func test_poorly_aimed_stones_do_not_breach() -> void:
	for case: Array in [["province_1", 1], ["province_2", 2]]:
		var sim := TrebuchetSim.new(_cfg, _setup(case[0], case[1]), 5)
		_play(sim, func(_s: TrebuchetSim) -> TrebuchetShot: return TrebuchetShot.make(100, 45))
		assert_false(sim.result().breach, "stones flying over the castle")
		assert_eq(sim.result().shots_fired, 5)


func test_a_stone_deals_240_to_the_part_it_hits() -> void:
	var sim := TrebuchetSim.new(_cfg, _setup("province_3", 3), 5)
	var gate := sim.castle.index_of("gate")
	var report := sim.fire(_at_gate(sim))
	assert_eq(report.impact.part, gate)
	assert_true(report.hit)
	assert_eq(sim.castle.hp[gate], sim.castle.max_hp[gate] - 240)
	assert_almost_eq(sim.result().wall_damage, 240.0 / 1200.0, 1e-9)


func test_fire_pots_wear_the_garrison_down() -> void:
	var sim := TrebuchetSim.new(_cfg, _setup("province_3", 3), 5)
	_play(sim, func(s: TrebuchetSim) -> TrebuchetShot: return _fire_pot_at_gate(s))
	var result := sim.result()
	assert_eq(result.hits, 4, "every fire pot lands in the castle")
	assert_almost_eq(result.garrison_damage, 4 * 0.08, 1e-9)
	assert_almost_eq(sim.garrison_health, 1.0 - 4 * 0.08, 1e-9)
	assert_false(result.breach, "fire does not break stone")


func test_garrison_cannot_lose_more_than_it_has() -> void:
	var setup := _setup("province_2", 2)
	setup.garrison_health = 0.1
	var sim := TrebuchetSim.new(_cfg, setup, 5)
	_play(sim, func(s: TrebuchetSim) -> TrebuchetShot: return _fire_pot_at_gate(s))
	assert_almost_eq(sim.result().garrison_damage, 0.1, 1e-9)
	assert_eq(sim.garrison_health, 0.0)


func test_a_burning_wooden_gate_burns_down_into_a_breach() -> void:
	var sim := TrebuchetSim.new(_cfg, _setup("home_2", 2), 5)
	var gate := sim.castle.index_of("gate")
	var report := sim.fire(_fire_pot_at_gate(sim))
	assert_eq(report.impact.part, gate)
	assert_eq(sim.castle.burning[gate], 1)
	assert_true(_has(report.events, SiegeEvent.Kind.IGNITED))
	_play(sim, func(_s: TrebuchetSim) -> TrebuchetShot: return _short())
	var result := sim.result()
	assert_true(result.breach, "the gate burns down while the stones fall short")
	assert_eq(result.breach_part, "gate")
	assert_eq(sim.castle.causes[gate], SiegeEvent.Cause.BURNT)
	assert_eq(result.shots_fired, 3, "it burns 34 % a shot, starting with the shot that lit it")


func test_second_round_starts_from_the_earlier_damage() -> void:
	var first := TrebuchetSim.new(_cfg, _setup("province_3", 3), 5)
	first.fire(_at_gate(first))
	_play(first, func(_s: TrebuchetSim) -> TrebuchetShot: return _short())
	var after_first := first.result()
	assert_false(after_first.breach)
	assert_almost_eq(after_first.wall_damage, 0.2, 1e-9)
	var setup := _setup("province_3", 3)
	setup.wall_damage = after_first.wall_damage
	var second := TrebuchetSim.new(_cfg, setup, 6)
	var gate := second.castle.index_of("gate")
	assert_eq(second.castle.hp[gate], roundi(second.castle.max_hp[gate] * 0.8), "spread evenly")
	assert_eq(second.result().wall_damage, 0.2, "no hits keep the damage as it was")
	second.fire(_at_gate(second))
	var result := second.result()
	assert_almost_eq(result.wall_damage_dealt, 240.0 / 1200.0, 1e-9)
	assert_almost_eq(result.wall_damage, 0.4, 1e-9, "earlier plus new damage")
	assert_true(_play_to_breach(second), "the weakened gate gives way sooner")


func test_wall_destroyed_earlier_is_breached_from_the_start() -> void:
	var setup := _setup("province_2", 2)
	setup.wall_damage = 1.0
	var sim := TrebuchetSim.new(_cfg, setup, 5)
	assert_true(sim.is_over())
	assert_true(sim.result().breach)
	assert_eq(sim.result().shots_fired, 0)
	assert_eq(sim.result().wall_damage, 1.0)


func test_aim_outside_the_trebuchets_range_is_clamped() -> void:
	var sim := TrebuchetSim.new(_cfg, _setup("province_2", 2), 5)
	var shot := sim.sanitized(TrebuchetShot.make(250, 5, TrebuchetShot.Projectile.STONE, 99.0))
	assert_eq(shot.counterweight, _cfg.counterweight_max)
	assert_eq(shot.angle, _cfg.angle_min)
	assert_eq(shot.aim_seconds, _cfg.aim_limit_seconds)


func test_invalid_setup_ends_at_once() -> void:
	var setup := _setup("province_2", 2)
	setup.trebuchets = 0
	var sim := TrebuchetSim.new(_cfg, setup, 5)
	assert_push_error("needs at least one trebuchet")
	assert_true(sim.is_over())
	assert_false(sim.result().breach)
	assert_eq(sim.result().shots_fired, 0)


func _setup(layout: String, wall: int, trebuchets: int = 1) -> TrebuchetSetup:
	var setup := _cfg.practice.duplicate_setup()
	setup.is_practice = false
	setup.is_home_castle = layout.begins_with("home")
	setup.castle_level = int(layout.get_slice("_", 1))
	setup.wall_level = wall
	setup.trebuchets = trebuchets
	assert_eq(setup.layout_key(), layout)
	return setup


func _at_gate(sim: TrebuchetSim) -> TrebuchetShot:
	return TrebuchetAimer.new(_cfg, 3).aim(sim)


func _fire_pot_at_gate(sim: TrebuchetSim) -> TrebuchetShot:
	var rect := sim.castle.world_rect(sim.castle.index_of("gate"))
	var kind := TrebuchetShot.Projectile.FIRE_POT
	var weight := TrebuchetAimer.solve(_cfg, 45, sim.wind(), rect[0], rect[3] * 0.5, kind)
	return TrebuchetShot.make(weight, 45, kind)


func _short() -> TrebuchetShot:
	return TrebuchetShot.make(0, 45)


func _play(sim: TrebuchetSim, aim: Callable) -> void:
	while not sim.is_over():
		if sim.is_counterfire_slot():
			sim.endure_counterfire()
		else:
			sim.fire(aim.call(sim) as TrebuchetShot)


func _play_to_breach(sim: TrebuchetSim) -> bool:
	_play(sim, _at_gate)
	return sim.result().breach


static func _has(events: Array[SiegeEvent], kind: SiegeEvent.Kind) -> bool:
	return events.any(func(event: SiegeEvent) -> bool: return event.kind == kind)
