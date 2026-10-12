class_name AiTargets
extends RefCounted
## What provinces are worth to a computer house on campaign: conquest value (legitimacy,
## votes, land; church land and an elector's anger cost), the pillars of the crown it marches
## towards (a pull that grows nearer the goal), and going home when the home is threatened.


## Provinces the house wants: coronation sites, the true regalia and the electors it does not
## hold, and the leader's land (anti-leader); value in taler.
static func goals(turn: AiTurn, leader: String) -> Dictionary[String, float]:
	var result: Dictionary[String, float] = {}
	var state := turn.state
	var map := turn.rules.map
	for id: String in map.provinces:
		if state.provinces[id].owner == turn.house:
			continue
		var worth := conquest_worth(turn, id, leader)
		var important := id == state.crown.regalia_province or id in map.electors()
		for site: String in map.crown.archbishops:
			important = important or site in map.provinces[id].tags
		important = important or state.provinces[id].owner == leader
		if important and worth > 0.0:
			result[id] = worth
	_exile_goals(turn, result)
	return result


## In exile the house must take its old home or a castle from the exile level within a few
## rounds, or it is out.
static func _exile_goals(turn: AiTurn, result: Dictionary[String, float]) -> void:
	var owner := turn.owner()
	if owner.exile_rounds <= 0:
		return
	var state := turn.state
	var urgency := turn.value("province") * turn.cfg.values["exile"]
	for id: String in turn.rules.map.provinces:
		var province := state.provinces[id]
		if province.owner == turn.house:
			continue
		if id == owner.home_province:
			result[id] = result.get(id, 0.0) + urgency * 2.0
		elif province.castle_level >= turn.rules.map.campaign.exile_min_castle_level:
			result[id] = result.get(id, 0.0) + urgency


## Provinces the house must not lose: the home castle, the true regalia and coronation sites
## it holds.
static func keys(turn: AiTurn) -> Array[String]:
	var result: Array[String] = []
	var state := turn.state
	var map := turn.rules.map
	for province: ProvinceState in state.provinces_of(turn.house):
		var key := province.id == turn.owner().home_province
		key = key or province.id == state.crown.regalia_province
		for site: String in map.crown.archbishops:
			key = key or site in map.provinces[province.id].tags
		if key:
			result.append(province.id)
	return result


## Pull of every province towards the goals: the best goal's value over the squared distance.
static func pull(turn: AiTurn, goals: Dictionary[String, float]) -> Dictionary[String, float]:
	var result: Dictionary[String, float] = {}
	for goal: String in goals:
		var steps := distances(turn.rules.map, goal)
		for id: String in steps:
			var value := goals[goal] / pow(1.0 + steps[id], 2.0)
			if value > result.get(id, 0.0):
				result[id] = value
	return result


## Steps from the province to every other (breadth-first over the neighbours).
static func distances(map: MapData, from: String) -> Dictionary[String, int]:
	var steps: Dictionary[String, int] = {from: 0}
	var queue: Array[String] = [from]
	while not queue.is_empty():
		var id: String = queue.pop_front()
		for next: String in map.provinces[id].neighbors:
			if not steps.has(next):
				steps[next] = steps[id] + 1
				queue.append(next)
	return steps


## Taler worth of taking the province from its owner.
static func conquest_worth(turn: AiTurn, province_id: String, leader: String) -> float:
	var state := turn.state
	var map := turn.rules.map
	var province := state.provinces[province_id]
	if province.owner == turn.house:
		return 0.0
	var def := map.provinces[province_id]
	var worth := turn.value("province") + province.population * 0.5
	for tag: String in def.tags:
		if tag != CrownRules.REGALIA_TAG:
			worth += map.campaign.legitimacy_tags.get(tag, 0.0) * turn.value("legitimacy")
	if state.crown.regalia_province == province_id:
		# Forged regalia give the pillar too; the true ones only add legitimacy and spare a vote.
		var weight: float = map.campaign.legitimacy_tags.get(CrownRules.REGALIA_TAG, 0.0)
		worth += (weight - map.campaign.legitimacy_forged_regalia) * turn.value("legitimacy")
		worth += turn.pillar_worth() / 4.0
	for site: String in map.crown.archbishops:
		var holds_one := false
		for any: String in map.crown.archbishops:
			holds_one = holds_one or CrownRules.holds_site(state, map, turn.house, any)
		if site in def.tags and not holds_one:
			worth += turn.pillar_worth()
	if province_id in map.electors():
		worth += turn.pillar_worth() / 4.0
		worth += map.crown.favour_changes["occupation_others"] * 6.0 * turn.value("favour")
	if def.is_church:
		worth -= map.crown.ban_attack_church_chance * turn.value("vote") * 2.0
	if province.castle_level > 0:
		worth *= 0.6
	if not leader.is_empty() and leader != turn.house:
		if province.owner == leader:
			var key := "coalition_weight" if turn.level.coalition else "attack_weight"
			worth *= turn.cfg.anti_leader[key]
		elif turn.level.coalition and state.houses.has(province.owner):
			worth *= 0.5
	return worth * turn.weight("military")


## Going home when the home province is threatened and the army is away; leaving it then is bad.
static func defense_worth(turn: AiTurn, army: ArmyState, target: String) -> float:
	var state := turn.state
	var home := turn.owner().home_province
	if state.provinces[home].owner != turn.house:
		return 0.0
	var gap := turn.threat(home)
	gap -= AiStrength.defense(state, turn.rules, turn.house, home)
	if gap <= 0.0:
		return 0.0
	var steps := distances(turn.rules.map, home)
	var closer: int = steps.get(army.province, 9) - steps.get(target, 9)
	return closer * turn.value("province") * turn.cfg.security["home_weight"]
