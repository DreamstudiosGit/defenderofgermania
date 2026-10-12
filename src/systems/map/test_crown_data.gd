extends GutTest
## Electors, favour, coronation, patrons and ban from the "crown" section of map.json,
## checked against the GDD tables.

var _map: MapData


func before_each() -> void:
	_map = MapData.load_file()


func test_seven_electors_three_of_them_archbishops() -> void:
	var electors := _map.electors()
	electors.sort()
	assert_eq_deep(electors, ["BOH", "BRB", "KOE", "MAI", "PFA", "SXW", "TRI"])
	var church := electors.filter(func(id: String) -> bool: return _map.provinces[id].is_church)
	assert_eq_deep(church, ["KOE", "MAI", "TRI"])


func test_elector_start_favour_matches_gdd() -> void:
	var expected := {
		"KOE": {"welfen": 55, "wettiner": 30, "staufer": 30, "wittelsbacher": 30},
		"MAI": {"welfen": 30, "wettiner": 30, "staufer": 45, "wittelsbacher": 30},
		"TRI": {"welfen": 30, "wettiner": 30, "staufer": 30, "wittelsbacher": 30},
		"PFA": {"welfen": 40, "wettiner": 30, "staufer": 40, "wittelsbacher": 30},
		"SXW": {"welfen": 30, "wettiner": 45, "staufer": 30, "wittelsbacher": 30},
		"BRB": {"welfen": 40, "wettiner": 35, "staufer": 30, "wittelsbacher": 30},
		"BOH": {"welfen": 30, "wettiner": 40, "staufer": 30, "wittelsbacher": 40},
	}
	for id: String in expected:
		for house: String in expected[id]:
			assert_eq(_map.start_favour(id, house), float(expected[id][house]), "%s %s" % [id, house])


func test_neutral_lords_start_at_30_except_alsace_for_the_staufer() -> void:
	for province: MapData.ProvinceDef in _map.provinces.values():
		if province.owner != "neutral":
			continue
		for house: String in _map.houses:
			var expected := 50.0 if province.id == "ELS" and house == "staufer" else 30.0
			assert_eq(_map.start_favour(province.id, house), expected, province.id)


func test_coronation_needs_one_more_vote_per_missing_true_element() -> void:
	var crown := _map.crown
	assert_eq(crown.votes_needed("true", "coronation_site"), 4)
	assert_eq(crown.votes_needed("forged", "coronation_site"), 5)
	assert_eq(crown.votes_needed("true", "emergency_coronation_site"), 5)
	assert_eq(crown.votes_needed("forged", "emergency_coronation_site"), 6)
	assert_eq(crown.votes_needed("none", "coronation_site"), 0)
	assert_eq(crown.archbishops["coronation_site"], "KOE")
	assert_eq(crown.archbishops["emergency_coronation_site"], "MAI")
	assert_eq(crown.archbishop_min_favour, 50.0)
	assert_eq(crown.vote_threshold, 60.0)


func test_forged_regalia_cost_300_taler_two_rounds_from_castle_three() -> void:
	assert_eq(_map.crown.forged_regalia_cost, 300.0)
	assert_eq(_map.crown.forged_regalia_rounds, 2)
	assert_eq(_map.crown.forged_regalia_home_castle, 3)


func test_legitimacy_counts_forged_regalia_and_secure_votes() -> void:
	var rules := _map.campaign
	assert_almost_eq(rules.legitimacy([], 0, 0.0, true, 3), 10.0 + 30.0, 1e-9)
	var held: Array[String] = ["imperial_regalia", "coronation_site"]
	# 30 regalia + 20 Aachen + 10 · 4 votes + 2 · 5 provinces + 50 / 5 prestige
	assert_almost_eq(rules.legitimacy(held, 5, 50.0, false, 4), 30.0 + 20.0 + 40.0 + 10.0 + 10.0, 1e-9)


func test_camps_call_england_and_france() -> void:
	var patrons := {}
	for house: String in _map.houses:
		patrons[house] = _map.crown.camp_patrons[_map.house_camps[house]]
	assert_eq_deep(patrons, {
		"welfen": "england", "wettiner": "england", "staufer": "france", "wittelsbacher": "france"
	})


func test_patron_cards_and_ban_follow_gdd() -> void:
	var crown := _map.crown
	assert_eq(crown.patron_cards, 3)
	assert_eq(crown.patron_cards_per_round, 1)
	assert_eq(crown.patron_silver, 200.0)
	assert_eq(crown.patron_mercenary_unit, "brabanters")
	assert_eq(crown.patron_mercenary_companies, 4)
	assert_eq(crown.patron_embassy_favour, 15.0)
	assert_eq(crown.ban_attack_church_chance, 0.5)
	assert_eq(crown.ban_raid_church_chance, 0.25)
	assert_eq(crown.penance_gold * crown.chapel_gold_multiplier, 75.0)


func test_every_house_has_two_colors() -> void:
	for house: String in _map.houses:
		assert_eq(_map.house_colors[house].size(), 2, house)


func test_validate_reports_bad_start_favour() -> void:
	_map.provinces["BRM"].start_favour["welfen"] = 40.0
	_map.provinces["KOE"].start_favour["romans"] = 120.0
	var errors := _map.validate()
	assert_eq(errors.size(), 3, str(errors))


func test_validate_reports_archbishop_who_is_no_church_elector() -> void:
	_map.crown.archbishops["coronation_site"] = "PFA"
	var errors := _map.validate()
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "PFA")


func test_incomplete_coronation_table_is_rejected() -> void:
	var data: Dictionary = DataReader.load_json(MapData.PATH)
	var crown: Dictionary = data["crown"]
	var rules: Array = crown["coronation"]["rules"]
	rules.pop_back()
	var reader := DataReader.new()
	CrownData.read(reader, crown)
	assert_eq(reader.errors.size(), 1)
	assert_string_contains(reader.errors[0], "one rule per regalia and site")
