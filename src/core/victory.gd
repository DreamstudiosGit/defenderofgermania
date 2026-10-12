class_name Victory
extends RefCounted
## Victory by subjugation (every other house eliminated) or by the highest legitimacy once
## the last round is settled. Coronation wins through CoronationCommand.


## Ends the game if a house has won; sets state.winner and the GAME_OVER phase.
static func check(state: GameState, rules: GameRules) -> void:
	var alive: Array[String] = []
	for house: HouseState in state.houses.values():
		if not house.is_eliminated:
			alive.append(house.id)
	alive.sort()
	if alive.size() <= 1:
		_finish(state, alive[0] if alive.size() == 1 else "")
	elif state.turn >= rules.map.campaign.max_rounds:
		_finish(state, _most_legitimate(state, rules, alive))


## L = 30·true regalia + 10·forged regalia + 20·Aachen + 10·Mainz + 10·votes + 2·provinces
## + prestige/5 (weights from data). The true regalia count where they lie now, which a
## castle raid can change.
static func legitimacy(state: GameState, rules: GameRules, house_id: String) -> float:
	var tags: Array[String] = []
	var owned := state.provinces_of(house_id)
	for province: ProvinceState in owned:
		for tag: String in rules.map.provinces[province.id].tags:
			if tag != CrownRules.REGALIA_TAG:
				tags.append(tag)
	if CrownRules.holds_true_regalia(state, house_id):
		tags.append(CrownRules.REGALIA_TAG)
	return rules.map.campaign.legitimacy(
		tags,
		owned.size(),
		state.houses[house_id].prestige,
		house_id in state.crown.forged_regalia,
		CrownRules.vote_count(state, rules.map, house_id)
	)


## Ties go to the house that comes first alphabetically, so the result stays deterministic.
static func _most_legitimate(state: GameState, rules: GameRules, houses: Array[String]) -> String:
	var best := houses[0]
	var best_value := legitimacy(state, rules, best)
	for id: String in houses:
		var value := legitimacy(state, rules, id)
		if value > best_value:
			best = id
			best_value = value
	return best


static func _finish(state: GameState, winner: String) -> void:
	state.winner = winner
	state.phase = GameState.Phase.GAME_OVER
