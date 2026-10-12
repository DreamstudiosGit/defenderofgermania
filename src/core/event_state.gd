class_name EventState
extends RefCounted
## Event cards in a running game: the active house's cards of this turn (some waiting for a
## choice), the round's news for everyone, and what events leave behind until it runs out.
## Part of the save (GameState.to_dict).

## Cards the active house drew this turn, in order; `pending` counts the last ones that still
## wait for a choice.
var drawn: Array[EventCard] = []
var pending: int = 0
## Events of the round that concern every house (legate, plague, weather, the Lionheart).
var news: Array[EventCard] = []
## Once-events that have fired.
var fired: Array[String] = []
## Extra share of grain the house's people and troops eat at the coming settlement.
var grain_demand: Dictionary[String, float] = {}
## Share by which the next harvest of a province changes (flood).
var harvest: Dictionary[String, float] = {}
## First round in which armies may enter the province again (flood).
var blocked_until: Dictionary[String, int] = {}
## Companies an event sent away and when they come home (crusade).
var away: Array[AwayCompanies] = []


class EventCard:
	var event: String
	var house: String
	## Province the card concerns; "" for the whole house.
	var province: String = ""
	## Region of a weather card; "" otherwise.
	var region: String = ""
	## Choice taken; "" while pending or for cards without a choice.
	var choice: String = ""
	## A battle the choice started was won.
	var won: bool = false

	static func create(event_id: String, house_id: String, province_id: String) -> EventCard:
		var card := EventCard.new()
		card.event = event_id
		card.house = house_id
		card.province = province_id
		return card

	static func from_dict(r: DataReader, data: Dictionary) -> EventCard:
		var card := create(r.text(data, "event"), r.text(data, "house"), r.text(data, "province"))
		card.region = r.text(data, "region")
		card.choice = r.text(data, "choice")
		card.won = r.flag(data, "won")
		return card

	func to_dict() -> Dictionary:
		return {
			"event": event,
			"house": house,
			"province": province,
			"region": region,
			"choice": choice,
			"won": won,
		}


class AwayCompanies:
	var house: String
	var unit: String
	var companies: int
	var back_turn: int

	static func from_dict(r: DataReader, data: Dictionary) -> AwayCompanies:
		var entry := AwayCompanies.new()
		entry.house = r.text(data, "house")
		entry.unit = r.text(data, "unit")
		entry.companies = r.integer(data, "companies")
		entry.back_turn = r.integer(data, "back_turn")
		return entry

	func to_dict() -> Dictionary:
		return {"house": house, "unit": unit, "companies": companies, "back_turn": back_turn}


## The first card that waits for a choice, or null.
func next_pending() -> EventCard:
	return drawn[drawn.size() - pending] if pending > 0 else null


func is_blocked(province_id: String, turn: int) -> bool:
	return turn < blocked_until.get(province_id, 0)


static func from_dict(r: DataReader, data: Dictionary) -> EventState:
	var events := EventState.new()
	for entry: Variant in r.list(data, "drawn"):
		events.drawn.append(EventCard.from_dict(r, _object(r, entry)))
	events.pending = r.integer(data, "pending")
	for entry: Variant in r.list(data, "news"):
		events.news.append(EventCard.from_dict(r, _object(r, entry)))
	events.fired = r.strings(data, "fired")
	var demand := r.object(data, "grain_demand")
	for id: String in demand:
		events.grain_demand[id] = r.number(demand, id)
	var harvest_data := r.object(data, "harvest")
	for id: String in harvest_data:
		events.harvest[id] = r.number(harvest_data, id)
	var blocked := r.object(data, "blocked_until")
	for id: String in blocked:
		events.blocked_until[id] = r.integer(blocked, id)
	for entry: Variant in r.list(data, "away"):
		events.away.append(AwayCompanies.from_dict(r, _object(r, entry)))
	return events


static func _object(r: DataReader, value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	r.errors.append("events: expected an object, got %s" % type_string(typeof(value)))
	return {}


func to_dict() -> Dictionary:
	return {
		"drawn": drawn.map(func(card: EventCard) -> Dictionary: return card.to_dict()),
		"pending": pending,
		"news": news.map(func(card: EventCard) -> Dictionary: return card.to_dict()),
		"fired": fired,
		"grain_demand": grain_demand,
		"harvest": harvest,
		"blocked_until": blocked_until,
		"away": away.map(func(entry: AwayCompanies) -> Dictionary: return entry.to_dict()),
	}
