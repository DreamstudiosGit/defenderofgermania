class_name DecorationDef
extends RefCounted
## A decoration of the home castle in data/economy.json.

var cost: float
var prestige: float
var satisfaction: float
## Home castle level it needs; 0 for none.
var home_castle: int


static func read(r: DataReader, entry: Dictionary) -> DecorationDef:
	var decoration := DecorationDef.new()
	decoration.cost = r.number(entry, "cost")
	decoration.prestige = r.number(entry, "prestige", 0.0)
	decoration.satisfaction = r.number(entry, "satisfaction", 0.0)
	decoration.home_castle = r.integer(entry, "home_castle", 0)
	return decoration
