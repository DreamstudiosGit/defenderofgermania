class_name RecruitDef
extends RefCounted
## Economy row of a unit type in data/economy.json: recruiting cost, upkeep and unlocks.

var cost: float
var population: float
var upkeep_gold: float
var upkeep_grain: float
var is_mercenary: bool
## Home castle level that unlocks the unit.
var home_castle: int
## Building the recruiting province needs; "" for none.
var requires: String


static func read(r: DataReader, entry: Dictionary) -> RecruitDef:
	var unit := RecruitDef.new()
	unit.cost = r.number(entry, "cost")
	unit.population = r.number(entry, "population")
	unit.upkeep_gold = r.number(entry, "upkeep_gold")
	unit.upkeep_grain = r.number(entry, "upkeep_grain")
	unit.is_mercenary = r.flag(entry, "mercenary")
	unit.home_castle = r.integer(entry, "home_castle")
	unit.requires = r.text(entry, "requires")
	return unit
