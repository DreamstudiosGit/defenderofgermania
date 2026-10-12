class_name EventEffects
extends RefCounted
## What an event card does (GDD "Ereignisse"): one function per effect type of
## data/events.json. Battles are fought by the core (EventBattles); adventures come with
## milestone M6 and marriages are out of scope, so choices that need them are refused.

const HALVED := 0.5
const ERROR_ADVENTURE_LATER := "EVENT_ADVENTURE_LATER"
const ERROR_UNAVAILABLE := "EVENT_UNAVAILABLE"
const ERROR_TARGET_GONE := "EVENT_TARGET_GONE"
const ERROR_NO_UNITS := "EVENT_NO_UNITS"
const HIGHEST_CHURCH := "highest_church_favour"
const LOWEST_CHURCH := "lowest_church_favour"
const CHURCH_GROUP := "church_electors"


## Why the house cannot take this choice now; "" if it can (battles are checked by the core).
static func choice_error(
	state: GameState, card: EventState.EventCard, choice: EventData.ChoiceDef
) -> String:
	if state.houses[card.house].gold < choice.cost:
		return Command.ERROR_NOT_ENOUGH_GOLD
	for effect: EventData.EffectDef in choice.effects:
		match effect.type:
			"adventure":
				return ERROR_ADVENTURE_LATER
			"marriage":
				return ERROR_UNAVAILABLE
			"homage":
				if state.provinces[effect.target].owner != CrownRules.NEUTRAL:
					return ERROR_TARGET_GONE
			"send_units":
				if _companies(state, card.house, effect.unit) < int(effect.amount):
					return ERROR_NO_UNITS
	return ""


static func apply(
	state: GameState,
	events: EventData,
	map: MapData,
	cfg: EconomyConfig,
	card: EventState.EventCard,
	effects: Array[EventData.EffectDef]
) -> void:
	for effect: EventData.EffectDef in effects:
		match effect.type:
			"grain":
				_grain(state, card.house, effect)
			"grain_demand":
				var demand := state.events.grain_demand
				demand[card.house] = demand.get(card.house, 0.0) + effect.amount
			"harvest":
				for id: String in provinces(state, map, card, effect):
					state.events.harvest[id] = state.events.harvest.get(id, 0.0) + effect.amount
			"population":
				for id: String in provinces(state, map, card, effect):
					state.provinces[id].population *= 1.0 + _local(state, id, effect)
			"satisfaction":
				for id: String in provinces(state, map, card, effect):
					var province := state.provinces[id]
					var value := province.satisfaction + _local(state, id, effect)
					province.satisfaction = clampf(value, 0.0, cfg.satisfaction_max)
			"prestige":
				state.houses[card.house].pending_prestige += effect.amount
			"gold":
				state.houses[card.house].gold += effect.amount
			"favour":
				for house: String in houses(state, events, card, effect):
					for lord: String in events.lords(effect.target):
						CrownRules.change_favour(state, map, lord, house, effect.amount)
			"ban_chance":
				for house: String in houses(state, events, card, effect):
					CrownRules.risk_ban(state, house, effect.amount)
			"no_passage":
				for id: String in provinces(state, map, card, effect):
					state.events.blocked_until[id] = state.turn + effect.rounds
			"homage":
				CrownRules.pay_homage(state, effect.target, card.house)
			"secure_vote":
				state.crown.promised_votes[effect.target] = card.house
			"send_units":
				_send(state, card.house, effect)
			"patron_strength":
				state.crown.patron_strength[effect.target] = effect.amount


## Provinces an effect reaches: the card's province (and its neighbours), the home province
## or every province of the house.
static func provinces(
	state: GameState, map: MapData, card: EventState.EventCard, effect: EventData.EffectDef
) -> Array[String]:
	var result: Array[String] = []
	match effect.scope:
		"province", "neighbor":
			result.append(card.province)
		"province_and_neighbors":
			result.append(card.province)
			result.append_array(map.provinces[card.province].neighbors)
		"home":
			var home := state.houses[card.house].home_province
			if state.provinces[home].owner == card.house:
				result.append(home)
		_:
			for province: ProvinceState in state.provinces_of(card.house):
				result.append(province.id)
	return result


## Houses an effect reaches: the card's house, or the one house with the highest or lowest
## favour summed over the church electors (nobody on a tie).
static func houses(
	state: GameState, events: EventData, card: EventState.EventCard, effect: EventData.EffectDef
) -> Array[String]:
	var result: Array[String] = []
	if effect.scope != HIGHEST_CHURCH and effect.scope != LOWEST_CHURCH:
		if not card.house.is_empty():
			result.append(card.house)
		return result
	var sign := 1.0 if effect.scope == HIGHEST_CHURCH else -1.0
	var best := ""
	var best_value := -INF
	var tied := false
	for house: HouseState in state.houses.values():
		if house.is_eliminated:
			continue
		var value := sign * church_favour(state, events, house.id)
		if value > best_value:
			best = house.id
			best_value = value
			tied = false
		elif value == best_value:
			tied = true
	if not best.is_empty() and not tied:
		result.append(best)
	return result


static func church_favour(state: GameState, events: EventData, house: String) -> float:
	var total := 0.0
	for lord: String in events.lords(CHURCH_GROUP):
		total += state.crown.favour_of(lord, house)
	return total


## Rat plague: the house's grain shrinks, half as much with a granary anywhere.
static func _grain(state: GameState, house: String, effect: EventData.EffectDef) -> void:
	var share := effect.amount
	if not effect.halved_by.is_empty():
		for province: ProvinceState in state.provinces_of(house):
			if effect.halved_by in province.buildings:
				share *= HALVED
				break
	state.houses[house].grain *= 1.0 + share


## The effect's amount in one province, halved where the named building stands.
static func _local(state: GameState, province_id: String, effect: EventData.EffectDef) -> float:
	var halved := effect.halved_by in state.provinces[province_id].buildings
	return effect.amount * (HALVED if halved else 1.0)


## Companies of the unit leave the house's armies until they come back (crusade).
static func _send(state: GameState, house: String, effect: EventData.EffectDef) -> void:
	var left := int(effect.amount)
	for army: ArmyState in state.armies_of(house):
		for i: int in range(army.company_count() - 1, -1, -1):
			if left > 0 and army.units[i] == effect.unit:
				army.remove_company(i)
				left -= 1
		if army.company_count() == 0:
			state.remove_army(army)
	var away := EventState.AwayCompanies.new()
	away.house = house
	away.unit = effect.unit
	away.companies = int(effect.amount) - left
	away.back_turn = state.turn + effect.rounds
	state.events.away.append(away)


static func _companies(state: GameState, house: String, unit: String) -> int:
	var count := 0
	for army: ArmyState in state.armies_of(house):
		count += army.units.count(unit)
	return count
