extends GutTest
## Army limits, leaders, garrisons and legitimacy from the campaign section of map.json.

var _map: MapData
var _rules: CampaignRules


func before_all() -> void:
	_map = MapData.load_file()
	_rules = _map.campaign


func test_campaign_rules_load() -> void:
	assert_not_null(_rules)
	assert_eq(_rules.max_rounds, 48)


func test_army_count_grows_every_second_home_castle_level() -> void:
	assert_eq(_rules.max_armies(0), 1)
	assert_eq(_rules.max_armies(1), 1)
	assert_eq(_rules.max_armies(2), 2)
	assert_eq(_rules.max_armies(3), 2)
	assert_eq(_rules.max_armies(4), 3)
	assert_eq(_rules.max_armies(5), 3)


func test_army_size_under_leader_and_captain() -> void:
	assert_eq(_rules.max_companies(true, 3), 9)
	assert_eq(_rules.max_companies(false, 5), 6)


func test_two_steps_only_in_summer() -> void:
	assert_eq(_rules.moves_per_round(false), 1)
	assert_eq(_rules.moves_per_round(true), 2)


func test_recovery_is_faster_in_own_provinces() -> void:
	assert_eq(_rules.recovery(true), 0.25)
	assert_eq(_rules.recovery(false), 0.1)


func test_neutral_levy_is_a_twentieth_of_the_people_rounded_up() -> void:
	assert_eq(_rules.neutral_garrison(35.0, 0), 2)
	assert_eq(_rules.neutral_garrison(40.0, 0), 2)
	assert_eq(_rules.neutral_garrison(41.0, 0), 3)
	assert_eq(_rules.neutral_garrison(70.0, 8), 8)


func test_leaders_have_nine_points_with_the_house_bonus() -> void:
	var bonus := {"welfen": "leadership", "wettiner": "blade", "staufer": "lance"}
	var rng := RandomNumberGenerator.new()
	for seed_value: int in 200:
		rng.seed = seed_value
		for house: String in _map.houses:
			var skills := _rules.roll_leader(house, rng)
			var total := 0
			for skill: String in CampaignRules.SKILLS:
				assert_between(skills[skill], 2, 5)
				total += skills[skill]
			assert_eq(total, 9)
			if bonus.has(house):
				assert_gte(skills[bonus[house]], 3, "%s bonus" % house)


func test_leader_roll_follows_the_seed() -> void:
	var first := RandomNumberGenerator.new()
	var second := RandomNumberGenerator.new()
	first.seed = 5
	second.seed = 5
	var skills := _rules.roll_leader("wittelsbacher", first)
	assert_eq_deep(skills, _rules.roll_leader("wittelsbacher", second))


func test_legitimacy_weighs_regalia_coronation_sites_provinces_and_prestige() -> void:
	var regalia: Array[String] = ["imperial_regalia", "wartburg"]
	assert_almost_eq(_rules.legitimacy(regalia, 2, 20.0), 30.0 + 4.0 + 4.0, 1e-9)
	var sites: Array[String] = ["coronation_site", "emergency_coronation_site"]
	assert_almost_eq(_rules.legitimacy(sites, 5, 50.0), 30.0 + 10.0 + 10.0, 1e-9)


func test_province_features() -> void:
	assert_true(_map.provinces["MEI"].has_feature("ore"))
	assert_true(_map.provinces["MEI"].has_feature("river"))
	assert_true(_map.provinces["TIR"].has_feature("pass"))
	assert_true(_map.provinces["HOL"].has_feature("port"))
	for feature: String in MapData.FEATURES:
		assert_false(_map.provinces["HES"].has_feature(feature))
