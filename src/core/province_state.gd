class_name ProvinceState
extends RefCounted
## Changing per-province values; static facts (terrain, neighbors) stay in MapData.

var id: String
var owner: String
var population: float
var satisfaction: float
var castle_level: int
var buildings: Array[String] = []
var occupied_rounds: int = 0
var in_revolt: bool = false
## Health share of the castle garrison, or of the levy of a province without a house.
var garrison_health: float = 1.0
## Companies the province can still give this year; set from its people each spring.
var recruits_left: int = 0
var constructions: Array[ConstructionState] = []


static func from_dict(r: DataReader, data: Dictionary) -> ProvinceState:
	var province := ProvinceState.new()
	province.id = r.text(data, "id")
	province.owner = r.text(data, "owner")
	province.population = r.number(data, "population")
	province.satisfaction = r.number(data, "satisfaction")
	province.castle_level = r.integer(data, "castle_level")
	province.buildings = r.strings(data, "buildings")
	province.occupied_rounds = r.integer(data, "occupied_rounds")
	province.in_revolt = r.flag(data, "in_revolt")
	province.garrison_health = r.number(data, "garrison_health")
	province.recruits_left = r.integer(data, "recruits_left")
	for entry: Variant in r.list(data, "constructions"):
		if entry is Dictionary:
			province.constructions.append(ConstructionState.from_dict(r, entry))
		else:
			r.errors.append("province %s: constructions must be objects" % province.id)
	return province


func has_project(project: String) -> bool:
	for construction: ConstructionState in constructions:
		if construction.project == project:
			return true
	return false


func to_dict() -> Dictionary:
	var construction_data: Array[Dictionary] = []
	for construction: ConstructionState in constructions:
		construction_data.append(construction.to_dict())
	return {
		"id": id,
		"owner": owner,
		"population": population,
		"satisfaction": satisfaction,
		"castle_level": castle_level,
		"buildings": buildings,
		"occupied_rounds": occupied_rounds,
		"in_revolt": in_revolt,
		"garrison_health": garrison_health,
		"recruits_left": recruits_left,
		"constructions": construction_data,
	}
