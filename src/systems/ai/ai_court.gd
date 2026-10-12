class_name AiCourt
extends RefCounted
## Goal options at court on the road to the crown: gifts to electors close to their vote (and
## to neutral lords close to homage), homage, patron cards, tournaments, forged regalia and
## penance — each valued in taler worth per taler spent. The coronation itself is taken the
## moment the rules allow it.


## Calls the coronation if every pillar stands; true if the house was crowned.
static func crown(turn: AiTurn) -> bool:
	var command := CoronationCommand.new(turn.rules.map, turn.house)
	return command.validate(turn.state).is_empty() and turn.act(command, "coronation", INF)


static func options(turn: AiTurn) -> Array[AiOption]:
	var result: Array[AiOption] = []
	_gifts(turn, result)
	_homage(turn, result)
	_patron(turn, result)
	_tournament(turn, result)
	_forge(turn, result)
	_penance(turn, result)
	return result


static func _gifts(turn: AiTurn, result: Array[AiOption]) -> void:
	var state := turn.state
	var map := turn.rules.map
	var crown := map.crown
	var cost := CrownRules.gift_cost(map, turn.house)
	var multiplier: float = crown.house_favour_multiplier.get(turn.house, 1.0)
	var votes := CrownRules.votes(state, map)
	for id: String in map.provinces:
		if not state.crown.has_favour_list(id, turn.house):
			continue
		var is_elector := id in votes
		var goal := crown.vote_threshold if is_elector else crown.homage_threshold
		if not is_elector and state.provinces[id].owner != CrownRules.NEUTRAL:
			continue
		var favour := state.crown.favour_of(id, turn.house)
		var gap := goal - favour
		if gap <= 0.0 or gap > turn.cfg.goals["favour_reach"]:
			continue
		var gain := CrownRules.gift_favour(state, map, id, turn.house) * multiplier
		if gain <= 0.0:
			continue
		var prize := turn.pillar_worth() / 4.0 if is_elector else turn.value("province")
		var worth := prize * minf(gain / gap, 1.0) * turn.weight("favour")
		var command := GiftCommand.new(map, turn.house, id)
		result.append(AiOption.create("gift to " + id, worth / cost, command, cost))


static func _homage(turn: AiTurn, result: Array[AiOption]) -> void:
	var map := turn.rules.map
	for id: String in map.provinces:
		var command := HomageCommand.new(map, turn.house, id)
		if turn.allowed(command):
			var worth := turn.value("province") * 2.0 * turn.weight("favour")
			var price := map.crown.homage_cost
			result.append(AiOption.create("homage of " + id, worth / price, command, price))


## One card a round: an embassy to the elector closest below his vote, else silver when the
## treasury is low.
static func _patron(turn: AiTurn, result: Array[AiOption]) -> void:
	var state := turn.state
	var map := turn.rules.map
	var crown := map.crown
	var best := ""
	var best_gap := INF
	for id: String in map.electors():
		var gap := crown.vote_threshold - state.crown.favour_of(id, turn.house)
		if gap > 0.0 and gap < best_gap:
			best = id
			best_gap = gap
	if not best.is_empty() and best_gap <= crown.patron_embassy_favour * 1.5:
		var embassy := PlayPatronCommand.new(map, turn.house, PlayPatronCommand.EMBASSY, best)
		var worth := turn.value("vote") * turn.weight("favour")
		result.append(AiOption.create("embassy to " + best, worth / 100.0, embassy))
	if turn.spare_gold() < 0.0:
		var silver := PlayPatronCommand.new(map, turn.house, PlayPatronCommand.SILVER)
		result.append(AiOption.create("patron silver", 2.0, silver))


static func _tournament(turn: AiTurn, result: Array[AiOption]) -> void:
	var command := HostTournamentCommand.new(turn.rules, turn.house)
	if not turn.allowed(command):
		return
	var cfg := turn.rules.economy
	var crown := turn.rules.map.crown
	var favour: float = crown.favour_changes["tournament_hosted"] * turn.rules.map.electors().size()
	var worth := cfg.tournament_hosted_prestige * turn.value("prestige") * 4.0
	worth += favour * turn.value("favour")
	worth += turn.rules.joust.prize_gold * 0.5
	var utility := worth * turn.weight("court") / cfg.tournament_cost
	result.append(AiOption.create("host a tournament", utility, command, cfg.tournament_cost))


static func _forge(turn: AiTurn, result: Array[AiOption]) -> void:
	var map := turn.rules.map
	var command := ForgeRegaliaCommand.new(map, turn.house)
	if not turn.allowed(command) or not CrownRules.regalia(turn.state, turn.house).is_empty():
		return
	var worth := turn.pillar_worth()
	var price := map.crown.forged_regalia_cost
	var option := AiOption.create("forge regalia", worth / price, command, price)
	result.append(option)


## Penance once the ban hurts more than it costs: satisfaction everywhere, prestige every
## round and the church electors' votes.
static func _penance(turn: AiTurn, result: Array[AiOption]) -> void:
	var map := turn.rules.map
	var command := PenanceCommand.new(map, turn.house)
	if not turn.allowed(command):
		return
	var provinces := turn.state.provinces_of(turn.house).size()
	var worth := provinces * turn.rules.economy.ban_penalty * turn.value("satisfaction") * 2.0
	worth += turn.rules.economy.ban_prestige * turn.value("prestige") * 8.0
	worth += turn.value("vote")
	var cost := CrownRules.penance_gold(turn.state, map, turn.house)
	result.append(AiOption.create("penance", worth / cost, command, cost))
