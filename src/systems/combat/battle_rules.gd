class_name BattleRules
extends RefCounted
## Real-time battle constants and the prototype's default armies from the "battle" section of
## data/combat.json. Angles are stored in radians, times in seconds, lengths in meters.

const SHAPES: Array[String] = ["line", "hedgehog", "staggered", "wedge"]
const FORMATIONS_PER_GROUP := 2

var tick_rate: int
var field_size: Vector2
var deploy_seconds: float
var deploy_depth: float
var time_limit_seconds: float
var acceleration: float
var turn_rate: float
var flee_speed_factor: float
var melee_reach: float
var deployment: Dictionary[String, float] = {}

var foot_radius: float
var horse_radius: float
var foot_spacing: float
var horse_spacing: float
var catch_up_factor: float

var morale_per_hp_percent: float
var flank_morale: float
var leader_captured_morale: float
var flee_below: float
var rally_radius: float
var rally_cooldown: float
var rally_morale: float

var runup_distance: float
var impact_seconds: float
var charge_max_distance: float

var attack_cone: float
var aim_cone: float
var pick_radius: float

var volleys: int
var volley_interval: float

## Seconds a trebuchet stone flies before it lands on the target circle.
var siege_flight_seconds: float
## Meters per second the stick moves a trebuchet's target circle.
var siege_aim_speed: float
## Distance ahead of a deployed engine where its target circle starts.
var siege_start_aim: float

## Two per group in CombatConfig.GROUPS order; siege reuses the infantry formations if absent.
var formations: Array[FormationRules] = []
## x, y = center on the field, z = radius; obstacle_kinds is parallel ("tree", "rock").
var obstacles: PackedVector3Array = []
var obstacle_kinds: PackedStringArray = []
## Companies whose center is within an obstacle's radius plus this margin are in its cover.
var cover_margin: float
## Ranged damage multiplier in the cover of each obstacle kind.
var cover_damage: Dictionary[String, float] = {}
## [attacker, defender] of the prototype battle.
var armies: Array[ArmyPreset] = []


class FormationRules:
	var shape: String
	var speed: float
	var impact: float
	var volley: float
	var reload: float
	var auto_fire: bool
	## False for a packed siege engine, which drives but cannot shoot.
	var can_fire: bool
	var cavalry_damage_taken: float
	## Attacks from further off the facing than this hit the flank or rear.
	var front_half_angle: float


class ArmyPreset:
	var house: String
	## Heraldic colours of the house (MapData.house_colors), set by apply_house_colors().
	var color := Color.WHITE
	var accent := Color.WHITE
	var has_leader: bool
	var leadership: int
	var units: Array[String] = []


static func read(r: DataReader, data: Dictionary) -> BattleRules:
	var rules := BattleRules.new()
	r.context = "battle"
	rules._read_core(r, data)
	var layout := r.object(data, "deployment")
	var keys: Array[String] = [
		"front_gap", "company_gap", "archer_depth", "cavalry_depth", "leader_depth", "siege_depth"
	]
	for key: String in keys:
		rules.deployment[key] = r.number(layout, key)
	rules._read_figures(r, r.object(data, "figures"))
	rules._read_morale(r, r.object(data, "morale"))
	rules._read_attacks(r, data)
	rules._read_formations(r, r.object(data, "formations"))
	rules._read_obstacles(r, r.list(data, "obstacles", false))
	var cover := r.object(data, "cover")
	rules.cover_margin = r.number(cover, "margin")
	var cover_damage := r.object(cover, "ranged_damage")
	for kind: String in cover_damage:
		rules.cover_damage[kind] = r.number(cover_damage, kind)
	rules._read_armies(r, r.list(data, "armies"))
	r.context = ""
	return rules


func formation(group: int, index: int) -> FormationRules:
	return formations[group * FORMATIONS_PER_GROUP + index]


func deploy_ticks() -> int:
	return roundi(deploy_seconds * tick_rate)


func time_limit_ticks() -> int:
	return roundi(time_limit_seconds * tick_rate)


## Ranged damage multiplier for a company standing at this point: the best cover in reach.
func cover_at(at: Vector2) -> float:
	var factor := 1.0
	for i: int in obstacles.size():
		var obstacle := obstacles[i]
		if at.distance_to(Vector2(obstacle.x, obstacle.y)) <= obstacle.z + cover_margin:
			var kind_factor: float = cover_damage.get(obstacle_kinds[i], 1.0)
			factor = minf(factor, kind_factor)
	return factor


## Gives the default armies their house colours: house id → [field, charge].
func apply_house_colors(house_colors: Dictionary[String, PackedColorArray]) -> void:
	for army: ArmyPreset in armies:
		var colors: PackedColorArray = house_colors.get(army.house, PackedColorArray())
		if colors.size() >= 2:
			army.color = colors[0]
			army.accent = colors[1]


## Builds the prototype battle from the default armies.
func default_setup() -> BattleSetup:
	var setup := BattleSetup.new()
	_fill_side(setup.attacker, armies[0])
	_fill_side(setup.defender, armies[1])
	return setup


