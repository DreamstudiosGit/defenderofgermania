class_name BuildingDef
extends RefCounted
## One row of the building table in data/economy.json: costs, effects and prerequisites.

var cost: float
var build_rounds: int
var upkeep: float
var harvest_bonus: float
var market_level: int
var satisfaction: float
var growth: float
var prestige: float
var spoilage_reduction: float
var income: float
var income_river: float
var income_pass: float
## Starvation loss of a besieged garrison in this province is multiplied by this.
var siege_starve_multiplier: float
## Castle construction of the owning house is multiplied by this.
var castle_cost_multiplier: float
## Building this one replaces when it is finished; it must stand in the province already.
var upgrade_of: String
var home_castle: int
var is_home_only: bool
## The province needs at least one of these MapData.FEATURES; empty means no requirement.
var features: Array[String] = []


static func read(r: DataReader, entry: Dictionary) -> BuildingDef:
	var building := BuildingDef.new()
	building.cost = r.number(entry, "cost")
	building.build_rounds = r.integer(entry, "build_rounds")
	building.upkeep = r.number(entry, "upkeep")
	building.harvest_bonus = r.number(entry, "harvest_bonus", 0.0)
	building.market_level = r.integer(entry, "market_level", 0)
	building.satisfaction = r.number(entry, "satisfaction", 0.0)
	building.growth = r.number(entry, "growth", 0.0)
	building.prestige = r.number(entry, "prestige", 0.0)
	building.spoilage_reduction = r.number(entry, "spoilage_reduction", 0.0)
	building.income = r.number(entry, "income", 0.0)
	building.income_river = r.number(entry, "income_river", 0.0)
	building.income_pass = r.number(entry, "income_pass", 0.0)
	building.siege_starve_multiplier = r.number(entry, "siege_starve_multiplier", 1.0)
	building.castle_cost_multiplier = r.number(entry, "castle_cost_multiplier", 1.0)
	building.upgrade_of = r.text(entry, "upgrade_of")
	building.home_castle = r.integer(entry, "home_castle", 0)
	building.is_home_only = r.flag(entry, "home_only")
	building.features = r.strings(entry, "features", false)
	return building
