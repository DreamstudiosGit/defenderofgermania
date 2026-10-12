extends GutTest
## data/combat_siege.json: it loads, it carries the GDD numbers, and broken data is reported.

var _cfg: SiegeConfig


func before_all() -> void:
	_cfg = SiegeConfig.load_file()


func test_file_loads() -> void:
	assert_not_null(_cfg)


func test_wall_hp_is_400_per_wall_level() -> void:
	for level: int in [1, 2, 3, 4]:
		assert_eq(_cfg.wall_hp(level), 400 * level)


func test_shots_are_three_plus_two_per_trebuchet() -> void:
	for trebuchets: int in [1, 2, 3, 4]:
		assert_eq(_cfg.shots(trebuchets), 3 + 2 * trebuchets)


func test_counterfire_costs_every_third_shot_from_wall_three() -> void:
	for slot: int in range(1, 12):
		assert_false(_cfg.is_counterfire_slot(slot, 2), "no counterfire below wall 3")
		assert_eq(_cfg.is_counterfire_slot(slot, 3), slot % 3 == 0, "shot %d at wall 3" % slot)
		assert_eq(_cfg.is_counterfire_slot(slot, 4), slot % 3 == 0, "shot %d at wall 4" % slot)


func test_projectiles_follow_the_gdd() -> void:
	var stone := _cfg.projectiles["stone"]
	assert_eq(stone.damage, 240)
	assert_false(stone.ignites)
	var fire_pot := _cfg.projectiles["fire_pot"]
	assert_almost_eq(fire_pot.garrison_damage, 0.08, 1e-9)
	assert_true(fire_pot.ignites)


func test_every_castle_kit_has_a_layout() -> void:
	for home: bool in [false, true]:
		for level: int in range(0, 6):
			var setup := TrebuchetSetup.new()
			setup.is_home_castle = home
			setup.castle_level = level
			assert_false(_cfg.layout(setup.layout_key()).is_empty(), setup.layout_key())


func test_layout_parts_share_the_whole_wall_hp() -> void:
	for key: String in _cfg.layouts:
		var total := 0.0
		for part: SiegeConfig.PartDef in _cfg.layout(key):
			total += part.hp_share
		assert_almost_eq(total, 1.0, 1e-6, key)


func test_practice_setup_is_playable() -> void:
	assert_eq(_cfg.practice.validate(), "")
	assert_true(_cfg.practice.is_practice)


func test_missing_values_are_reported() -> void:
	var data := _data()
	data.erase("wall_hp_per_level")
	(data["projectiles"] as Dictionary).erase("fire_pot")
	var reader := DataReader.new()
	SiegeConfig.parse(reader, data)
	assert_true(_has_error(reader, "wall_hp_per_level: missing"), str(reader.errors))
	assert_true(_has_error(reader, "projectiles: missing 'fire_pot'"), str(reader.errors))


func test_broken_layout_is_reported() -> void:
	var data := _data()
	var parts: Array = data["layouts"]["province_2"]["parts"]
	(parts[0] as Dictionary)["hp_share"] = 0.5
	(parts[1] as Dictionary)["falls_onto"] = ["drawbridge"]
	(parts[2] as Dictionary)["kind"] = "moat"
	var reader := DataReader.new()
	SiegeConfig.parse(reader, data)
	assert_true(_has_error(reader, "hp_share must add up to 1"), str(reader.errors))
	assert_true(_has_error(reader, "unknown neighbour 'drawbridge'"), str(reader.errors))
	assert_true(_has_error(reader, "kind: unknown 'moat'"), str(reader.errors))


func test_missing_layout_and_skills_are_reported() -> void:
	var data := _data()
	(data["layouts"] as Dictionary).erase("home_5")
	(data["ai"]["skills"] as Array).pop_back()
	var reader := DataReader.new()
	SiegeConfig.parse(reader, data)
	assert_true(_has_error(reader, "layouts: missing 'home_5'"), str(reader.errors))
	assert_true(_has_error(reader, "ai.skills"), str(reader.errors))


func test_broken_file_does_not_load() -> void:
	assert_null(SiegeConfig.load_file("res://data/combat_siege_missing.json"))
	assert_push_error("data file not found")
	assert_push_error("expected a JSON object")


static func _data() -> Dictionary:
	return DataReader.load_json(SiegeConfig.PATH)


static func _has_error(reader: DataReader, text: String) -> bool:
	for error: String in reader.errors:
		if text in error:
			return true
	return false
