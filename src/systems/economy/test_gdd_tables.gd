extends GutTest
## The GDD tables of "Gebäude & Stammburg" and "Militär & Einheiten" against data/economy.json:
## costs, build times, upkeep, effects and unlocks (milestone M4 acceptance).

var _cfg: EconomyConfig
var _map: MapData


func before_all() -> void:
	_cfg = EconomyConfig.load_file()
	_map = MapData.load_file()


func test_buildings_match_the_gdd_table() -> void:
	# id: [cost, build rounds, upkeep]
	var table := {
		"mill": [80, 1, 2], "market_1": [100, 1, 2], "market_2": [250, 2, 5],
		"granary": [70, 1, 1], "monastery": [150, 2, 3], "mine": [200, 2, 5],
		"toll": [60, 1, 1], "tourney_ground": [120, 1, 2], "workshop": [150, 2, 3],
	}
	assert_eq_deep(_sorted(_cfg.buildings.keys()), _sorted(table.keys()))
	for id: String in table:
		var building := _cfg.buildings[id]
		assert_eq([building.cost, building.build_rounds, building.upkeep], [
			float(table[id][0]), table[id][1], float(table[id][2])
		], id)


func test_building_effects_and_prerequisites_match_the_gdd() -> void:
	var b := _cfg.buildings
	assert_eq(b["mill"].harvest_bonus, 0.25)
	assert_eq(b["market_1"].market_level, 1)
	assert_eq(b["market_1"].satisfaction, 5.0)
	assert_eq(b["market_2"].market_level, 2)
	assert_eq(b["market_2"].upgrade_of, "market_1")
	assert_eq(b["market_2"].home_castle, 2)
	assert_eq(b["granary"].spoilage_reduction, 0.02)
	assert_eq(b["granary"].siege_starve_multiplier, 0.5)
	assert_eq([b["monastery"].satisfaction, b["monastery"].growth, b["monastery"].prestige], [
		10.0, 0.01, 0.5
	])
	assert_eq(b["mine"].income, 30.0)
	assert_eq_deep(b["mine"].features, ["ore"] as Array[String])
	assert_eq([b["toll"].income_river, b["toll"].income_pass], [8.0, 15.0])
	assert_true(b["tourney_ground"].is_home_only)
	assert_eq(b["tourney_ground"].home_castle, 3)
	assert_true(b["workshop"].is_home_only)
	assert_eq(b["workshop"].home_castle, 4)
	assert_eq(b["workshop"].castle_cost_multiplier, 0.85)
	assert_eq(_cfg.tournament_cost, 80.0)
	assert_eq(_cfg.tournament_hosted_prestige, 5.0)


func test_home_castle_levels_match_the_gdd_table() -> void:
	# level: [cost, build rounds, upkeep, wall, prestige per round]
	var table := {
		1: [0, 0, 0, 1, 0.5], 2: [300, 2, 5, 2, 1.0], 3: [600, 3, 10, 3, 1.5],
		4: [1000, 3, 15, 3, 2.5], 5: [1800, 4, 25, 4, 4.0],
	}
	assert_eq_deep(_sorted(_cfg.home_castle.keys()), [1, 2, 3, 4, 5])
	for level: int in table:
		var row := _cfg.home_castle[level]
		var expected: Array = table[level]
		assert_eq([row.cost, row.build_rounds, row.upkeep, row.wall, row.prestige], [
			float(expected[0]), expected[1], float(expected[2]), expected[3], expected[4]
		], "home castle %d" % level)


func test_province_castles_match_the_gdd_table() -> void:
	# level: [cost, build rounds, upkeep, wall, garrison companies]
	var table := {
		0: [0, 0, 0, 0, 0], 1: [80, 1, 2, 1, 1], 2: [250, 2, 5, 2, 2], 3: [500, 3, 10, 3, 3],
	}
	for level: int in table:
		var row := _cfg.province_castle[level]
		var expected: Array = table[level]
		assert_eq([row.cost, row.build_rounds, row.upkeep, row.wall, row.garrison], [
			float(expected[0]), expected[1], float(expected[2]), expected[3], expected[4]
		], "province castle %d" % level)
	assert_eq(_cfg.province_castle[3].home_castle, 3, "a fortress needs home castle 3")


func test_decorations_match_the_gdd_table() -> void:
	var d := _cfg.decorations
	assert_eq(_cfg.decoration_limit, 5)
	assert_eq([d["banners"].cost, d["banners"].prestige], [50.0, 0.2])
	assert_eq([d["fountain"].cost, d["fountain"].satisfaction], [100.0, 3.0])
	assert_eq([d["rose_garden"].cost, d["rose_garden"].prestige], [120.0, 0.4])
	assert_eq([d["tapestries"].cost, d["tapestries"].prestige], [150.0, 0.5])
	assert_eq([d["stained_glass"].cost, d["stained_glass"].prestige], [200.0, 0.6])
	assert_eq(d["stained_glass"].home_castle, 4)


func test_units_match_the_gdd_cost_table() -> void:
	# id: [cost, population, upkeep taler, upkeep grain, home castle]
	var table := {
		"levy": [20, 0.5, 1, 3, 1], "spearmen": [40, 0.5, 2, 3, 1],
		"crossbowmen": [50, 0.5, 3, 3, 2], "knights": [120, 0.3, 8, 6, 3],
		"brabanters": [90, 0.0, 10, 3, 1], "trebuchet": [150, 0.2, 6, 2, 1],
	}
	for id: String in table:
		var unit := _cfg.units[id]
		var expected: Array = table[id]
		assert_eq([unit.cost, unit.population, unit.upkeep_gold, unit.upkeep_grain, unit.home_castle], [
			float(expected[0]), expected[1], float(expected[2]), float(expected[3]), expected[4]
		], id)
	assert_eq(_cfg.units["brabanters"].requires, "market_2")
	assert_true(_cfg.units["brabanters"].is_mercenary)
	assert_eq(_cfg.units["trebuchet"].requires, "workshop")
	assert_eq(RecruitCommand.unit_cost(_cfg, "staufer", "knights"), 90.0, "Staufer knights")


func test_castle_level_unlocks_match_the_gdd() -> void:
	assert_eq(_map.crown.forged_regalia_home_castle, 3, "forged regalia from level 3")
	assert_eq(_map.crown.chapel_home_castle, 4, "the chapel halves the penance from level 4")
	assert_eq(_map.crown.imperial_palace_home_castle, 5, "the imperial palace courts the electors")
	assert_eq(_map.crown.favour_changes["imperial_palace"], 1.0)
	var slots: Array[int] = []
	for level: int in range(1, 6):
		slots.append(BuildingRules.slots(_cfg, true, level))
	assert_eq(slots, [2, 3, 4, 5, 6] as Array[int], "home province slots per level")


func _sorted(values: Array) -> Array:
	var copy := values.duplicate()
	copy.sort()
	return copy
