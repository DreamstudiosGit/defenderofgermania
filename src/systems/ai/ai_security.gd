class_name AiSecurity
extends RefCounted
## Decision level 2, security (GDD): a threat map of enemy strength next to the own provinces
## against their garrisons and armies; the threatened home province comes first. Threatened
## castles recruit defenders; in quiet times the leader's army grows to the size the
## personality wants, as long as the treasury carries the upkeep.


static func run(turn: AiTurn) -> void:
	for province_id: String in _by_danger(turn):
		_defend(turn, province_id)


## Own provinces with a castle, the most endangered first (the home province weighs double).
static func _by_danger(turn: AiTurn) -> Array[String]:
	var danger: Dictionary[String, float] = {}
	var owner := turn.owner()
	for province: ProvinceState in turn.state.provinces_of(turn.house):
		if province.castle_level == 0:
			continue
		var gap := AiStrength.threat(turn.state, turn.rules, turn.house, province.id)
		gap -= AiStrength.defense(turn.state, turn.rules, turn.house, province.id)
		if province.id == owner.home_province:
			gap *= turn.cfg.security["home_weight"]
		danger[province.id] = gap
	var ids: Array[String] = []
	ids.assign(danger.keys())
	ids.sort_custom(func(a: String, b: String) -> bool: return danger[a] > danger[b])
	return ids


static func _defend(turn: AiTurn, province_id: String) -> void:
	var state := turn.state
	var needed := AiStrength.threat(state, turn.rules, turn.house, province_id)
	needed *= turn.cfg.security["defenders_per_threat"]
	var guard := 0
	while needed > 0.0 and guard < 6:
		guard += 1
		var defense := AiStrength.defense(state, turn.rules, turn.house, province_id)
		if defense >= needed * turn.cfg.security["threat_ratio"]:
			return
		if not recruit(turn, province_id, "defend " + province_id):
			return


## Goal options to strengthen the army the leader rides with (or forms at home), worth more
## while it is below the share of its room the personality wants.
static func field_options(turn: AiTurn) -> Array[AiOption]:
	var result: Array[AiOption] = []
	var owner := turn.owner()
	var army := turn.state.army(owner.leader_army)
	var province := army.province if army != null else owner.home_province
	var room := turn.rules.map.campaign.max_companies(true, owner.leadership)
	var wanted := roundi(room * clampf(0.45 * turn.weight("military"), 0.3, 0.9))
	var size := army.company_count() if army != null else 0
	var urge := 1.0 if size < wanted else 0.25
	var target := army.id if army != null else RecruitCommand.AUTO_ARMY
	for option: AiOption in unit_options(turn, province, "field army", target):
		option.utility *= urge * turn.weight("military") * 0.01 * turn.value("province")
		result.append(option)
	return result


## Recruits the best unit the province offers for its cost, against the enemies' main group
## when the difficulty counters; false if nothing could be recruited.
static func recruit(
	turn: AiTurn, province_id: String, reason: String, army_id: int = RecruitCommand.AUTO_ARMY
) -> bool:
	var choice := turn.choose(unit_options(turn, province_id, reason, army_id))
	return choice != null and turn.act(choice.command, choice.label, choice.utility)


## One option per unit the rules let the house recruit there, valued as strength per taler
## (cost plus eight rounds of upkeep) while the treasury carries the upkeep.
static func unit_options(
	turn: AiTurn, province_id: String, reason: String, army_id: int
) -> Array[AiOption]:
	var cfg := turn.rules.economy
	var upkeep_room := EconomyTerm.sum(
		EconomyBreakdown.gold_change(turn.state, turn.rules.map, cfg, turn.house)
	)
	var counter := _enemy_group(turn) if turn.level.counters else ""
	var options: Array[AiOption] = []
	for unit: String in cfg.units:
		var def := cfg.units[unit]
		var combat := turn.rules.combat.units[unit]
		if def.is_mercenary or combat.group == TrebuchetCommand.SIEGE_GROUP:
			continue
		if def.upkeep_gold > upkeep_room * turn.cfg.army["max_share_of_income"] + 1.0:
			continue
		var cost := RecruitCommand.unit_cost(cfg, turn.house, unit)
		if turn.owner().gold - cost < turn.reserve():
			continue
		var power := combat.auto_resolve
		if not counter.is_empty() and counter in combat.strong_against:
			power *= 1.0 + turn.rules.combat.counter_bonus
		var command := RecruitCommand.new(
			cfg, turn.rules.map, turn.house, province_id, unit, army_id
		)
		var worth := power * 100.0 / (cost + def.upkeep_gold * 8.0)
		var option := AiOption.create("%s: recruit %s" % [reason, unit], worth, command, cost)
		option.upkeep = def.upkeep_gold
		options.append(option)
	return options


## Unit type most common among the enemy armies within two provinces of the own land.
static func _enemy_group(turn: AiTurn) -> String:
	var counts: Dictionary[String, int] = {}
	for army: ArmyState in turn.state.armies:
		if army.owner == turn.house or not turn.state.houses.has(army.owner):
			continue
		for unit: String in army.units:
			counts[unit] = counts.get(unit, 0) + 1
	var best := ""
	for unit: String in counts:
		if best.is_empty() or counts[unit] > counts[best]:
			best = unit
	return best