func check(r: DataReader, units: Dictionary) -> void:
	if armies.size() != 2:
		r.errors.append("battle.armies: expected 2 armies (attacker, defender)")
	for army: ArmyPreset in armies:
		for id: String in army.units:
			if not units.has(id):
				r.errors.append("battle.armies.%s: unknown unit '%s'" % [army.house, id])
	for rule: FormationRules in formations:
		if rule.shape not in SHAPES:
			r.errors.append("battle.formations: unknown shape '%s'" % rule.shape)
	if tick_rate <= 0 or runup_distance <= 0.0:
		r.errors.append("battle: tick_rate and charge.runup_distance must be positive")
	if field_size.x <= 0 or field_size.y <= 0 or deploy_depth <= 0:
		r.errors.append("battle: field dimensions and deploy_depth must be positive")
	if deploy_depth * 2 >= field_size.x:
		r.errors.append("battle: deployment zones must leave space between armies")
	for key: String in deployment:
		if deployment[key] < 0:
			r.errors.append("battle.deployment.%s: must not be negative" % key)
	for kind: String in obstacle_kinds:
		if not cover_damage.has(kind):
			r.errors.append("battle.cover.ranged_damage: no value for obstacle kind '%s'" % kind)


func _read_core(r: DataReader, data: Dictionary) -> void:
	tick_rate = r.integer(data, "tick_rate")
	var field := r.object(data, "field")
	field_size = Vector2(r.number(field, "width"), r.number(field, "height"))
	deploy_seconds = r.number(data, "deploy_seconds")
	deploy_depth = r.number(data, "deploy_depth")
	time_limit_seconds = r.number(data, "time_limit_seconds")
	acceleration = r.number(data, "acceleration")
	turn_rate = deg_to_rad(r.number(data, "turn_rate_deg"))
	flee_speed_factor = r.number(data, "flee_speed_factor")
	melee_reach = r.number(data, "melee_reach")


func _read_figures(r: DataReader, data: Dictionary) -> void:
	foot_radius = r.number(data, "foot_radius")
	horse_radius = r.number(data, "horse_radius")
	foot_spacing = r.number(data, "foot_spacing")
	horse_spacing = r.number(data, "horse_spacing")
	catch_up_factor = r.number(data, "catch_up_factor")


func _read_morale(r: DataReader, data: Dictionary) -> void:
	morale_per_hp_percent = r.number(data, "per_hp_percent")
	flank_morale = r.number(data, "flank")
	leader_captured_morale = r.number(data, "leader_captured")
	flee_below = r.number(data, "flee_below")
	rally_radius = r.number(data, "rally_radius")
	rally_cooldown = r.number(data, "rally_cooldown")
	rally_morale = r.number(data, "rally_morale")


func _read_attacks(r: DataReader, data: Dictionary) -> void:
	var charge := r.object(data, "charge")
	runup_distance = r.number(charge, "runup_distance")
	impact_seconds = r.number(charge, "impact_seconds")
	charge_max_distance = r.number(charge, "max_distance")
	var targeting := r.object(data, "targeting")
	attack_cone = deg_to_rad(r.number(targeting, "attack_cone_deg"))
	aim_cone = deg_to_rad(r.number(targeting, "aim_cone_deg"))
	pick_radius = r.number(targeting, "pick_radius")
	var volley_data := r.object(data, "volleys")
	volleys = r.integer(volley_data, "count")
	volley_interval = r.number(volley_data, "interval")
	var siege := r.object(data, "siege")
	siege_flight_seconds = r.number(siege, "flight_seconds")
	siege_aim_speed = r.number(siege, "aim_speed")
	siege_start_aim = r.number(siege, "start_aim_distance")


func _read_formations(r: DataReader, data: Dictionary) -> void:
	var infantry: Array[FormationRules] = []
	for group: String in CombatConfig.GROUPS:
		var entries := r.list(data, group, group != "siege")
		if entries.is_empty() and group == "siege":
			formations.append_array(infantry)
			continue
		if entries.size() != FORMATIONS_PER_GROUP:
			r.errors.append("battle.formations.%s: expected 2 formations" % group)
		var pair: Array[FormationRules] = []
		for i: int in FORMATIONS_PER_GROUP:
			var entry: Variant = entries[i] if i < entries.size() else {}
			pair.append(_read_formation(r, entry if entry is Dictionary else {}))
		formations.append_array(pair)
		if group == "infantry":
			infantry = pair


func _read_formation(r: DataReader, entry: Dictionary) -> FormationRules:
	var rule := FormationRules.new()
	rule.shape = r.text(entry, "shape", "line")
	rule.speed = r.number(entry, "speed", 1.0)
	rule.impact = r.number(entry, "impact", 1.0)
	rule.volley = r.number(entry, "volley", 1.0)
	rule.reload = r.number(entry, "reload", 1.0)
	rule.auto_fire = r.flag(entry, "auto_fire")
	rule.can_fire = not entry.has("fires") or r.flag(entry, "fires")
	rule.cavalry_damage_taken = r.number(entry, "cavalry_damage_taken", 1.0)
	rule.front_half_angle = deg_to_rad(r.number(entry, "front_half_angle_deg"))
	return rule


func _read_obstacles(r: DataReader, entries: Array) -> void:
	for entry: Variant in entries:
		var data: Dictionary = entry if entry is Dictionary else {}
		obstacles.append(
			Vector3(r.number(data, "x"), r.number(data, "y"), r.number(data, "radius"))
		)
		obstacle_kinds.append(r.text(data, "kind", "rock"))


func _read_armies(r: DataReader, entries: Array) -> void:
	for entry: Variant in entries:
		var data: Dictionary = entry if entry is Dictionary else {}
		var army := ArmyPreset.new()
		army.house = r.text(data, "house")
		army.has_leader = r.flag(data, "leader")
		army.leadership = r.integer(data, "leadership", 0)
		army.units = r.strings(data, "units")
		armies.append(army)


func _fill_side(side: BattleSide, army: ArmyPreset) -> void:
	side.owner = army.house
	for id: String in army.units:
		side.add_company(id)
	side.has_leader = army.has_leader
	side.leadership = army.leadership
