class_name MerchantConfig
extends RefCounted
## Merchant train raid values from data/combat_merchant.json (GDD "Kaufmannszug"): the train,
## the leader's moves, the crossbow, the ambushing companies, the escorts' fixed patterns per
## skill and the computer raider's fixed error patterns per skill. Road positions are metres;
## the rear wagon starts at 0 and the train rolls towards the town gate (+x).

const PATH := "res://data/combat_merchant.json"
## Escort and raider skills 0 (sloppy) … 3 (veterans).
const SKILLS := 4

var wagons: int
## Seconds until the rear wagon reaches the gate; the gate lies where it gets by then.
var train_seconds: float
var intro_seconds: float
var outro_seconds: float
var wagon_speed: float
var wagon_spacing: float
var cargo_min: int
var cargo_max: int
## Driver's box and draught horses ahead of the wagon's centre.
var box_ahead: float
var horses_ahead: float

var leader_start_behind: float
var leader_speed: float
var leader_acceleration: float
## Escort blows the leader takes before the escorts pull him off his horse.
var composure: int
var stun_seconds: float
var gate_keep_away: float
var strike_reach: float
var strike_damage: float
var strike_seconds: float
var parry_window_ms: float
var parry_cooldown: float
var pull_reach: float
var pull_seconds: float

var reload_seconds: float
## Bolts the leader carries; a miss costs one like a hit.
var bolts: int
var range_min: float
var range_max: float
var sway_period: float
var sway_still: float
var sway_riding: float
var hit_window: float

var max_companies: int
var company_figures: int
## Ambush points as shares of the road from the leader's start to the gate.
var ambush_at := PackedFloat64Array()
var company_speed_factor: float
var engage_range: float
var company_reach: float
var company_pull_seconds: float
var fight_seconds: float
var reference_melee: float
var reference_guard: float

var escort_reach: float
var stagger_seconds: float
var post_jitter: float
## Notice range factor once the first wagon stopped: the whole escort comes running.
var alarm_notice_factor: float
var escort_skills: Array[EscortSkill] = []
var raider_skills: Array[RaiderSkill] = []


## One escort pattern: shield up (cover), wind-up, blow, recovery — always in this order.
class EscortSkill:
	var count: int
	var speed: float
	var notice_range: float
	var cover_seconds: float
	var windup_seconds: float
	var recover_seconds: float
	var down_seconds: float
	var guard: float


## The computer raider's fixed mistakes: slow decisions, parries off by a repeating list of
## milliseconds, shots loosed while the aim still sways, pauses.
class RaiderSkill:
	var think_seconds: float
	var parry_errors_ms := PackedFloat64Array()
	var aim_factor: float
	var fights_escorts: bool
	var hesitate_every_seconds: float
	var hesitate_seconds: float


static func load_file(path: String = PATH) -> MerchantConfig:
	var data: Variant = DataReader.load_json(path)
	if not data is Dictionary:
		push_error("%s: expected a JSON object" % path)
		return null
	var reader := DataReader.new()
	var config := read(reader, data)
	for error: String in reader.errors:
		push_error("%s: %s" % [path, error])
	return null if reader.errors else config


## Reads and checks parsed data; problems go to reader.errors.
static func read(reader: DataReader, data: Dictionary) -> MerchantConfig:
	var config := MerchantConfig.new()
	config._read(reader, data)
	config._check(reader)
	return config


func gate_x() -> float:
	return wagon_speed * train_seconds


## Start of wagon w; wagon 0 leads the train.
func wagon_start(w: int) -> float:
	return (wagons - 1 - w) * wagon_spacing


func leader_start() -> float:
	return -leader_start_behind


func escort_skill(skill: int) -> EscortSkill:
	return escort_skills[clampi(skill, 0, escort_skills.size() - 1)]


func raider_skill(skill: int) -> RaiderSkill:
	return raider_skills[clampi(skill, 0, raider_skills.size() - 1)]


func min_escorts() -> int:
	var lowest := 1 << 30
	for skill: EscortSkill in escort_skills:
		lowest = mini(lowest, skill.count)
	return lowest


