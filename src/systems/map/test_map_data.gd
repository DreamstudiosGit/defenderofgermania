extends GutTest

const TEXTS_PATH := "res://data/i18n/texts.csv"

var _map: MapData


func before_all() -> void:
	_map = MapData.load_file()


func test_map_file_loads() -> void:
	assert_not_null(_map)


func test_map_passes_integrity_checks() -> void:
	assert_eq_deep(_map.validate(), PackedStringArray())


func test_map_has_31_provinces_and_63_connections() -> void:
	assert_eq(_map.provinces.size(), 31)
	assert_eq(_map.connection_count(), 63)


func test_terrain_counts_match_gdd() -> void:
	var expected := {
		"farmland": 12, "marsh": 2, "hills": 8, "forest": 3, "heath": 2, "mountains": 3, "city": 1
	}
	assert_eq_deep(_count_by(func(p: MapData.ProvinceDef) -> String: return p.terrain), expected)


func test_start_owners_match_gdd() -> void:
	var expected := {
		"welfen": 2,
		"wettiner": 2,
		"staufer": 2,
		"wittelsbacher": 2,
		"elector": 7,
		"church": 6,
		"neutral": 10,
	}
	assert_eq_deep(_count_by(func(p: MapData.ProvinceDef) -> String: return p.owner), expected)


func test_every_house_has_a_home_province() -> void:
	var expected := {"welfen": "BSW", "wettiner": "MEI", "staufer": "SWB", "wittelsbacher": "BAY"}
	for house: String in expected:
		assert_eq(_map.home_province(house), expected[house])


func test_church_lands_match_ban_list() -> void:
	var church: Array[String] = []
	for province: MapData.ProvinceDef in _map.provinces.values():
		if province.is_church:
			church.append(province.id)
	church.sort()
	assert_eq_deep(church, ["BRM", "FRA", "KOE", "MAG", "MAI", "MUN", "OSN", "SAL", "TRI"])


func test_validate_reports_one_sided_neighbor() -> void:
	var map := MapData.load_file()
	map.provinces["FRS"].neighbors.append("TIR")
	var errors := map.validate()
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "FRS-TIR")


func test_validate_reports_unknown_terrain_and_owner() -> void:
	var map := MapData.load_file()
	map.provinces["HES"].terrain = "desert"
	map.provinces["HES"].owner = "romans"
	assert_eq(map.validate().size(), 2)


func test_every_province_has_german_and_english_name() -> void:
	var names := _read_texts()
	for id: String in _map.provinces:
		var key := "PROVINCE_%s" % id
		assert_true(names.has(key), "missing text key %s" % key)
		if names.has(key):
			var row: PackedStringArray = names[key]
			assert_false(row[1].is_empty() or row[2].is_empty(), "empty name for %s" % key)


func _count_by(property: Callable) -> Dictionary:
	var counts := {}
	for province: MapData.ProvinceDef in _map.provinces.values():
		var key: String = property.call(province)
		counts[key] = counts.get(key, 0) + 1
	return counts


func _read_texts() -> Dictionary:
	var rows := {}
	var file := FileAccess.open(TEXTS_PATH, FileAccess.READ)
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() >= 3:
			rows[row[0]] = row
	return rows
