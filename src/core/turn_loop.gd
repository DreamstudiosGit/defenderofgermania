class_name TurnLoop
extends RefCounted
## Round flow: each house plays event, administration and campaign in turn (lowest prestige
## first, ties by seed), then settlement runs for all houses and the next round starts.


## Orders the houses for the round; the first one starts with its administration, since the
## opening round has no event cards (EventData.first_turn) and later rounds draw them in
## _settle.
static func start_round(state: GameState) -> void:
	state.turn_order = _order(state)
	state.active_index = 0
	state.phase = GameState.Phase.ADMINISTRATION


## Ends the active house's event, administration or campaign phase; EndPhaseCommand validates.
## Ending the event phase takes the default choice of every waiting card.
static func end_phase(state: GameState, rules: GameRules) -> void:
	if state.phase == GameState.Phase.EVENT:
		ChooseEventCommand.resolve_by_default(state, rules)
		state.phase = GameState.Phase.ADMINISTRATION
		return
	if state.phase == GameState.Phase.ADMINISTRATION:
		state.phase = GameState.Phase.CAMPAIGN
		Movement.start_campaign(state, rules.map.campaign, state.active_house())
		return
	Victory.check(state, rules)
	if state.is_over():
		return
	state.active_index += 1
	while (
		state.active_index < state.turn_order.size()
		and state.houses[state.active_house()].is_eliminated
	):
		state.active_index += 1
	if state.active_index < state.turn_order.size():
		_begin_turn(state, rules)
	else:
		_settle(state, rules)


## The event phase: cards without a choice act at once; with cards waiting for a choice the
## house stays in it until it answers them (ChooseEventCommand).
static func _begin_turn(state: GameState, rules: GameRules) -> void:
	state.phase = GameState.Phase.EVENT
	EventDeck.begin_turn(state, rules.events, rules.map, rules.economy)
	if state.events.pending == 0:
		state.phase = GameState.Phase.ADMINISTRATION


static func _settle(state: GameState, rules: GameRules) -> void:
	state.phase = GameState.Phase.SETTLEMENT
	Garrisons.starve(state, rules)
	CrownSettlement.settle(state, rules.map)
	EconomySettlement.settle(state, rules.map, rules.economy)
	EventRound.end_round(state)
	Movement.recover(state, rules.map.campaign)
	Garrisons.recover(state, rules)
	Conquest.count_down_exile(state)
	Victory.check(state, rules)
	if not state.is_over():
		start_round(state)
		EventRound.start_round(state, rules.events, rules.map, rules.economy)
		_begin_turn(state, rules)


## Houses still in the game, lowest prestige first; the seed breaks ties.
static func _order(state: GameState) -> Array[String]:
	var ids: Array[String] = []
	for house: HouseState in state.houses.values():
		if not house.is_eliminated:
			ids.append(house.id)
	ids.sort()
	var tiebreak: Dictionary[String, float] = {}
	for id: String in ids:
		tiebreak[id] = state.rng.randf()
	ids.sort_custom(
		func(a: String, b: String) -> bool:
			var prestige_a := state.houses[a].prestige
			var prestige_b := state.houses[b].prestige
			if prestige_a != prestige_b:
				return prestige_a < prestige_b
			return tiebreak[a] < tiebreak[b]
	)
	return ids