func max_escorts() -> int:
	var highest := 0
	for skill: EscortSkill in escort_skills:
		highest = maxi(highest, skill.count)
	return highest


func _read(r: DataReader, data: Dictionary) -> void:
	r.context = ""
	var train := r.object(data, "train")
	r.context = "train"
	wagons = r.integer(train, "wagons")
	train_seconds = r.number(train, "train_seconds")
	intro_seconds = r.number(train, "intro_seconds")
	outro_seconds = r.number(train, "outro_seconds")
	wagon_speed = r.number(train, "wagon_speed")
	wagon_spacing = r.number(train, "wagon_spacing")
	var cargo := r.numbers(train, "cargo_taler")
	if cargo.size() == 2:
		cargo_min = int(cargo[0])
		cargo_max = int(cargo[1])
	else:
		r.errors.append("train.cargo_taler: expected [min, max]")
	box_ahead = r.number(train, "box_ahead")
	horses_ahead = r.number(train, "horses_ahead")
	r.context = ""
	var leader := r.object(data, "leader")
	var crossbow := r.object(data, "crossbow")
	var companies := r.object(data, "companies")
	var escorts := r.object(data, "escorts")
	_read_leader(r, leader)
	_read_crossbow(r, crossbow)
	_read_companies(r, companies)
	r.context = "escorts"
	escort_reach = r.number(escorts, "reach")
	stagger_seconds = r.number(escorts, "stagger_seconds")
	post_jitter = r.number(escorts, "post_jitter")
	alarm_notice_factor = r.number(escorts, "alarm_notice_factor")
	var skills := r.list(escorts, "skills")
	for i: int in skills.size():
		r.context = "escorts.skills[%d]" % i
		escort_skills.append(_read_escort(r, skills[i] if skills[i] is Dictionary else {}))
	r.context = ""
	var raiders := r.list(data, "raider_ai")
	for i: int in raiders.size():
		r.context = "raider_ai[%d]" % i
		raider_skills.append(_read_raider(r, raiders[i] if raiders[i] is Dictionary else {}))
	r.context = ""


func _read_leader(r: DataReader, leader: Dictionary) -> void:
	r.context = "leader"
	leader_start_behind = r.number(leader, "start_behind")
	leader_speed = r.number(leader, "speed")
	leader_acceleration = r.number(leader, "acceleration")
	composure = r.integer(leader, "composure")
	stun_seconds = r.number(leader, "stun_seconds")
	gate_keep_away = r.number(leader, "gate_keep_away")
	strike_reach = r.number(leader, "strike_reach")
	strike_damage = r.number(leader, "strike_damage")
	strike_seconds = r.number(leader, "strike_seconds")
	parry_window_ms = r.number(leader, "parry_window_ms")
	parry_cooldown = r.number(leader, "parry_cooldown_seconds")
	pull_reach = r.number(leader, "pull_reach")
	pull_seconds = r.number(leader, "pull_seconds")


func _read_crossbow(r: DataReader, crossbow: Dictionary) -> void:
	r.context = "crossbow"
	reload_seconds = r.number(crossbow, "reload_seconds")
	bolts = r.integer(crossbow, "bolts")
	var reach := r.numbers(crossbow, "range")
	if reach.size() == 2:
		range_min = reach[0]
		range_max = reach[1]
	else:
		r.errors.append("crossbow.range: expected [min, max]")
	sway_period = r.number(crossbow, "sway_period_seconds")
	sway_still = r.number(crossbow, "sway_still")
	sway_riding = r.number(crossbow, "sway_riding")
	hit_window = r.number(crossbow, "hit_window")


func _read_companies(r: DataReader, companies: Dictionary) -> void:
	r.context = "companies"
	max_companies = r.integer(companies, "max")
	company_figures = r.integer(companies, "figures")
	ambush_at = r.numbers(companies, "ambush_at")
	company_speed_factor = r.number(companies, "speed_factor")
	engage_range = r.number(companies, "engage_range")
	company_reach = r.number(companies, "reach")
	company_pull_seconds = r.number(companies, "pull_seconds")
	fight_seconds = r.number(companies, "fight_seconds")
	reference_melee = r.number(companies, "reference_melee")
	reference_guard = r.number(companies, "reference_guard")


