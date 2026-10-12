class_name ArmyState
extends RefCounted
## An army on the map. units and health are parallel, one entry per company ("Rotte");
## health is the company's share of its unit's full HP.

var id: int
var owner: String
var province: String
var units: Array[String] = []
var health: PackedFloat64Array = []
## Provinces the army may still enter in the current campaign phase.
var moves_left: int = 0
## Round of the army's last storm or bombardment; a besieger acts once a round.
var siege_turn: int = -1


static func from_dict(r: DataReader, data: Dictionary) -> ArmyState:
	var army := ArmyState.new()
	army.id = r.integer(data, "id")
	army.owner = r.text(data, "owner")
	army.province = r.text(data, "province")
	army.units = r.strings(data, "units")
	army.health = r.numbers(data, "health")
	army.moves_left = r.integer(data, "moves_left")
	army.siege_turn = r.integer(data, "siege_turn")
	if army.health.size() != army.units.size():
		r.errors.append("army %d: units and health differ in length" % army.id)
	return army


func add_company(unit: String, company_health: float = 1.0) -> void:
	units.append(unit)
	health.append(company_health)


func remove_company(index: int) -> void:
	units.remove_at(index)
	health.remove_at(index)


func company_count() -> int:
	return units.size()


func to_dict() -> Dictionary:
	return {
		"id": id,
		"owner": owner,
		"province": province,
		"units": units,
		"health": Array(health),
		"moves_left": moves_left,
		"siege_turn": siege_turn,
	}
