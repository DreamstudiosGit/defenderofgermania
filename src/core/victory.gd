class_name Victory
extends RefCounted
## Victory while electors are deferred: subjugation (every other house eliminated) or the
## highest legitimacy once the last round is settled. Coronation comes with the electors.


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


## L = 30·regalia + 20·Aachen + 10·Mainz + 2·provinces + prestige/5 (weights from data);
## the electors' votes and forged regalia count once electors exist.
static func legitimacy(state: GameState, rules: GameRules, house_id: String) -> float:
	var tags: Array[String] = []
	var owned := state.provinces_of(house_id)
	for province: ProvinceState in owned:
		tags.append_array(rules.map.provinces[province.id].tags)
	var prestige := state.houses[house_id].prestige
	return rules.map.campaign.legitimacy(tags, owned.size(), prestige)


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
