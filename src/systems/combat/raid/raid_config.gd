class_name RaidConfig
extends RefCounted
## Castle raid values from data/combat_raid.json (GDD "Burgüberfall") plus the leader's blade
## values from data/combat.json (CombatConfig, shared with the joust).

const PATH := "res://data/combat_raid.json"
const TARGETS: Array[String] = ["treasury", "dungeon", "granary", "regalia"]
const SKILLS := 4

var tick_rate: int
var time_limit_seconds: float
var alarm_seconds: float
var parry_window_base_ms: float
var parry_window_per_blade_ms: float
var damage_per_blade: float
var max_blade: int
var intro_seconds: float
var outro_seconds: float

var leader_health: float
var stamina: float
var stamina_regen_per_second: float
var stamina_regen_delay_ms: float
var walk_speed: float
var strike_damage: float
var strike_cost: float
var parry_cost: float
var strike_windup_ms: float
var strike_recover_ms: float
var blocked_recover_ms: float
var parry_recover_ms: float
var leader_stagger_ms: float
var reach: float

var guard_speed: float
var engage_distance: float
var fight_distance: float
var queue_gap: float
var guard_stagger_ms: float
## Damage share of a blow that hits a guard in the middle of its own swing.
var windup_damage_factor: float
var guard_skills: Array[RaidRules.GuardSkill] = []

var home_castles: Dictionary[int, RaidRules.Castle] = {}
var province_castles: Dictionary[int, RaidRules.Castle] = {}
var layout := RaidRules.Layout.new()
var targets: Dictionary[String, RaidRules.Target] = {}
## Chance that a raid on church land brings the ban; applied by the campaign.
var church_ban_chance: float
var ai_skills: Array[RaidRules.AiSkill] = []


static func load_file(path: String = PATH, combat: CombatConfig = null) -> RaidConfig:
	if combat == null:
		combat = CombatConfig.load_file()
	var data: Variant = DataReader.load_json(path)
	if combat == null or not data is Dictionary:
		push_error("%s: expected a JSON object and a valid data/combat.json" % path)
		return null
	return from_data(data, combat, path)


## Reads parsed raid data; reports every problem and returns null if there is any.
static func from_data(data: Dictionary, combat: CombatConfig, path: String = PATH) -> RaidConfig:
	var reader := DataReader.new()
	var config := RaidConfig.new()
	config.parry_window_per_blade_ms = combat.parry_window_per_blade_ms
	config.damage_per_blade = combat.damage_per_blade
	config._read(reader, data)
	config._check(reader)
	for error: String in reader.errors:
		push_error("%s: %s" % [path, error])
	return null if reader.errors else config


## GDD: parry window 150 + 20 × blade ms.
func parry_window_ms(blade: int) -> float:
	return parry_window_base_ms + parry_window_per_blade_ms * blade


## GDD: sword damage +10 % per blade point.
func strike_damage_for(blade: int) -> float:
	return strike_damage * (1.0 + damage_per_blade * blade)


## Guards, sneak paths and reinforcements of a castle; null if the level has no castle.
func castle(home: bool, level: int) -> RaidRules.Castle:
	var table := home_castles if home else province_castles
	return table.get(level, null)


func prestige(target: String) -> float:
	return targets[target].prestige if targets.has(target) else 0.0


## Taler a successful treasury raid takes: 20 % of the enemy's taler, at most 200.
func treasury_loot(enemy_taler: int) -> int:
	var rules := targets["treasury"]
	return mini(floori(maxi(enemy_taler, 0) * rules.taler_share), roundi(rules.taler_max))


## Grain a burnt granary costs the enemy: 30 % of its grain.
func granary_loss(enemy_grain: float) -> float:
	return maxf(enemy_grain, 0.0) * targets["granary"].grain_loss


func ticks(ms: float) -> int:
	return maxi(1, roundi(ms * tick_rate / 1000.0))


func seconds_to_ticks(seconds: float) -> int:
	return roundi(seconds * tick_rate)


## Ticks a parry stays up: a parry pressed k ticks before the blow lands holds if
## k × tick ≤ window, so k = 0 … floor(window / tick).
func parry_ticks(blade: int) -> int:
	return floori(parry_window_ms(blade) * tick_rate / 1000.0 + 1e-6) + 1


