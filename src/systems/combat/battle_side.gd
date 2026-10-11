class_name BattleSide
extends RefCounted
## One side of a battle. units and health are parallel: one entry per company, health is the
## share of the unit's full HP (0..1). The leader is not a company; has_leader adds it.

var owner: String
var units: Array[String] = []
var health: PackedFloat64Array = []
var has_leader: bool = false
var leadership: int = 0
var is_human: bool = false
## Added to the average unit morale, e.g. data morale.leader_captured while the leader is held.
var morale_bonus: float = 0.0


func add_company(unit: String, company_health: float = 1.0) -> void:
	units.append(unit)
	health.append(company_health)


func company_count() -> int:
	return units.size()
