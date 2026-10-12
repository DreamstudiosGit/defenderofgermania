class_name EventRound
extends RefCounted
## Events of the whole round (GDD "Ereignisse"): fixed dates (the papal legate every winter, the
## Lionheart's death), the yearly plague roll per province, the news of an extreme harvest,
## and companies a crusade sent away coming home. end_round forgets what lasted one settlement.

const FIXED := "fixed"
const PROVINCE_CHANCE := "province_chance"
const WEATHER := "weather"


## Start of a round, before the first house's event phase; news are what everyone sees.
static func start_round(
	state: GameState, events: EventData, map: MapData, cfg: EconomyConfig
) -> void:
	state.events.news.clear()
	_bring_home(state)
	if state.turn < events.first_turn:
		return
	for event: EventData.EventDef in events.events.values():
		if not event.is_enabled or not _in_years(state, event):
			continue
		match event.trigger:
			FIXED:
				if _in_season(event, state.season()):
					_fire(state, events, map, cfg, event, "", "")
			PROVINCE_CHANCE:
				if _in_season(event, state.season()):
					_roll_provinces(state, events, map, cfg, event)
			WEATHER:
				var settled := posmod(state.turn - 1, GameState.ROUNDS_PER_YEAR)
				if _in_season(event, settled as GameState.Season):
					_announce_weather(state, map, event)


## After the economy settled the round (state.turn already counts the new one).
static func end_round(state: GameState) -> void:
	state.events.grain_demand.clear()
	if state.season() == GameState.Season.WINTER:
		state.events.harvest.clear()
	for id: String in state.events.blocked_until.keys():
		if not state.events.is_blocked(id, state.turn):
			state.events.blocked_until.erase(id)


static func _fire(
	state: GameState,
	events: EventData,
	map: MapData,
	cfg: EconomyConfig,
	event: EventData.EventDef,
	house: String,
	province: String
) -> void:
	var card := EventState.EventCard.create(event.id, house, province)
	state.events.news.append(card)
	EventEffects.apply(state, events, map, cfg, card, event.effects)


## Every province rolls the yearly chance once, in data order.
static func _roll_provinces(
	state: GameState, events: EventData, map: MapData, cfg: EconomyConfig, event: EventData.EventDef
) -> void:
	for id: String in map.provinces:
		if state.rng.randf() < event.chance_per_year:
			var owner := state.provinces[id].owner
			_fire(state, events, map, cfg, event, owner if state.houses.has(owner) else "", id)


## The weather of the last harvest made the news if it hit one of the event's values.
static func _announce_weather(state: GameState, map: MapData, event: EventData.EventDef) -> void:
	for region: String in map.regions:
		var weather: float = state.weather.get(region, 1.0)
		for value: float in event.weather:
			if is_equal_approx(weather, value):
				var card := EventState.EventCard.create(event.id, "", "")
				card.region = region
				state.events.news.append(card)


## Companies back from a crusade gather as a new army at the home castle.
static func _bring_home(state: GameState) -> void:
	var still_away: Array[EventState.AwayCompanies] = []
	for entry: EventState.AwayCompanies in state.events.away:
		if entry.back_turn > state.turn:
			still_away.append(entry)
			continue
		var house := state.houses[entry.house]
		if house.is_eliminated or state.home_castle_level(entry.house) == 0:
			continue
		var army := state.add_army(entry.house, house.home_province)
		for _i: int in entry.companies:
			army.add_company(entry.unit)
	state.events.away = still_away


static func _in_season(event: EventData.EventDef, season: GameState.Season) -> bool:
	return event.seasons.is_empty() or season in event.seasons


static func _in_years(state: GameState, event: EventData.EventDef) -> bool:
	var year := EventDeck.year_of(state.turn)
	return year >= event.from_year and (event.to_year == 0 or year <= event.to_year)
