extends GutTest
## The computer leader: skill levels differ clearly, raids take one to three minutes.

const SEEDS := 12

var _cfg: RaidConfig


func before_all() -> void:
	_cfg = RaidConfig.load_file()


func test_skill_levels_differ_clearly_over_a_set_of_seeds() -> void:
	var wins: Array[int] = []
	for ai_skill: int in 4:
		var count := 0
		for s: int in SEEDS:
			if RaidAI.auto_resolve(_cfg, _setup(2, 2), 100 + s, ai_skill).success:
				count += 1
		wins.append(count)
	assert_lte(wins[0], SEEDS / 3, "a clumsy leader mostly ends in the dungeon: %s" % [wins])
	assert_gte(wins[3], SEEDS - 1, "a master swordsman nearly always gets in: %s" % [wins])
	assert_gt(wins[2], wins[0])
	assert_gte(wins[3], wins[1])


func test_guard_skill_makes_the_castle_harder() -> void:
	var wins: Array[int] = []
	for guard_skill: int in 4:
		var count := 0
		for s: int in SEEDS:
			if RaidAI.auto_resolve(_cfg, _setup(guard_skill, 2), 100 + s, 2).success:
				count += 1
		wins.append(count)
	assert_eq(wins[0], SEEDS, "%s" % [wins])
	assert_lt(wins[3], wins[1], "%s" % [wins])


func test_typical_raid_lasts_one_to_three_minutes() -> void:
	var total := 0.0
	var runs := 0
	for level: int in [2, 3]:
		for ai_skill: int in [1, 2]:
			for s: int in 6:
				var result := RaidAI.auto_resolve(_cfg, _setup(1, level), 200 + s, ai_skill)
				assert_lte(result.time_used, _cfg.time_limit_seconds)
				var shown := _cfg.intro_seconds + result.time_used + _cfg.outro_seconds
				assert_between(shown, 45.0, 180.0)
				total += shown
				runs += 1
	var mean := total / runs
	assert_between(mean, 60.0, 180.0, "mean %.1f s" % mean)


func test_auto_resolve_is_deterministic() -> void:
	var first := RaidAI.auto_resolve(_cfg, _setup(2, 3), 5, 1)
	var second := RaidAI.auto_resolve(_cfg, _setup(2, 3), 5, 1)
	assert_eq(first.outcome, second.outcome)
	assert_eq(first.time_used, second.time_used)
	assert_eq(first.guards_defeated, second.guards_defeated)


func _setup(guard_skill: int, level: int) -> RaidSetup:
	var setup := RaidSetup.new()
	setup.guard_skill = guard_skill
	setup.castle_level = level
	setup.blade = 3
	return setup
