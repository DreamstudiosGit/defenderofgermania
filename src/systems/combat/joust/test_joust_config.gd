extends GutTest
## Joust data (data/combat_joust.json): GDD numbers, the lance values reused from combat.json
## and validation of broken files.

const EPSILON := 1e-9

var _cfg: JoustConfig


func before_all() -> void:
	_cfg = JoustConfig.load_file()


func test_file_loads_without_errors() -> void:
	assert_not_null(_cfg)
	assert_eq(_cfg.errors.size(), 0)


func test_three_passes_with_gdd_run_up_and_aim() -> void:
	assert_eq(_cfg.passes, 3)
	assert_eq(_cfg.runup_seconds, 3.0)
	assert_eq(_cfg.aim_seconds, 1.5)
	assert_eq(_cfg.tick_rate, 30, "same fixed tick as the battle")


func test_hit_window_is_60_plus_15_per_lance_point_and_staufer_add_40_ms() -> void:
	assert_almost_eq(_cfg.window_seconds(0, "welfen"), 0.060, EPSILON)
	assert_almost_eq(_cfg.window_seconds(2, "wettiner"), 0.090, EPSILON)
	assert_almost_eq(_cfg.window_seconds(5, "elector"), 0.135, EPSILON)
	assert_almost_eq(_cfg.window_seconds(3, "staufer"), 0.145, EPSILON)


func test_lance_steadies_the_sway_by_ten_percent_per_point() -> void:
	assert_almost_eq(_cfg.sway_scale(0), 1.0, EPSILON)
	assert_almost_eq(_cfg.sway_scale(3), 0.7, EPSILON)


func test_zones_score_helmet_5_shield_centre_3_rim_1() -> void:
	assert_eq(_cfg.zone_ids(), ["helmet", "shield_centre", "shield_rim"] as Array[String])
	assert_eq(_cfg.zones[0].points, 5)
	assert_eq(_cfg.zones[1].points, 3)
	assert_eq(_cfg.zones[2].points, 1)


func test_perfect_breaks_the_lance_for_a_point_and_40_stance() -> void:
	assert_eq(_cfg.perfect_points, 1)
	assert_eq(_cfg.perfect_stance, 40.0)
	assert_eq(_cfg.normal_stance, 20.0)


func test_riders_have_100_stance_and_the_shield_halves_a_hit() -> void:
	assert_eq(_cfg.stance, 100.0)
	assert_eq(_cfg.shield_damage_factor, 0.5)


func test_rewards_of_tournament_and_fief_joust() -> void:
	assert_eq(_cfg.prize_gold, 100.0)
	assert_eq(_cfg.fief_satisfaction, -10.0)
	var economy := EconomyConfig.load_file()
	assert_eq(economy.tournament_won_prestige, 5.0, "prestige stays in economy.json")
	var map := MapData.load_file()
	assert_eq(map.crown.favour_changes["tournament_won"], 5.0, "favour stays in map.json")


func test_every_skill_has_an_error_pattern() -> void:
	assert_eq(_cfg.ai.size(), 4)
	for profile: JoustAIProfile in _cfg.ai:
		assert_false(profile.targets.is_empty())
		assert_false(profile.strike_error_ms.is_empty())


func test_missing_and_mistyped_values_are_all_reported() -> void:
	var data := _data()
	data.erase("stance")
	(data["strike"] as Dictionary)["perfect_stance"] = "forty"
	(data["aim"] as Dictionary)["rest"] = [0.0]
	var errors := JoustConfig.from_data(data, _cfg.combat).errors
	assert_true(_mentions(errors, "stance: missing"), str(errors))
	assert_true(_mentions(errors, "perfect_stance: expected a number"), str(errors))
	assert_true(_mentions(errors, "rest: expected [x, y]"), str(errors))


func test_implausible_values_are_rejected() -> void:
	var data := _data()
	(data["strike"] as Dictionary)["normal_stance"] = 50
	(data["ai"] as Array).pop_back()
	var first: Dictionary = (data["ai"] as Array)[0]
	first["targets"] = ["belly"]
	first["spurs"] = [9]
	(data["zones"] as Array).append({"id": "helmet", "center": [0, 0], "radius": 0, "points": 1})
	var errors := JoustConfig.from_data(data, _cfg.combat).errors
	assert_true(_mentions(errors, "perfect_stance must be at least"), str(errors))
	assert_true(_mentions(errors, "one error pattern per skill"), str(errors))
	assert_true(_mentions(errors, "unknown zone 'belly'"), str(errors))
	assert_true(_mentions(errors, "beat 9 outside"), str(errors))
	assert_true(_mentions(errors, "zones[3]"), str(errors))


func _data() -> Dictionary:
	return (DataReader.load_json(JoustConfig.PATH) as Dictionary).duplicate(true)


static func _mentions(errors: PackedStringArray, text: String) -> bool:
	for error: String in errors:
		if text in error:
			return true
	return false
