class_name EventDeck
extends RefCounted
## The event phase of a house's turn (GDD "Ereignisse"): once-events whose favour condition the
## house meets fire, then the house draws one card from the weighted deck of the season. Cards
## without a choice act at once; the others wait for the house's choice (ChooseEventCommand).

const DECK := "deck"
const ONCE := "once"
const NEIGHBOR := "neighbor"


## Draws the active house's cards for this turn and applies those without a choice.
static func begin_turn(
	state: GameState, events: EventData, map: MapData, cfg: EconomyConfig
) -> void:
	var house := state.active_house()
	state.events.drawn.clear()
	state.events.pending = 0
	if state.turn < events.first_turn:
		return
	var cards: Array[EventState.EventCard] = []
	for event: EventData.EventDef in events.events.values():
		if event.trigger == ONCE and not event.favour_province.is_empty():
			var card := _card(state, map, event, house)
			if card != null:
				cards.append(card)
	var drawn := _draw(state, events, map, house)
	if drawn != null:
		cards.append(drawn)
	var waiting: Array[EventState.EventCard] = []
	for card: EventState.EventCard in cards:
		var event := events.events[card.event]
		if event.trigger == ONCE:
			state.events.fired.append(event.id)
		if event.choices.is_empty():
			state.events.drawn.append(card)
			EventEffects.apply(state, events, map, cfg, card, event.effects)
		else:
			waiting.append(card)
	state.events.drawn.append_array(waiting)
	state.events.pending = waiting.size()


## True if the house may get the event now: enabled, in its season and years, not yet fired
## and with a place for it.
static func is_eligible(
	state: GameState, map: MapData, event: EventData.EventDef, house: String
) -> bool:
	if not event.is_enabled or event.id in state.events.fired:
		return false
	if not event.seasons.is_empty() and state.season() not in event.seasons:
		return false
	var year := year_of(state.turn)
	if year < event.from_year or (event.to_year > 0 and year > event.to_year):
		return false
	var favour := event.favour_province
	if not favour.is_empty() and state.crown.favour_of(favour, house) < event.favour_min:
		return false
	return not places(state, map, event, house).is_empty()


## Game year of a round; the first year is 1.
static func year_of(turn: int) -> int:
	@warning_ignore("integer_division")
	return turn / GameState.ROUNDS_PER_YEAR + 1


## Provinces of the house the event can happen in; [""] when it concerns the whole house.
## Events "next door" need an own province, not the home, that borders land of no house.
static func places(
	state: GameState, map: MapData, event: EventData.EventDef, house: String
) -> Array[String]:
	var result: Array[String] = []
	if not event.needs_province.is_empty():
		if state.provinces[event.needs_province].owner == house:
			result.append(event.needs_province)
		return result
	var next_door := _uses_scope(event, NEIGHBOR)
	if event.needs_feature.is_empty() and not next_door:
		result.append("")
		return result
	for province: ProvinceState in state.provinces_of(house):
		var def := map.provinces[province.id]
		if not event.needs_feature.is_empty() and not def.has_feature(event.needs_feature):
			continue
		if next_door and not _borders_lords(state, def, house):
			continue
		result.append(province.id)
	return result


static func _draw(
	state: GameState, events: EventData, map: MapData, house: String
) -> EventState.EventCard:
	var deck: Array[EventData.EventDef] = []
	var total := 0.0
	for event: EventData.EventDef in events.events.values():
		var in_deck := event.trigger == DECK
		in_deck = in_deck or (event.trigger == ONCE and event.favour_province.is_empty())
		if in_deck and is_eligible(state, map, event, house):
			deck.append(event)
			total += event.weight
	if deck.is_empty():
		return null
	var roll := state.rng.randf() * total
	for event: EventData.EventDef in deck:
		roll -= event.weight
		if roll < 0.0:
			return _card(state, map, event, house)
	return _card(state, map, deck[deck.size() - 1], house)


static func _card(
	state: GameState, map: MapData, event: EventData.EventDef, house: String
) -> EventState.EventCard:
	if not is_eligible(state, map, event, house):
		return null
	var candidates := places(state, map, event, house)
	var index := 0 if candidates.size() == 1 else state.rng.randi_range(0, candidates.size() - 1)
	return EventState.EventCard.create(event.id, house, candidates[index])


static func _uses_scope(event: EventData.EventDef, scope: String) -> bool:
	for effect: EventData.EffectDef in event.effects:
		if effect.scope == scope:
			return true
	for choice: EventData.ChoiceDef in event.choices:
		for effect: EventData.EffectDef in choice.effects:
			if effect.scope == scope:
				return true
	return false


static func _borders_lords(state: GameState, def: MapData.ProvinceDef, house: String) -> bool:
	if state.houses[house].home_province == def.id:
		return false
	for id: String in def.neighbors:
		if not state.houses.has(state.provinces[id].owner):
			return true
	return false