func _read(r: DataReader, data: Dictionary) -> void:
	tick_rate = r.integer(data, "tick_rate")
	time_limit_seconds = r.number(data, "time_limit_seconds")
	alarm_seconds = r.number(data, "alarm_seconds")
	parry_window_base_ms = r.number(data, "parry_window_base_ms")
	max_blade = r.integer(data, "max_blade")
	intro_seconds = r.number(data, "intro_seconds")
	outro_seconds = r.number(data, "outro_seconds")
	church_ban_chance = r.number(data, "church_ban_chance")
	_read_leader(r, r.object(data, "leader"))
	_read_guards(r, r.object(data, "guards"))
	var castles := r.object(data, "castles")
	r.context = "castles.home"
	home_castles = RaidRules.Castle.read_table(r, r.object(castles, "home"))
	r.context = "castles.province"
	province_castles = RaidRules.Castle.read_table(r, r.object(castles, "province"))
	r.context = "layout"
	layout = RaidRules.Layout.read(r, r.object(data, "layout"))
	var target_data := r.object(data, "targets")
	for id: String in target_data:
		r.context = "targets.%s" % id
		targets[id] = RaidRules.Target.read(r, r.object(target_data, id))
	var ai_data := r.list(data, "ai_skills")
	for i: int in ai_data.size():
		r.context = "ai_skills[%d]" % i
		ai_skills.append(RaidRules.AiSkill.read(r, ai_data[i] if ai_data[i] is Dictionary else {}))
	r.context = ""


func _read_leader(r: DataReader, leader: Dictionary) -> void:
	r.context = "leader"
	leader_health = r.number(leader, "health")
	stamina = r.number(leader, "stamina")
	stamina_regen_per_second = r.number(leader, "stamina_regen_per_second")
	stamina_regen_delay_ms = r.number(leader, "stamina_regen_delay_ms")
	walk_speed = r.number(leader, "walk_speed")
	strike_damage = r.number(leader, "strike_damage")
	strike_cost = r.number(leader, "strike_cost")
	parry_cost = r.number(leader, "parry_cost")
	strike_windup_ms = r.number(leader, "strike_windup_ms")
	strike_recover_ms = r.number(leader, "strike_recover_ms")
	blocked_recover_ms = r.number(leader, "blocked_recover_ms")
	parry_recover_ms = r.number(leader, "parry_recover_ms")
	leader_stagger_ms = r.number(leader, "hit_stagger_ms")
	reach = r.number(leader, "reach")


func _read_guards(r: DataReader, guards: Dictionary) -> void:
	r.context = "guards"
	guard_speed = r.number(guards, "approach_speed")
	engage_distance = r.number(guards, "engage_distance")
	fight_distance = r.number(guards, "fight_distance")
	queue_gap = r.number(guards, "queue_gap")
	guard_stagger_ms = r.number(guards, "hit_stagger_ms")
	windup_damage_factor = r.number(guards, "windup_damage_factor")
	var skills := r.list(guards, "skills")
	for i: int in skills.size():
		r.context = "guards.skills[%d]" % i
		var entry: Dictionary = skills[i] if skills[i] is Dictionary else {}
		guard_skills.append(RaidRules.GuardSkill.read(r, entry))


func _check(r: DataReader) -> void:
	r.context = ""
	if tick_rate <= 0 or time_limit_seconds <= 0.0:
		r.errors.append("tick_rate and time_limit_seconds must be positive")
	if alarm_seconds <= 0.0 or alarm_seconds >= time_limit_seconds:
		r.errors.append("alarm_seconds must lie inside the time limit")
	if guard_skills.size() != SKILLS or ai_skills.size() != SKILLS:
		r.errors.append("guards.skills and ai_skills need %d entries (skill 0–3)" % SKILLS)
	if fight_distance >= engage_distance or fight_distance >= reach:
		r.errors.append("guards.fight_distance must be below engage_distance and leader.reach")
	if layout.sneak_before <= engage_distance:
		r.errors.append("layout.sneak_before must keep sneak entries out of a guard's sight")
	for target: String in TARGETS:
		if not targets.has(target):
			r.errors.append("targets: missing '%s'" % target)
	for id: String in targets:
		if id not in TARGETS:
			r.errors.append("targets: unknown target '%s'" % id)
	if targets.has("treasury") and targets["treasury"].taler_max <= 0.0:
		r.errors.append("targets.treasury: taler_share and taler_max must be positive")
	if targets.has("granary") and targets["granary"].grain_loss <= 0.0:
		r.errors.append("targets.granary: grain_loss must be positive")
	for table: Dictionary[int, RaidRules.Castle] in [home_castles, province_castles]:
		for level: int in table:
			table[level].check(r, level)
	if home_castles.is_empty() or province_castles.is_empty():
		r.errors.append("castles: home and province need at least one level")
