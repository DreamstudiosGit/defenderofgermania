class_name JoustConfig
extends RefCounted
## Joust values from data/combat_joust.json (GDD "Abenteuer-Module" → "Tjost"), plus the
## leader's lance values (hit window, steadier aim) from data/combat.json.

const PATH := "res://data/combat_joust.json"
const SKILLS := 4

var combat: CombatConfig

var tick_rate: int
var passes: int
## Extra passes when points and stance are level after the regular ones.
var deciding_passes: int
var stance: float

var intro_seconds: float
var ready_seconds: float
var runup_seconds: float
var aim_seconds: float
var clash_seconds: float
var return_seconds: float
var finale_seconds: float

var perfect_stance: float
var normal_stance: float
var perfect_points: int
## A press this close to the impact couches the lance; outside it the lance glances off.
var couch_window_ms: float

var shield_damage_factor: float
## Shield input shorter than this does not count as aligned.
var shield_min_deflection: float
var shield_tolerance_deg: float

var tempo_start: float
var tempo_ideal: float
var tempo_max: float
var beat_seconds: float
var beat_window_ms: float
var tempo_on_beat: float
var tempo_off_beat: float
## Share of the stance hit a rider deals at standstill; it grows to 1 at the ideal tempo.
var min_force: float
## Extra sway per tempo point above the ideal.
var overspeed_sway: float

## Reach of the lance hand around the opponent's chest, in metres.
var aim_range: float
var aim_speed: float
var aim_rest := Vector2.ZERO

var sway_amplitude := Vector2.ZERO
var sway_period := Vector2.ONE
## Gait phase (in cycles) at the start of each pass; repeats for deciding passes.
var sway_pass_phase := PackedFloat64Array()

## Hit zones on the opponent as the attacker sees him (x right, y up, metres from the chest);
## the first zone containing the lance tip counts.
var zones: Array[Zone] = []
## Error patterns of the computer riders, by skill 0–3.
var ai: Array[JoustAIProfile] = []

var prize_gold: float
var fief_satisfaction: float

var errors: PackedStringArray = []


class Zone:
	var id: String
	var center := Vector2.ZERO
	var radius: float
	var points: int


static func load_file(path: String = PATH, combat_path: String = CombatConfig.PATH) -> JoustConfig:
	var combat_config := CombatConfig.load_file(combat_path)
	var data: Variant = DataReader.load_json(path)
	if combat_config == null or not data is Dictionary:
		push_error("%s: expected a JSON object and a valid %s" % [path, combat_path])
		return null
	var config := from_data(data, combat_config)
	for error: String in config.errors:
		push_error("%s: %s" % [path, error])
	return null if config.errors else config


## Reads parsed JSON; every missing, mistyped or implausible value ends up in `errors`.
static func from_data(data: Dictionary, combat_config: CombatConfig) -> JoustConfig:
	var reader := DataReader.new()
	var config := JoustConfig.new()
	config.combat = combat_config
	config._read(reader, data)
	var found := reader.errors
	found.append_array(config._check())
	config.errors = found
	return config


func ticks(seconds: float) -> int:
	return roundi(seconds * tick_rate)


func beats() -> int:
	return floori(runup_seconds / beat_seconds + 1e-6)


## Half-width of the perfect hit window in seconds (GDD: ±(60 + 15 × lance) ms).
func window_seconds(lance: int, house: String) -> float:
	return combat.joust_window_ms(lance, house) / 1000.0


## Sway left after the lance skill steadies the aim (−10 % per point).
func sway_scale(lance: int) -> float:
	return maxf(0.0, 1.0 - combat.sway_reduction_per_lance * lance)


func zone_ids() -> Array[String]:
	var ids: Array[String] = []
	for zone: Zone in zones:
		ids.append(zone.id)
	return ids


