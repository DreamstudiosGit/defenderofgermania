extends GutTest
## Cross-file consistency between the data files in data/.

const TEXTS_PATH := "res://data/i18n/texts.csv"
const PATRON_CARDS: Array[String] = ["SILVER", "MERCENARIES", "EMBASSY"]

var _map: MapData
var _economy: EconomyConfig
var _combat: CombatConfig
var _events: EventData


func before_all() -> void:
	_map = MapData.load_file()
	_economy = EconomyConfig.load_file()
	_combat = CombatConfig.load_file()
	_events = EventData.load_file()


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


func test_battle_armies_are_houses_with_colors() -> void:
	for army: BattleRules.ArmyPreset in _combat.battle.armies:
		assert_true(army.house in _map.houses, "unknown house %s" % army.house)
		assert_eq(_map.house_colors[army.house].size(), 2, army.house)


func test_patron_mercenaries_exist_in_economy_and_combat() -> void:
	var unit := _map.crown.patron_mercenary_unit
	assert_true(_economy.units.has(unit), "no economy entry for %s" % unit)
	assert_true(_combat.units.has(unit), "no combat stats for %s" % unit)
	assert_true(_economy.units[unit].is_mercenary, "%s are no mercenaries" % unit)


func test_event_references_exist() -> void:
	var patrons := _map.crown.camp_patrons.values()
	for event: EventData.EventDef in _events.events.values():
		var where := "event %s" % event.id
		if not event.needs_feature.is_empty():
			assert_true(event.needs_feature in MapData.FEATURES, "%s: feature" % where)
		for id: String in [event.needs_province, event.favour_province]:
			assert_true(id.is_empty() or _map.provinces.has(id), "%s: province %s" % [where, id])
		for effect: EventData.EffectDef in _events.all_effects(event):
			if not effect.unit.is_empty():
				assert_true(_combat.units.has(effect.unit), "%s: unit %s" % [where, effect.unit])
				assert_true(_economy.units.has(effect.unit), "%s: unit %s" % [where, effect.unit])
			if not effect.halved_by.is_empty():
				var building := effect.halved_by
				assert_true(_economy.buildings.has(building), "%s: building %s" % [where, building])
			var names_province := not effect.target.is_empty() and effect.target == effect.target.to_upper()
			if effect.type in ["secure_vote", "homage"] or names_province:
				assert_true(_map.provinces.has(effect.target), "%s: province %s" % [where, effect.target])
			if effect.type == "patron_strength":
				assert_true(effect.target in patrons, "%s: patron %s" % [where, effect.target])


func test_event_groups_name_lords_with_favour_lists() -> void:
	for group: String in _events.groups:
		var lords: Array = _events.groups[group]
		assert_false(lords.is_empty(), group)
		for id: String in lords:
			var def: MapData.ProvinceDef = _map.provinces.get(id)
			assert_not_null(def, "%s: province %s" % [group, id])
			if def != null:
				var keeps_list := def.owner == "elector" or (def.owner == "neutral" and not def.is_church)
				assert_true(keeps_list, "%s: %s keeps no favour list" % [group, id])
	for id: String in _events.lords(EventEffects.CHURCH_GROUP):
		assert_true(_map.provinces[id].is_church and _map.provinces[id].owner == "elector", id)


func test_crown_and_event_texts_exist_in_both_languages() -> void:
	var keys: Array[String] = []
	for id: String in _map.electors():
		keys.append("ELECTOR_%s" % id)
	for house: String in _map.houses:
		keys.append("CASTLE_HOME_%s" % house.to_upper())
	for camp: String in _map.crown.camp_patrons:
		keys.append("CAMP_%s" % camp.to_upper())
		keys.append("PATRON_%s" % _map.crown.camp_patrons[camp].to_upper())
	for card: String in PATRON_CARDS:
		keys.append("PATRON_CARD_%s" % card)
	for event: EventData.EventDef in _events.events.values():
		var prefix := "EVENT_%s" % event.id.to_upper()
		keys.append_array([prefix + "_TITLE", prefix + "_TEXT"])
		for choice: EventData.ChoiceDef in event.choices:
			keys.append("%s_CHOICE_%s" % [prefix, choice.id.to_upper()])
	var texts := _read_texts()
	for key: String in keys:
		var row: PackedStringArray = texts.get(key, PackedStringArray())
		assert_true(row.size() >= 3 and not row[1].is_empty() and not row[2].is_empty(), key)


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
		MoveArmyCommand.ERROR_PENANCE,
		CrownRules.ERROR_NO_REGALIA,
		CrownRules.ERROR_NO_SITE,
		CrownRules.ERROR_NO_ARCHBISHOP,
		CrownRules.ERROR_NOT_ENOUGH_VOTES,
		CoronationCommand.ERROR_NOT_WINTER,
		GiftCommand.ERROR_NO_FAVOUR_LIST,
		HomageCommand.ERROR_NOT_NEUTRAL,
		HomageCommand.ERROR_FAVOUR,
		PenanceCommand.ERROR_NOT_BANNED,
		PlayPatronCommand.ERROR_UNKNOWN_CARD,
		PlayPatronCommand.ERROR_NO_CARDS,
		PlayPatronCommand.ERROR_PLAYED,
		PlayPatronCommand.ERROR_NOT_ELECTOR,
		ForgeRegaliaCommand.ERROR_FORGED,
		ForgeRegaliaCommand.ERROR_CASTLE,
		HostTournamentCommand.ERROR_SEASON,
		HostTournamentCommand.ERROR_NO_GROUND,
		HostTournamentCommand.ERROR_HOSTED,
		MoveArmyCommand.ERROR_FLOODED,
		ChooseEventCommand.ERROR_NO_CARD,
		ChooseEventCommand.ERROR_UNKNOWN_CHOICE,
		EventEffects.ERROR_ADVENTURE_LATER,
		EventEffects.ERROR_UNAVAILABLE,
		EventEffects.ERROR_TARGET_GONE,
		EventEffects.ERROR_NO_UNITS,
		EventBattles.ERROR_NO_ARMY,
		Adventures.ERROR_DONE,
		Adventures.ERROR_LEADER_CAPTURED,
		"ECONOMY_TERM_EVENT_GRAIN",
	]:
		assert_string_contains(texts, "\n%s," % key)


func _read_texts() -> Dictionary:
	var rows := {}
	var file := FileAccess.open(TEXTS_PATH, FileAccess.READ)
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() >= 3:
			rows[row[0]] = row
	return rows
