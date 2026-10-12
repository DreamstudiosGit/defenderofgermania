class_name AiStrength
extends RefCounted
## How strong armies and garrisons are, judged with the auto-resolve's strength K, and the
## pillars of the crown each house holds (for the anti-leader logic).


## Strength of a battle side on its own (no enemy, open field).
static func side_power(rules: GameRules, side: BattleSide) -> float:
	if side.company_count() == 0 and not side.has_leader:
		return 0.0
	var combat := rules.combat
	var morale := AutoResolve.morale(combat, side, false)
	return AutoResolve.strength(combat, side, BattleSide.new(), 1.0, morale)


static func army_power(state: GameState, rules: GameRules, army: ArmyState) -> float:
	return side_power(rules, CampaignBattles.army_side(state, rules, army))


## The attacker's chance to win the battle, by the auto-resolve's formula.
static func win_chance(rules: GameRules, setup: BattleSetup) -> float:
	if setup.defender.company_count() == 0 and not setup.defender.has_leader:
		return 1.0
	var k := AutoResolve.strengths(rules.combat, setup)
	return AutoResolve.win_chance(rules.combat, k[0], k[1])


## Enemy strength that could strike the province soon: hostile house armies within `radius`
## steps (1: next round).
static func threat(
	state: GameState, rules: GameRules, house: String, province_id: String, radius: int = 1
) -> float:
	var total := 0.0
	var steps := AiTargets.distances(rules.map, province_id)
	for id: String in steps:
		if steps[id] > radius:
			continue
		for army: ArmyState in state.armies_in(id):
			if army.owner != house and state.houses.has(army.owner):
				total += army_power(state, rules, army)
	return total


## Own armies in the province plus its garrison, strengthened by the walls.
static func defense(
	state: GameState, rules: GameRules, house: String, province_id: String
) -> float:
	var total := 0.0
	for army: ArmyState in state.armies_in(province_id):
		if army.owner == house:
			total += army_power(state, rules, army)
	var garrison := side_power(rules, Garrisons.side(state, rules, province_id))
	var wall := Garrisons.wall(state, rules, province_id)
	return total + garrison * (1.0 + rules.combat.castle_per_wall * wall)


## Pillars of the crown the house holds: regalia, a coronation site, and the votes of the
## cheapest coronation row.
static func pillars(state: GameState, rules: GameRules, house: String) -> int:
	var count := 0
	if not CrownRules.regalia(state, house).is_empty():
		count += 1
	for site: String in rules.map.crown.archbishops:
		if CrownRules.holds_site(state, rules.map, house, site):
			count += 1
			break
	var fewest := 99
	for rule: CrownData.CoronationRule in rules.map.crown.coronation:
		fewest = mini(fewest, rule.votes)
	if CrownRules.vote_count(state, rules.map, house) >= fewest:
		count += 1
	return count


## The house the others gang up on: the one with the most pillars from the threshold on; ""
## when nobody (or more than one) leads.
static func leader(state: GameState, rules: GameRules, threshold: int) -> String:
	var best := ""
	var most := threshold - 1
	var tied := false
	for house: HouseState in state.houses.values():
		if house.is_eliminated:
			continue
		var held := pillars(state, rules, house.id)
		if held > most:
			best = house.id
			most = held
			tied = false
		elif held == most and held >= threshold:
			tied = true
	return "" if tied else best
