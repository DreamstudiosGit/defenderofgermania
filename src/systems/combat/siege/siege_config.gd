class_name SiegeConfig
extends RefCounted
## Values of the trebuchet minigame from data/combat_siege.json: wall HP, shots, counterfire,
## projectiles, burning, collapse, wind, ballistics, timing, the practice setup, the computer
## aimer and the castle layouts (side-view cross-sections of the kit castles).

const PATH := "res://data/combat_siege.json"
const KINDS: Array[String] = [
	"wall", "gate", "hoarding", "tower", "keep", "building", "roof", "mound"
]
## A wall or gate segment at 0 HP opens a breach.
const BREACH_KINDS: Array[String] = ["wall", "gate"]
## Mounds are earthworks: they stop projectiles but take no damage.
const MOUND := "mound"
const MATERIALS: Array[String] = ["wood", "stone", "earth"]
const WOOD := "wood"
const LAYOUT_KEYS: Array[String] = [
	"province_1", "province_2", "province_3", "home_1", "home_2", "home_3", "home_4", "home_5"
]
const AI_SKILLS := 4
const SHARE_TOLERANCE := 1e-6

var wall_hp_per_level: int
var shots_base: int
var shots_per_trebuchet: int
var counterfire_from_wall: int
var counterfire_every: int
var projectiles: Dictionary[String, ProjectileDef] = {}
var burn_share_per_shot: float
var fall_damage_share: float
var wind_min: float
var wind_max: float
var wind_acceleration: float
var gravity: float
var release := Vector2.ZERO
var speed_min: float
var speed_max: float
var counterweight_min: int
var counterweight_max: int
var angle_min: int
var angle_max: int
var start_counterweight: int
var start_angle: int
var step_rate: int
var max_flight_seconds: float
var preview_share: float
var castle_front: float
var aim_limit_seconds: float
var typical_aim_seconds: float
var throw_seconds: float
var settle_seconds: float
var counterfire_seconds: float
var practice := TrebuchetSetup.new()
var campaign_skill: int
var skills: Array[AiSkill] = []
var layouts: Dictionary[String, Array] = {}


class ProjectileDef:
	var id: String
	var damage: int
	var garrison_damage: float
	var ignites: bool
	var speed_factor: float


class PartDef:
	var id: String
	var kind: String
	var material: String
	## Side-view rectangle relative to the castle front: x is the distance behind the front,
	## y the height above the ground. Plain floats (not Rect2) keep double precision.
	var x0: float
	var y0: float
	var x1: float
	var y1: float
	var hp_share: float
	## Parts this one rests on; it falls as soon as one of them is destroyed.
	var supported_by: Array[String] = []
	## Parts it crashes onto when it is destroyed.
	var falls_onto: Array[String] = []

	func is_breach_segment() -> bool:
		return kind in BREACH_KINDS

	func is_solid_only() -> bool:
		return kind == MOUND


class AiSkill:
	var aim_seconds: float
	var angle: int
	## Share of the wind the aimer allows for (0 ignores it, 1 corrects it fully).
	var wind_awareness: float
	var counterweight_errors: PackedInt32Array
	var angle_errors: PackedInt32Array


static func load_file(path: String = PATH) -> SiegeConfig:
	var data: Variant = DataReader.load_json(path)
	if not data is Dictionary:
		push_error("%s: expected a JSON object" % path)
		return null
	var reader := DataReader.new()
	var config := parse(reader, data)
	for error: String in reader.errors:
		push_error("%s: %s" % [path, error])
	return null if reader.errors else config


## Reads and checks the whole file; problems end up in reader.errors.
static func parse(r: DataReader, data: Dictionary) -> SiegeConfig:
	var config := SiegeConfig.new()
	config._read(r, data)
	SiegeConfigCheck.check(config, r)
	return config


func wall_hp(wall_level: int) -> int:
	return wall_hp_per_level * wall_level


## Shots = base + per trebuchet × trebuchets (GDD: 3 + 2 × trebuchets).
func shots(trebuchets: int) -> int:
	return shots_base + shots_per_trebuchet * trebuchets


## Whether counterfire costs this shot (1-based) at the wall level: every third from wall 3.
func is_counterfire_slot(slot: int, wall_level: int) -> bool:
	return wall_level >= counterfire_from_wall and slot % counterfire_every == 0


func layout(key: String) -> Array[PartDef]:
	var parts: Array[PartDef] = []
	parts.assign(layouts.get(key, []))
	return parts