func _read_escort(r: DataReader, entry: Dictionary) -> EscortSkill:
	var skill := EscortSkill.new()
	skill.count = r.integer(entry, "count")
	skill.speed = r.number(entry, "speed")
	skill.notice_range = r.number(entry, "notice_range")
	skill.cover_seconds = r.number(entry, "cover_seconds")
	skill.windup_seconds = r.number(entry, "windup_seconds")
	skill.recover_seconds = r.number(entry, "recover_seconds")
	skill.down_seconds = r.number(entry, "down_seconds")
	skill.guard = r.number(entry, "guard")
	return skill


func _read_raider(r: DataReader, entry: Dictionary) -> RaiderSkill:
	var skill := RaiderSkill.new()
	skill.think_seconds = r.number(entry, "think_seconds")
	skill.parry_errors_ms = r.numbers(entry, "parry_errors_ms")
	skill.aim_factor = r.number(entry, "aim_factor")
	skill.fights_escorts = r.flag(entry, "fights_escorts")
	skill.hesitate_every_seconds = r.number(entry, "hesitate_every_seconds")
	skill.hesitate_seconds = r.number(entry, "hesitate_seconds")
	return skill


func _check(r: DataReader) -> void:
	var positive := {
		"train.wagons": wagons, "train.train_seconds": train_seconds,
		"train.wagon_speed": wagon_speed, "train.wagon_spacing": wagon_spacing,
		"leader.speed": leader_speed, "leader.acceleration": leader_acceleration,
		"leader.composure": composure, "leader.strike_reach": strike_reach,
		"leader.strike_damage": strike_damage, "leader.pull_reach": pull_reach,
		"leader.pull_seconds": pull_seconds, "crossbow.reload_seconds": reload_seconds,
		"crossbow.sway_period_seconds": sway_period, "crossbow.hit_window": hit_window,
		"companies.figures": company_figures, "companies.speed_factor": company_speed_factor,
		"companies.reach": company_reach, "companies.pull_seconds": company_pull_seconds,
		"companies.fight_seconds": fight_seconds, "companies.reference_melee": reference_melee,
		"companies.reference_guard": reference_guard, "escorts.reach": escort_reach,
		"escorts.alarm_notice_factor": alarm_notice_factor,
	}
	for key: String in positive:
		if float(positive[key]) <= 0.0:
			r.errors.append("%s: must be above 0" % key)
	if cargo_min < 0 or cargo_min > cargo_max:
		r.errors.append("train.cargo_taler: expected 0 <= min <= max")
	if range_min < 0.0 or range_min >= range_max:
		r.errors.append("crossbow.range: expected 0 <= min < max")
	if wagon_start(0) >= gate_x():
		r.errors.append("train: the leading wagon starts at or behind the gate")
	if ambush_at.size() < max_companies:
		r.errors.append("companies.ambush_at: needs one point per company (%d)" % max_companies)
	for share: float in ambush_at:
		if share <= 0.0 or share >= 1.0:
			r.errors.append("companies.ambush_at: shares must lie between 0 and 1")
	if escort_skills.size() != SKILLS:
		r.errors.append("escorts.skills: expected %d skills" % SKILLS)
	for i: int in escort_skills.size():
		var skill := escort_skills[i]
		if skill.count < 1 or skill.speed <= 0.0 or skill.guard <= 0.0:
			r.errors.append("escorts.skills[%d]: count, speed and guard must be above 0" % i)
		if skill.cover_seconds <= 0.0 or skill.windup_seconds <= 0.0:
			r.errors.append("escorts.skills[%d]: cover and wind-up must be above 0" % i)
	if raider_skills.size() != SKILLS:
		r.errors.append("raider_ai: expected %d skills" % SKILLS)
	for i: int in raider_skills.size():
		var raider := raider_skills[i]
		if raider.parry_errors_ms.is_empty() or raider.think_seconds <= 0.0:
			r.errors.append("raider_ai[%d]: needs parry errors and a think time above 0" % i)
