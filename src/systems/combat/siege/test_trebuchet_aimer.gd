extends GutTest
## The computer's trebuchet crews differ clearly by skill, and a siege takes one to three
## minutes of play.

const SEEDS := 20
const LAYOUTS: Array[String] = ["province_2", "province_3", "home_2", "home_5"]
const WALLS: Array[int] = [2, 3, 2, 4]

var _cfg: SiegeConfig


func before_all() -> void:
	_cfg = SiegeConfig.load_file()


func test_skill_levels_differ_clearly_over_many_sieges() -> void:
	var hit_rates := PackedFloat64Array()
	var breaches := PackedInt32Array()
	for skill: int in SiegeConfig.AI_SKILLS:
		var hits := 0
		var shots := 0
		var won := 0
		for i: int in LAYOUTS.size():
			for seed_value: int in SEEDS:
				var sim := TrebuchetSim.new(_cfg, _setup(LAYOUTS[i], WALLS[i], 1), seed_value)
				var result := TrebuchetAimer.new(_cfg, skill).play(sim)
				hits += result.hits
				shots += result.shots_fired
				won += 1 if result.breach else 0
		hit_rates.append(float(hits) / shots)
		breaches.append(won)
	for skill: int in range(1, SiegeConfig.AI_SKILLS):
		assert_gt(hit_rates[skill], hit_rates[skill - 1] + 0.05, "hit rate, skill %d" % skill)
		assert_gt(breaches[skill], breaches[skill - 1], "breaches, skill %d" % skill)
	var sieges := LAYOUTS.size() * SEEDS
	assert_lt(breaches[0] * 2, sieges, "a clumsy crew breaches less than half the walls")
	assert_eq(breaches[3], sieges, "a master crew breaches every wall")


func test_aimer_follows_its_fixed_error_pattern() -> void:
	var sim := TrebuchetSim.new(_cfg, _setup("province_3", 3, 1), 3)
	var aimer := TrebuchetAimer.new(_cfg, 0)
	var crew := _cfg.skills[0]
	var target := sim.castle.world_rect(TrebuchetAimer.target_part(sim.castle))
	var ideal := TrebuchetAimer.solve(_cfg, crew.angle, 0.0, target[0], target[3] * 0.5)
	var shot := aimer.aim(sim)
	assert_eq(shot.counterweight, ideal + crew.counterweight_errors[0], "skill 0 ignores the wind")
	assert_eq(shot.angle, crew.angle + crew.angle_errors[0])


func test_full_siege_takes_one_to_three_minutes_of_play() -> void:
	for trebuchets: int in [1, 2]:
		for case: Array in [["province_1", 1], ["province_3", 3], ["home_5", 4]]:
			var sim := TrebuchetSim.new(_cfg, _setup(case[0], case[1], trebuchets), 4)
			while not sim.is_over():
				if sim.is_counterfire_slot():
					sim.endure_counterfire()
				else:
					sim.fire(TrebuchetShot.make(0, 45))
			var label := "%s wall %d, %d trebuchet(s)" % [case[0], case[1], trebuchets]
			assert_between(sim.result().duration_seconds, 60.0, 180.0, label)


func test_typical_player_siege_lasts_one_to_three_minutes_on_average() -> void:
	var total := 0.0
	var count := 0
	for i: int in LAYOUTS.size():
		for seed_value: int in SEEDS:
			var sim := TrebuchetSim.new(_cfg, _setup(LAYOUTS[i], WALLS[i], 1), seed_value)
			var aimer := TrebuchetAimer.new(_cfg, 1)
			while not sim.is_over():
				if sim.is_counterfire_slot():
					sim.endure_counterfire()
				else:
					var shot := aimer.aim(sim)
					shot.aim_seconds = _cfg.typical_aim_seconds
					sim.fire(shot)
			total += sim.result().duration_seconds
			count += 1
	assert_between(total / count, 60.0, 180.0)


func _setup(layout: String, wall: int, trebuchets: int) -> TrebuchetSetup:
	var setup := _cfg.practice.duplicate_setup()
	setup.is_home_castle = layout.begins_with("home")
	setup.castle_level = int(layout.get_slice("_", 1))
	setup.wall_level = wall
	setup.trebuchets = trebuchets
	return setup
