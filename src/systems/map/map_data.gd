class_name MapData
extends RefCounted
## Static map definition from data/map.json: regions, terrain, provinces and adjacency.

const PATH := "res://data/map.json"
const NON_HOUSE_OWNERS: Array[String] = ["neutral", "church", "elector"]
## Province features buildings can require (BuildingDef.features).
const FEATURES: Array[String] = ["ore", "river", "pass", "port"]

var regions: Array[String] = []
var houses: Array[String] = []
## Camp of each house; the camp decides the patron power (CrownData.camp_patrons).
var house_camps: Dictionary[String, String] = {}
## Heraldic colours of each house: field first, then charge.
var house_colors: Dictionary[String, PackedColorArray] = {}
## Colours of the lords who are no house (NON_HOUSE_OWNERS): field first, then charge.
var lord_colors: Dictionary[String, PackedColorArray] = {}
var start_army: Array[String] = []
var campaign: CampaignRules
var crown: CrownData
var geography: MapGeography
var terrains: Dictionary[String, TerrainDef] = {}
var provinces: Dictionary[String, ProvinceDef] = {}


class TerrainDef:
	var field_yield: float
	var battlefield: String


class ProvinceDef:
	var id: String
	var region: String
	var owner: String
	var terrain: String
	var population: float
	var neighbors: Array[String] = []
	var home_of: String = ""
	var castle_level: int = 0
	var buildings: Array[String] = []
	var river: String = ""
	var has_port: bool = false
	var has_pass: bool = false
	var has_ore: bool = false
	var is_church: bool = false
	var garrison: int = 0
	var satisfaction_bonus: float = 0.0
	var tax_cap: int = 100
	var fixed_income: float = 0.0
	var tags: Array[String] = []
	## Rough real centre as longitude and latitude (degrees); MapGeography projects it.
	var at := Vector2.ZERO
	## Favour of the province's lord (elector or neutral) per house where it differs from
	## CrownData.favour_default.
	var start_favour: Dictionary[String, float] = {}

	func has_feature(feature: String) -> bool:
		match feature:
			"ore":
				return has_ore
			"river":
				return not river.is_empty()
			"pass":
				return has_pass
			"port":
				return has_port
		return false


static func load_file(path: String = PATH) -> MapData:
	var data: Variant = DataReader.load_json(path)
	if not data is Dictionary:
		push_error("%s: expected a JSON object" % path)
		return null
	var reader := DataReader.new()
	var map := MapData.new()
	map._read(reader, data)
	for error: String in reader.errors:
		push_error("%s: %s" % [path, error])
	return null if reader.errors else map


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	var homes: Dictionary[String, int] = {}
	for province: ProvinceDef in provinces.values():
		var where := "province %s" % province.id
		if province.region not in regions:
			errors.append("%s: unknown region '%s'" % [where, province.region])
		if not terrains.has(province.terrain):
			errors.append("%s: unknown terrain '%s'" % [where, province.terrain])
		if province.owner not in houses and province.owner not in NON_HOUSE_OWNERS:
			errors.append("%s: unknown owner '%s'" % [where, province.owner])
		if not geography.contains(province.at):
			errors.append("%s: centre %s lies outside the realm" % [where, province.at])
		if province.population <= 0.0:
			errors.append("%s: population must be positive" % where)
		if not province.home_of.is_empty():
			if province.home_of != province.owner:
				errors.append("%s: home of '%s' but owned by '%s'" % [
					where, province.home_of, province.owner
				])
			homes[province.home_of] = homes.get(province.home_of, 0) + 1
		errors.append_array(_validate_neighbors(province))
	for house: String in houses:
		if homes.get(house, 0) != 1:
			errors.append("house %s: needs exactly one home province" % house)
	errors.append_array(_validate_crown())
	return errors


func connection_count() -> int:
	var count := 0
	for province: ProvinceDef in provinces.values():
		count += province.neighbors.size()
	@warning_ignore("integer_division")
	return count / 2


func are_neighbors(a: String, b: String) -> bool:
	return provinces.has(a) and b in provinces[a].neighbors


func home_province(house: String) -> String:
	for province: ProvinceDef in provinces.values():
		if province.home_of == house:
			return province.id
	return ""


## Field and charge colours of every owner: the houses and the other lords.
func heraldry() -> Dictionary[String, PackedColorArray]:
	var colors := house_colors.duplicate()
	colors.merge(lord_colors)
	return colors


## Provinces whose lord is an elector, in data order.
func electors() -> Array[String]:
	var ids: Array[String] = []
	for province: ProvinceDef in provinces.values():
		if province.owner == "elector":
			ids.append(province.id)
	return ids


## Start favour of a house with the lord of an elector or neutral province.
func start_favour(province_id: String, house: String) -> float:
	return provinces[province_id].start_favour.get(house, crown.favour_default)


func _validate_neighbors(province: ProvinceDef) -> PackedStringArray:
	var errors: PackedStringArray = []
	var seen: Array[String] = []
	for other: String in province.neighbors:
		var pair := "%s-%s" % [province.id, other]
		if other == province.id:
			errors.append("neighbors %s: province borders itself" % pair)
		elif not provinces.has(other):
			errors.append("neighbors %s: unknown province" % pair)
		elif province.id not in provinces[other].neighbors:
			errors.append("neighbors %s: missing reverse connection" % pair)
		if other in seen:
			errors.append("neighbors %s: listed twice" % pair)
		seen.append(other)
	return errors