func _read(r: DataReader, data: Dictionary) -> void:
	wall_hp_per_level = r.integer(data, "wall_hp_per_level")
	var shot_data := r.object(data, "shots")
	shots_base = r.integer(shot_data, "base")
	shots_per_trebuchet = r.integer(shot_data, "per_trebuchet")
	var counterfire := r.object(data, "counterfire")
	counterfire_from_wall = r.integer(counterfire, "from_wall")
	counterfire_every = r.integer(counterfire, "every")
	var projectile_data := r.object(data, "projectiles")
	for id: String in projectile_data:
		r.context = "projectiles.%s" % id
		projectiles[id] = _read_projectile(r, id, r.object(projectile_data, id))
	r.context = ""
	burn_share_per_shot = r.number(r.object(data, "burning"), "share_per_shot")
	fall_damage_share = r.number(r.object(data, "collapse"), "fall_damage_share")
	var wind := r.object(data, "wind")
	wind_min = r.number(wind, "min")
	wind_max = r.number(wind, "max")
	wind_acceleration = r.number(wind, "acceleration_per_mps")
	_read_ballistics(r, r.object(data, "ballistics"))
	var timing := r.object(data, "timing")
	aim_limit_seconds = r.number(timing, "aim_limit_seconds")
	typical_aim_seconds = r.number(timing, "typical_aim_seconds")
	throw_seconds = r.number(timing, "throw_seconds")
	settle_seconds = r.number(timing, "settle_seconds")
	counterfire_seconds = r.number(timing, "counterfire_seconds")
	_read_practice(r, r.object(data, "practice"))
	var ai := r.object(data, "ai")
	campaign_skill = r.integer(ai, "campaign_skill")
	for entry: Variant in r.list(ai, "skills"):
		if entry is Dictionary:
			skills.append(_read_skill(r, entry))
	var layout_data := r.object(data, "layouts")
	for key: String in layout_data:
		r.context = "layouts.%s" % key
		var parts: Array[PartDef] = []
		for entry: Variant in r.list(r.object(layout_data, key), "parts"):
			if entry is Dictionary:
				parts.append(_read_part(r, entry))
		layouts[key] = parts
	r.context = ""


func _read_ballistics(r: DataReader, data: Dictionary) -> void:
	gravity = r.number(data, "gravity")
	var point := r.numbers(data, "release")
	if point.size() == 2:
		release = Vector2(point[0], point[1])
	speed_min = r.number(data, "speed_min")
	speed_max = r.number(data, "speed_max")
	var weights := _pair(r, data, "counterweight")
	counterweight_min = weights[0]
	counterweight_max = weights[1]
	var angles := _pair(r, data, "angle_deg")
	angle_min = angles[0]
	angle_max = angles[1]
	var start := _pair(r, data, "start")
	start_counterweight = start[0]
	start_angle = start[1]
	step_rate = r.integer(data, "step_rate")
	max_flight_seconds = r.number(data, "max_flight_seconds")
	preview_share = r.number(data, "preview_share")
	castle_front = r.number(data, "castle_front")


func _read_practice(r: DataReader, data: Dictionary) -> void:
	practice.attacker_house = r.text(data, "attacker_house")
	practice.defender_owner = r.text(data, "defender_owner")
	practice.wall_level = r.integer(data, "wall_level")
	practice.is_home_castle = r.flag(data, "is_home_castle")
	practice.castle_level = r.integer(data, "castle_level")
	practice.trebuchets = r.integer(data, "trebuchets")
	practice.garrison_health = r.number(data, "garrison_health")
	practice.wall_damage = r.number(data, "wall_damage")
	practice.is_practice = true


func _read_projectile(r: DataReader, id: String, data: Dictionary) -> ProjectileDef:
	var projectile := ProjectileDef.new()
	projectile.id = id
	projectile.damage = r.integer(data, "damage")
	projectile.garrison_damage = r.number(data, "garrison_damage")
	projectile.ignites = r.flag(data, "ignites")
	projectile.speed_factor = r.number(data, "speed_factor")
	return projectile


func _read_skill(r: DataReader, data: Dictionary) -> AiSkill:
	var skill := AiSkill.new()
	skill.aim_seconds = r.number(data, "aim_seconds")
	skill.angle = r.integer(data, "angle_deg")
	skill.wind_awareness = r.number(data, "wind_awareness")
	for value: float in r.numbers(data, "counterweight_errors"):
		skill.counterweight_errors.append(int(value))
	for value: float in r.numbers(data, "angle_errors"):
		skill.angle_errors.append(int(value))
	return skill


func _read_part(r: DataReader, data: Dictionary) -> PartDef:
	var part := PartDef.new()
	part.id = r.text(data, "id")
	part.kind = r.text(data, "kind")
	part.material = r.text(data, "material")
	var rect := r.numbers(data, "rect")
	if rect.size() == 4:
		part.x0 = rect[0]
		part.y0 = rect[1]
		part.x1 = rect[2]
		part.y1 = rect[3]
	else:
		r.errors.append("%s.%s.rect: expected [x0, y0, x1, y1]" % [r.context, part.id])
	part.hp_share = r.number(data, "hp_share")
	part.supported_by = r.strings(data, "supported_by", false)
	part.falls_onto = r.strings(data, "falls_onto", false)
	return part


static func _pair(r: DataReader, data: Dictionary, key: String) -> PackedInt32Array:
	var values := r.numbers(data, key)
	if values.size() != 2:
		r.errors.append("ballistics.%s: expected [low, high]" % key)
		return PackedInt32Array([0, 0])
	return PackedInt32Array([int(values[0]), int(values[1])])
