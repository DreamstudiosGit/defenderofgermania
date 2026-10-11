class_name CastleLevelDef
extends RefCounted
## One level of the home castle or province castle table in data/economy.json.

var cost: float
var build_rounds: int
var upkeep: float
var wall: int
## Levy companies defending the castle without upkeep.
var garrison: int
var prestige: float
## Home castle level needed to build this level; 0 for none.
var home_castle: int


## Reads a list of levels into a table keyed by level number.
static func read_table(
	r: DataReader, data: Dictionary, key: String
) -> Dictionary[int, CastleLevelDef]:
	var levels: Dictionary[int, CastleLevelDef] = {}
	for item: Variant in r.list(data, key):
		if not item is Dictionary:
			r.errors.append("%s: expected objects" % key)
			continue
		var entry: Dictionary = item
		var number := r.integer(entry, "level")
		r.context = "%s.%d" % [key, number]
		var level := CastleLevelDef.new()
		level.cost = r.number(entry, "cost")
		level.build_rounds = r.integer(entry, "build_rounds")
		level.upkeep = r.number(entry, "upkeep")
		level.wall = r.integer(entry, "wall")
		level.garrison = r.integer(entry, "garrison")
		level.prestige = r.number(entry, "prestige", 0.0)
		level.home_castle = r.integer(entry, "home_castle", 0)
		levels[number] = level
		r.context = ""
	return levels
