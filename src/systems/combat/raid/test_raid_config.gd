extends GutTest
## Castle raid data (GDD "Burgüberfall"): binding numbers, castle tables and broken data.

const EPSILON := 1e-9

var _cfg: RaidConfig


func before_each() -> void:
	_cfg = RaidConfig.load_file()


func test_parry_window_is_150_plus_20_ms_per_blade_point() -> void:
	for blade: int in 6:
		assert_eq(_cfg.parry_window_ms(blade), 150.0 + 20.0 * blade)


func test_parry_ticks_cover_exactly_the_window() -> void:
	# 30 Hz: a parry k ticks old holds while k × 33.3 ms ≤ window.
	assert_eq(_cfg.parry_ticks(0), 5, "150 ms: ages 0–4")
	assert_eq(_cfg.parry_ticks(2), 6, "190 ms: ages 0–5")
	assert_eq(_cfg.parry_ticks(5), 8, "250 ms: ages 0–7")


func test_blade_sharpens_the_sword_by_ten_percent_per_point() -> void:
	assert_almost_eq(_cfg.strike_damage_for(0), _cfg.strike_damage, EPSILON)
	assert_almost_eq(_cfg.strike_damage_for(3), _cfg.strike_damage * 1.3, EPSILON)


func test_raid_lasts_120_seconds_and_the_alarm_sounds_after_60() -> void:
	assert_eq(_cfg.time_limit_seconds, 120.0)
	assert_eq(_cfg.alarm_seconds, 60.0)


func test_treasury_takes_20_percent_of_the_taler_up_to_200() -> void:
	assert_eq(_cfg.treasury_loot(450), 90)
	assert_eq(_cfg.treasury_loot(1000), 200)
	assert_eq(_cfg.treasury_loot(5000), 200)
	assert_eq(_cfg.treasury_loot(0), 0)


func test_burnt_granary_costs_30_percent_of_the_grain() -> void:
	assert_almost_eq(_cfg.granary_loss(200.0), 60.0, EPSILON)


func test_success_brings_prestige_3_and_the_regalia_10() -> void:
	for target: String in ["treasury", "dungeon", "granary"]:
		assert_eq(_cfg.prestige(target), 3.0, target)
	assert_eq(_cfg.prestige("regalia"), 10.0)
	assert_eq(_cfg.church_ban_chance, 0.25, "a raid on church land risks the ban at 25 %")


func test_every_castle_sets_3_to_6_guards_growing_with_its_level() -> void:
	var tables: Array = [[true, 5], [false, 3]]
	for entry: Array in tables:
		var home: bool = entry[0]
		var previous := 0
		for level: int in range(1, int(entry[1]) + 1):
			var castle := _cfg.castle(home, level)
			assert_not_null(castle, "home %s level %d" % [home, level])
			assert_between(castle.guards, 3, 6)
			assert_true(castle.guards >= previous, "more guards in bigger castles")
			assert_lt(castle.sneak_paths, castle.guards)
			previous = castle.guards
	assert_eq(_cfg.castle(false, 1).guards, 3)
	assert_eq(_cfg.castle(true, 5).guards, 6)
	assert_null(_cfg.castle(false, 0), "an open province has no castle to raid")


func test_guard_patterns_cover_every_skill() -> void:
	assert_eq(_cfg.guard_skills.size(), 4)
	assert_eq(_cfg.ai_skills.size(), 4)
	for i: int in range(1, 4):
		var easier := _cfg.guard_skills[i - 1]
		var harder := _cfg.guard_skills[i]
		assert_lt(harder.windup_ms, easier.windup_ms, "skill %d telegraphs less" % i)
		assert_lt(harder.open_ms, easier.open_ms, "skill %d stays open shorter" % i)


func test_broken_data_is_reported_and_refused() -> void:
	var data: Dictionary = DataReader.load_json(RaidConfig.PATH)
	data.erase("alarm_seconds")
	var skills: Array = data["guards"]["skills"]
	(skills[1]["attacks"] as Array).append("sideways")
	data["castles"]["home"]["5"]["guards"] = 7
	assert_null(RaidConfig.from_data(data, CombatConfig.load_file(), "broken"))
	assert_push_error("alarm_seconds: missing")
	assert_push_error("alarm_seconds must lie inside")
	assert_push_error("unknown height 'sideways'")
	assert_push_error("guards must be 3–6")
