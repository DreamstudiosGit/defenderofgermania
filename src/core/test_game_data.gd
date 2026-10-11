extends GutTest
## Cross-file consistency between data/map.json and data/economy.json.

var _map: MapData
var _economy: EconomyConfig
var _combat: CombatConfig


func before_all() -> void:
	_map = MapData.load_file()
	_economy = EconomyConfig.load_file()
	_combat = CombatConfig.load_file()


func test_every_recruitable_unit_has_combat_stats() -> void:
	for id: String in _economy.units:
		assert_true(_combat.units.has(id), "no combat stats for %s" % id)


func test_terrain_bonuses_use_map_terrains() -> void:
	for id: String in _combat.terrain_defender:
		assert_true(_map.terrains.has(id), "unknown terrain %s" % id)


func test_economy_file_loads() -> void:
	assert_not_null(_economy)


func test_houses_match_between_map_and_economy() -> void:
	var map_houses := _map.houses.duplicate()
	var economy_houses: Array[String] = []
	economy_houses.assign(_economy.houses.keys())
	map_houses.sort()
	economy_houses.sort()
	assert_eq_deep(economy_houses, map_houses)


func test_start_buildings_exist() -> void:
	for province: MapData.ProvinceDef in _map.provinces.values():
		for id: String in province.buildings:
			assert_true(_economy.buildings.has(id), "%s: unknown building %s" % [province.id, id])


func test_start_army_units_exist() -> void:
	for id: String in _map.start_army:
		assert_true(_economy.units.has(id), "unknown unit %s" % id)


func test_texts_are_registered_in_both_languages() -> void:
	var locale := TranslationServer.get_locale()
	TranslationServer.set_locale("de")
	assert_eq(tr("PROVINCE_KOE"), "Köln")
	TranslationServer.set_locale("en")
	assert_eq(tr("PROVINCE_KOE"), "Cologne")
	TranslationServer.set_locale(locale)


func test_start_castle_levels_exist() -> void:
	for province: MapData.ProvinceDef in _map.provinces.values():
		var table := _economy.home_castle if province.home_of else _economy.province_castle
		assert_true(
			table.has(province.castle_level),
			"%s: no castle level %d" % [province.id, province.castle_level]
		)


func test_garrison_unit_exists_in_combat_and_economy() -> void:
	var unit := _map.campaign.garrison_unit
	assert_true(_combat.units.has(unit), "no combat stats for %s" % unit)
	assert_true(_economy.units.has(unit), "no economy entry for %s" % unit)


func test_building_features_exist_on_the_map() -> void:
	for id: String in _economy.buildings:
		for feature: String in _economy.buildings[id].features:
			assert_true(feature in MapData.FEATURES, "%s: unknown feature %s" % [id, feature])


func test_legitimacy_tags_mark_provinces() -> void:
	for tag: String in _map.campaign.legitimacy_tags:
		var holders := _map.provinces.values().filter(
			func(province: MapData.ProvinceDef) -> bool: return tag in province.tags
		)
		assert_eq(holders.size(), 1, "tag %s" % tag)


func test_leader_bonus_names_known_houses() -> void:
	for house: String in _map.campaign.leader_bonus:
		assert_true(house in _map.houses, "unknown house %s" % house)


func test_castle_tables_cover_every_level_up_to_the_top() -> void:
	for table: Dictionary[int, CastleLevelDef] in [_economy.home_castle, _economy.province_castle]:
		var top: int = table.keys().max()
		for level: int in range(table.keys().min(), top + 1):
			assert_true(table.has(level), "missing castle level %d" % level)


func test_campaign_error_keys_have_texts() -> void:
	var texts := FileAccess.get_file_as_string("res://data/i18n/texts.csv")
	for key: String in [
		Command.ERROR_GAME_OVER,
		Command.ERROR_NOT_ACTIVE,
		Command.ERROR_WRONG_PHASE,
		Command.ERROR_UNKNOWN_PROVINCE,
		Command.ERROR_NOT_OWNER,
		Command.ERROR_NOT_ENOUGH_GOLD,
		MoveArmyCommand.ERROR_UNKNOWN_ARMY,
		MoveArmyCommand.ERROR_NOT_NEIGHBOR,
		MoveArmyCommand.ERROR_NO_MOVES,
		StormCommand.ERROR_NOT_BESIEGING,
		AssignLeaderCommand.ERROR_LEADER_UNAVAILABLE,
		AssignLeaderCommand.ERROR_ARMY_FULL,
	]:
		assert_string_contains(texts, "\n%s," % key)