func _validate_crown() -> PackedStringArray:
	var errors: PackedStringArray = []
	for house: String in houses:
		if not crown.camp_patrons.has(house_camps[house]):
			errors.append("house %s: unknown camp '%s'" % [house, house_camps[house]])
		if house_colors[house].size() != 2:
			errors.append("house %s: needs two colors" % house)
	for owner: String in NON_HOUSE_OWNERS:
		if lord_colors.get(owner, PackedColorArray()).size() != 2:
			errors.append("lords.%s: needs two colors" % owner)
	for site: String in crown.archbishops:
		var id: String = crown.archbishops[site]
		if not campaign.legitimacy_tags.has(site):
			errors.append("crown.coronation.archbishops: unknown site '%s'" % site)
		if not provinces.has(id) or provinces[id].owner != "elector" or not provinces[id].is_church:
			errors.append("crown.coronation.archbishops.%s: %s is no church elector" % [site, id])
	for province: ProvinceDef in provinces.values():
		var where := "province %s: start favour" % province.id
		if not province.start_favour.is_empty() and province.owner not in ["elector", "neutral"]:
			errors.append("%s, but its lord keeps no favour list" % where)
		for house: String in province.start_favour:
			var value := province.start_favour[house]
			if house not in houses:
				errors.append("%s for unknown house '%s'" % [where, house])
			if value < 0.0 or value > crown.favour_max:
				errors.append("%s %s is outside 0–%s" % [where, value, crown.favour_max])
	var modified: Array = crown.house_favour_multiplier.keys()
	modified.append_array(crown.house_gift_cost_multiplier.keys())
	for house: String in modified:
		if house not in houses:
			errors.append("crown.favour: unknown house '%s'" % house)
	return errors


func _read(reader: DataReader, data: Dictionary) -> void:
	regions = reader.strings(data, "regions")
	var house_data := reader.object(data, "houses")
	for id: String in house_data:
		reader.context = "houses.%s" % id
		var entry := reader.object(house_data, id)
		houses.append(id)
		house_camps[id] = reader.text(entry, "camp")
		house_colors[id] = _read_colors(reader, entry)
	reader.context = ""
	var lords := reader.object(data, "lords")
	for id: String in lords:
		reader.context = "lords.%s" % id
		lord_colors[id] = _read_colors(reader, reader.object(lords, id))
	reader.context = ""
	start_army = reader.strings(data, "start_army")
	var campaign_data := reader.object(data, "campaign")
	reader.context = "campaign"
	campaign = CampaignRules.read(reader, campaign_data)
	reader.context = ""
	crown = CrownData.read(reader, reader.object(data, "crown"))
	geography = MapGeography.read(reader, reader.object(data, "geography"))
	var terrain_data := reader.object(data, "terrains")
	for id: String in terrain_data:
		reader.context = "terrains.%s" % id
		var entry := reader.object(terrain_data, id)
		var terrain := TerrainDef.new()
		terrain.field_yield = reader.number(entry, "field_yield")
		terrain.battlefield = reader.text(entry, "battlefield")
		terrains[id] = terrain
	reader.context = ""
	for entry: Variant in reader.list(data, "provinces"):
		if not entry is Dictionary:
			reader.errors.append("provinces: expected objects")
			continue
		var province := _read_province(reader, entry)
		if provinces.has(province.id):
			reader.errors.append("provinces: duplicate id '%s'" % province.id)
		provinces[province.id] = province


func _read_province(reader: DataReader, entry: Dictionary) -> ProvinceDef:
	var province := ProvinceDef.new()
	province.id = reader.text(entry, "id")
	reader.context = "provinces.%s" % province.id
	if province.id.is_empty():
		reader.errors.append("%s: missing id" % reader.context)
	province.region = reader.text(entry, "region")
	province.at = MapGeography.lon_lat(reader, entry, "at")
	province.owner = reader.text(entry, "owner")
	province.terrain = reader.text(entry, "terrain")
	province.population = reader.number(entry, "population")
	province.neighbors = reader.strings(entry, "neighbors")
	province.home_of = reader.text(entry, "home_of")
	province.castle_level = reader.integer(entry, "castle_level", 0)
	province.buildings = reader.strings(entry, "buildings", false)
	province.river = reader.text(entry, "river")
	province.has_port = reader.flag(entry, "port")
	province.has_pass = reader.flag(entry, "pass")
	province.has_ore = reader.flag(entry, "ore")
	province.is_church = reader.flag(entry, "church")
	province.garrison = reader.integer(entry, "garrison", 0)
	province.satisfaction_bonus = reader.number(entry, "satisfaction_bonus", 0.0)
	province.tax_cap = reader.integer(entry, "tax_cap", 100)
	province.fixed_income = reader.number(entry, "fixed_income", 0.0)
	province.tags = reader.strings(entry, "tags", false)
	var favour := reader.object(entry, "start_favour", false)
	for house: String in favour:
		province.start_favour[house] = reader.number(favour, house)
	reader.context = ""
	return province


func _read_colors(reader: DataReader, entry: Dictionary) -> PackedColorArray:
	var colors := PackedColorArray()
	for html: String in reader.strings(entry, "colors"):
		if Color.html_is_valid(html):
			colors.append(Color.html(html))
		else:
			reader.errors.append("%s.colors: invalid color '%s'" % [reader.context, html])
	return colors