func _read(r: DataReader, data: Dictionary) -> void:
	tick_rate = r.integer(data, "tick_rate")
	passes = r.integer(data, "passes")
	deciding_passes = r.integer(data, "deciding_passes")
	stance = r.number(data, "stance")
	var timeline := r.object(data, "timeline")
	intro_seconds = r.number(timeline, "intro_seconds")
	ready_seconds = r.number(timeline, "ready_seconds")
	runup_seconds = r.number(timeline, "runup_seconds")
	aim_seconds = r.number(timeline, "aim_seconds")
	clash_seconds = r.number(timeline, "clash_seconds")
	return_seconds = r.number(timeline, "return_seconds")
	finale_seconds = r.number(timeline, "finale_seconds")
	var strike := r.object(data, "strike")
	perfect_stance = r.number(strike, "perfect_stance")
	normal_stance = r.number(strike, "normal_stance")
	perfect_points = r.integer(strike, "perfect_points")
	couch_window_ms = r.number(strike, "couch_window_ms")
	var shield := r.object(data, "shield")
	shield_damage_factor = r.number(shield, "damage_factor")
	shield_min_deflection = r.number(shield, "min_deflection")
	shield_tolerance_deg = r.number(shield, "tolerance_deg")
	var tempo := r.object(data, "tempo")
	tempo_start = r.number(tempo, "start")
	tempo_ideal = r.number(tempo, "ideal")
	tempo_max = r.number(tempo, "max")
	beat_seconds = r.number(tempo, "beat_seconds")
	beat_window_ms = r.number(tempo, "beat_window_ms")
	tempo_on_beat = r.number(tempo, "on_beat")
	tempo_off_beat = r.number(tempo, "off_beat")
	min_force = r.number(tempo, "min_force")
	overspeed_sway = r.number(tempo, "overspeed_sway")
	var aim := r.object(data, "aim")
	aim_range = r.number(aim, "range")
	aim_speed = r.number(aim, "speed")
	aim_rest = _vector(r, aim, "rest")
	var sway := r.object(data, "sway")
	sway_amplitude = _vector(r, sway, "amplitude")
	sway_period = _vector(r, sway, "period_seconds")
	sway_pass_phase = r.numbers(sway, "pass_phase")
	for entry: Variant in r.list(data, "zones"):
		if entry is Dictionary:
			r.context = "zones"
			zones.append(_read_zone(r, entry))
	r.context = ""
	var profiles := r.list(data, "ai")
	for skill: int in profiles.size():
		r.context = "ai[%d]" % skill
		var entry: Variant = profiles[skill]
		ai.append(JoustAIProfile.read(r, entry if entry is Dictionary else {}))
	r.context = ""
	var rewards := r.object(data, "rewards")
	prize_gold = r.number(rewards, "prize_gold")
	fief_satisfaction = r.number(rewards, "fief_satisfaction")


func _read_zone(r: DataReader, data: Dictionary) -> Zone:
	var zone := Zone.new()
	zone.id = r.text(data, "id")
	zone.center = _vector(r, data, "center")
	zone.radius = r.number(data, "radius")
	zone.points = r.integer(data, "points")
	return zone


func _check() -> PackedStringArray:
	var errors: PackedStringArray = []
	if tick_rate <= 0 or passes < 1 or deciding_passes < 0 or stance <= 0.0:
		errors.append("tick_rate, passes and stance must be positive")
	for seconds: float in [
		intro_seconds, ready_seconds, runup_seconds, aim_seconds, clash_seconds,
		return_seconds, finale_seconds
	]:
		if seconds <= 0.0:
			errors.append("timeline: every phase needs a positive duration")
			break
	if normal_stance < 0.0 or perfect_stance < normal_stance:
		errors.append("strike: perfect_stance must be at least normal_stance >= 0")
	if couch_window_ms <= 0.0 or couch_window_ms / 1000.0 >= clash_seconds:
		errors.append("strike.couch_window_ms: must be positive and end within the clash")
	if shield_damage_factor < 0.0 or shield_damage_factor > 1.0:
		errors.append("shield.damage_factor: must lie in 0..1")
	if shield_tolerance_deg <= 0.0 or shield_tolerance_deg > 180.0:
		errors.append("shield.tolerance_deg: must lie in (0, 180]")
	if tempo_start < 0.0 or tempo_start > tempo_max or tempo_ideal <= 0.0:
		errors.append("tempo: start must lie in 0..max and ideal must be positive")
	if min_force < 0.0 or min_force > 1.0:
		errors.append("tempo.min_force: must lie in 0..1")
	if beat_seconds <= 0.0 or beat_window_ms <= 0.0 or beat_window_ms >= beat_seconds * 500.0:
		errors.append("tempo: beat windows must be positive and must not overlap")
	if aim_range <= 0.0 or aim_speed <= 0.0:
		errors.append("aim: range and speed must be positive")
	if sway_period.x <= 0.0 or sway_period.y <= 0.0 or sway_pass_phase.is_empty():
		errors.append("sway: periods must be positive and pass_phase needs an entry")
	if zones.is_empty():
		errors.append("zones: needs at least one hit zone")
	var ids := zone_ids()
	for i: int in zones.size():
		if zones[i].radius <= 0.0 or zones[i].points < 0 or ids.find(zones[i].id) != i:
			errors.append("zones[%d]: needs a unique id, a positive radius and points" % i)
	if ai.size() != SKILLS:
		errors.append("ai: needs one error pattern per skill 0..%d" % (SKILLS - 1))
	for skill: int in ai.size():
		errors.append_array(ai[skill].check("ai[%d]" % skill, beats(), ids))
	if prize_gold < 0.0:
		errors.append("rewards.prize_gold: must not be negative")
	return errors


static func _vector(r: DataReader, data: Dictionary, key: String) -> Vector2:
	var values := r.numbers(data, key)
	if values.size() != 2:
		var where := key if r.context.is_empty() else "%s.%s" % [r.context, key]
		r.errors.append("%s: expected [x, y]" % where)
		return Vector2.ZERO
	return Vector2(values[0], values[1])
