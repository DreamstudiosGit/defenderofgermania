class_name AiConfig
extends RefCounted
## The computer opponents from data/ai.json (GDD "KI-Gegner"): four personalities that weigh
## the kinds of actions, four difficulties, the values the utility compares in taler, and the
## thresholds of the four decision levels (supply, security, goals, opportunity).

const PATH := "res://data/ai.json"
const CATEGORIES: Array[String] = [
	"economy", "military", "castle", "court", "favour", "adventure"
]
const DIFFICULTIES := 4

var default_difficulty: int
## Personality id → house it plays by default.
var default_house: Dictionary[String, String] = {}
## Personality id → category → weight.
var weights: Dictionary[String, Dictionary] = {}
var difficulties: Array[Difficulty] = []
## Taler worth of one unit of legitimacy, prestige, favour, satisfaction, a province, a round
## of waiting and an elector's vote.
var values: Dictionary[String, float] = {}
var supply: Dictionary[String, float] = {}
var security: Dictionary[String, float] = {}
var goals: Dictionary[String, float] = {}
var opportunity: Dictionary[String, float] = {}
var anti_leader: Dictionary[String, float] = {}
var army: Dictionary[String, float] = {}
## Chance a minigame goes well for the computer at skill 0–3 (measured by the minigames' tests).
var adventure_success: PackedFloat64Array


class Difficulty:
	var id: String
	## Share of decisions taken deliberately below the best (GDD: squire 30 %).
	var suboptimal_share: float
	var better_targets: bool
	## Recruits against the enemy's dominant unit group.
	var counters: bool
	## Spares the others while one house leads and goes for the leader.
	var coalition: bool


static func load_file(path: String = PATH) -> AiConfig:
	var data: Variant = DataReader.load_json(path)
	if not data is Dictionary:
		push_error("%s: expected a JSON object" % path)
		return null
	var r := DataReader.new()
	var cfg := AiConfig.new()
	cfg._read(r, data)
	for error: String in r.errors:
		push_error("%s: %s" % [path, error])
	return null if r.errors else cfg


## Personality a computer house plays by default.
func personality_of(house: String) -> String:
	for id: String in default_house:
		if default_house[id] == house:
			return id
	return default_house.keys()[0]


func weight(personality: String, category: String) -> float:
	var table: Dictionary = weights.get(personality, {})
	return table.get(category, 1.0)


func difficulty(index: int) -> Difficulty:
	return difficulties[clampi(index, 0, difficulties.size() - 1)]


func _read(r: DataReader, data: Dictionary) -> void:
	default_difficulty = r.integer(data, "default_difficulty")
	var personalities := r.object(data, "personalities")
	for id: String in personalities:
		var entry := r.object(personalities, id)
		default_house[id] = r.text(entry, "house")
		var table := r.object(entry, "weights")
		var parsed := {}
		for category: String in CATEGORIES:
			parsed[category] = r.number(table, category)
		weights[id] = parsed
	for item: Variant in r.list(data, "difficulties"):
		if not item is Dictionary:
			r.errors.append("difficulties: expected objects")
			continue
		var entry: Dictionary = item
		var level := Difficulty.new()
		level.id = r.text(entry, "id")
		level.suboptimal_share = r.number(entry, "suboptimal_share")
		level.better_targets = r.flag(entry, "better_targets")
		level.counters = r.flag(entry, "counters")
		level.coalition = r.flag(entry, "coalition")
		difficulties.append(level)
	for section: String in [
		"values", "supply", "security", "goals", "opportunity", "anti_leader", "army"
	]:
		var target: Dictionary[String, float] = get(section)
		var table := r.object(data, section)
		for key: String in table:
			target[key] = r.number(table, key)
	adventure_success = r.numbers(data, "adventure_success")
	_check(r)


## Chance a minigame goes well at this skill.
func success(skill: int) -> float:
	return adventure_success[clampi(skill, 0, adventure_success.size() - 1)]


func _check(r: DataReader) -> void:
	if difficulties.size() != DIFFICULTIES:
		r.errors.append("difficulties: needs %d levels" % DIFFICULTIES)
	if default_difficulty < 0 or default_difficulty >= DIFFICULTIES:
		r.errors.append("default_difficulty: outside 0–%d" % (DIFFICULTIES - 1))
	if adventure_success.size() != DIFFICULTIES:
		r.errors.append("adventure_success: needs one chance per skill (%d)" % DIFFICULTIES)
	if default_house.is_empty():
		r.errors.append("personalities: none")
	for level: Difficulty in difficulties:
		if level.suboptimal_share < 0.0 or level.suboptimal_share > 1.0:
			r.errors.append("difficulties.%s: suboptimal_share outside 0–1" % level.id)
