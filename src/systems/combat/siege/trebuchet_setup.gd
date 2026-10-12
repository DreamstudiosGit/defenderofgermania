class_name TrebuchetSetup
extends RefCounted
## What the campaign hands the trebuchet minigame. The castle kit follows the castle (home or
## province, level); its HP follows the wall level (400 × wall level).

const ERROR_WALL := "wall level must be at least 1"
const ERROR_TREBUCHETS := "needs at least one trebuchet"
const ERROR_GARRISON := "garrison health must be a share 0..1"
const ERROR_WALL_DAMAGE := "wall damage must be a share 0..1"
const ERROR_CASTLE := "castle level must not be negative"
const ERROR_OWNERS := "attacker and defender must be named"

var attacker_house: String = ""
## House id, or "neutral" / "church" / "elector" for a lord who is no house.
var defender_owner: String = ""
var wall_level: int = 1
var is_home_castle: bool = false
var castle_level: int = 1
var trebuchets: int = 1
## Health share of the garrison when the bombardment starts.
var garrison_health: float = 1.0
## Share of the wall's HP destroyed in earlier rounds (ProvinceState.wall_damage).
var wall_damage: float = 0.0
var is_practice: bool = false


## Empty when the setup can be played, else what is wrong.
func validate() -> String:
	var problems: Dictionary[String, bool] = {
		ERROR_WALL: wall_level < 1,
		ERROR_TREBUCHETS: trebuchets < 1,
		ERROR_GARRISON: garrison_health < 0.0 or garrison_health > 1.0,
		ERROR_WALL_DAMAGE: wall_damage < 0.0 or wall_damage > 1.0,
		ERROR_CASTLE: castle_level < 0,
		ERROR_OWNERS: attacker_house.is_empty() or defender_owner.is_empty(),
	}
	for problem: String in problems:
		if problems[problem]:
			return problem
	return ""


## Layout key in data/combat_siege.json, chosen like the castle view picks its kit: home castles
## and castles above the province table use the home kit.
func layout_key() -> String:
	if is_home_castle or castle_level > 3:
		return "home_%d" % clampi(castle_level, 1, 5)
	return "province_%d" % clampi(castle_level, 1, 3)


func duplicate_setup() -> TrebuchetSetup:
	var copy := TrebuchetSetup.new()
	copy.attacker_house = attacker_house
	copy.defender_owner = defender_owner
	copy.wall_level = wall_level
	copy.is_home_castle = is_home_castle
	copy.castle_level = castle_level
	copy.trebuchets = trebuchets
	copy.garrison_health = garrison_health
	copy.wall_damage = wall_damage
	copy.is_practice = is_practice
	return copy
