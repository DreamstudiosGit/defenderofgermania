class_name CombatConfig
extends RefCounted
## Combat values from data/combat.json: unit stats, morale rules, auto-resolve constants and
## the real-time battle rules.

const PATH := "res://data/combat.json"
const GROUPS: Array[String] = ["infantry", "archers", "cavalry", "siege"]

var units: Dictionary[String, UnitStats] = {}

var morale_per_leadership: float
var morale_leader_captured: float
var winter_attack_morale_multiplier: float

## Lance and blade of the leader (GDD "Häuser & Anführer"), used by joust and castle raid.
var joust_window_base_ms: float
var joust_window_per_lance_ms: float
var sway_reduction_per_lance: float
var house_joust_window_ms: Dictionary[String, float] = {}
var damage_per_blade: float
var parry_window_per_blade_ms: float

var leadership_bonus: float
var morale_base: float
var morale_divisor: float
var exponent: float
var terrain_defender: Dictionary[String, float] = {}
var castle_per_wall: float
var counter_bonus: float
var counter_max: float
var human_malus: float
var loser_loss_min: float
var loser_loss_max: float
var winner_loss_factor: float
var winner_loss_min: float
var winner_loss_max: float

## Real-time battle constants ("battle" section).
var battle: BattleRules


class UnitStats:
	var group: String
	var hp: float
	var melee: float
	var melee_vs_cavalry: float
	var charge_multiplier: float
	var charge_min_speed: float
	var ranged: float
	var attack_range: float
	var reload: float
	var armor_piercing: float
	var splash_radius: float
	var wall_multiplier: float
	var armor: float
	var speed: float
	var charge_speed: float
	var morale: float
	var unpaid_morale_penalty: float
	var aura_morale: float
	var aura_radius: float
	var auto_resolve: float
	var figures: int
	var strong_against: Array[String] = []


static func load_file(path: String = PATH) -> CombatConfig:
	var data: Variant = DataReader.load_json(path)
	if not data is Dictionary:
		push_error("%s: expected a JSON object" % path)
		return null
	var reader := DataReader.new()
	var config := CombatConfig.new()
	config._read(reader, data)
	config._check(reader)
	for error: String in reader.errors:
		push_error("%s: %s" % [path, error])
	return null if reader.errors else config


func _read(r: DataReader, data: Dictionary) -> void:
	var unit_data := r.object(data, "units")
	for id: String in unit_data:
		r.context = "units.%s" % id
		units[id] = _read_unit(r, r.object(unit_data, id))
	r.context = ""

	var morale := r.object(data, "morale")
	morale_per_leadership = r.number(morale, "per_leadership")
	morale_leader_captured = r.number(morale, "leader_captured")
	winter_attack_morale_multiplier = r.number(morale, "winter_attack_multiplier")

	var skills := r.object(data, "leader_skills")
	var lance := r.object(skills, "lance")
	joust_window_base_ms = r.number(lance, "joust_window_base_ms")
	joust_window_per_lance_ms = r.number(lance, "joust_window_per_point_ms")
	sway_reduction_per_lance = r.number(lance, "sway_reduction_per_point")
	var house_window := r.object(lance, "house_joust_window_ms", false)
	for house: String in house_window:
		house_joust_window_ms[house] = r.number(house_window, house)
	var blade := r.object(skills, "blade")
	damage_per_blade = r.number(blade, "damage_per_point")
	parry_window_per_blade_ms = r.number(blade, "parry_window_per_point_ms")

	var auto := r.object(data, "auto_resolve")
	leadership_bonus = r.number(auto, "leadership_bonus")
	morale_base = r.number(auto, "morale_base")
	morale_divisor = r.number(auto, "morale_divisor")
	exponent = r.number(auto, "exponent")
	var terrain := r.object(auto, "terrain_defender")
	for id: String in terrain:
		terrain_defender[id] = r.number(terrain, id)
	castle_per_wall = r.number(auto, "castle_per_wall")
	counter_bonus = r.number(auto, "counter_bonus")
	counter_max = r.number(auto, "counter_max")
	human_malus = r.number(auto, "human_malus")
	loser_loss_min = r.number(auto, "loser_loss_min")
	loser_loss_max = r.number(auto, "loser_loss_max")
	winner_loss_factor = r.number(auto, "winner_loss_factor")
	winner_loss_min = r.number(auto, "winner_loss_min")
	winner_loss_max = r.number(auto, "winner_loss_max")

	battle = BattleRules.read(r, r.object(data, "battle"))


## Half-width of the joust hit window: ±(60 + 15 · lance) ms plus the house bonus.
func joust_window_ms(lance: int, house: String) -> float:
	var house_bonus: float = house_joust_window_ms.get(house, 0.0)
	return joust_window_base_ms + joust_window_per_lance_ms * lance + house_bonus


func _read_unit(r: DataReader, entry: Dictionary) -> UnitStats:
	var unit := UnitStats.new()
	unit.group = r.text(entry, "group")
	unit.hp = r.number(entry, "hp")
	unit.melee = r.number(entry, "melee")
	unit.melee_vs_cavalry = r.number(entry, "melee_vs_cavalry", 1.0)
	unit.charge_multiplier = r.number(entry, "charge_multiplier", 1.0)
	unit.charge_min_speed = r.number(entry, "charge_min_speed", 0.0)
	unit.ranged = r.number(entry, "ranged", 0.0)
	unit.attack_range = r.number(entry, "range", 0.0)
	unit.reload = r.number(entry, "reload", 0.0)
	unit.armor_piercing = r.number(entry, "armor_piercing", 1.0)
	unit.splash_radius = r.number(entry, "splash_radius", 0.0)
	unit.wall_multiplier = r.number(entry, "wall_multiplier", 1.0)
	unit.armor = r.number(entry, "armor")
	unit.speed = r.number(entry, "speed")
	unit.charge_speed = r.number(entry, "charge_speed", unit.speed)
	unit.morale = r.number(entry, "morale")
	unit.unpaid_morale_penalty = r.number(entry, "unpaid_morale_penalty", 0.0)
	unit.aura_morale = r.number(entry, "aura_morale", 0.0)
	unit.aura_radius = r.number(entry, "aura_radius", 0.0)
	unit.auto_resolve = r.number(entry, "auto_resolve")
	unit.figures = r.integer(entry, "figures")
	unit.strong_against = r.strings(entry, "strong_against")
	return unit


func _check(r: DataReader) -> void:
	if not units.has("leader"):
		r.errors.append("units: missing 'leader'")
	for id: String in units:
		var unit := units[id]
		if unit.group not in GROUPS:
			r.errors.append("units.%s.group: unknown group '%s'" % [id, unit.group])
		for other: String in unit.strong_against:
			if not units.has(other):
				r.errors.append("units.%s.strong_against: unknown unit '%s'" % [id, other])
	battle.check(r, units)
