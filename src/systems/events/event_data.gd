class_name EventData
extends RefCounted
## Event cards from data/events.json (GDD "Ereignisse"): when they fire, what the drawing
## house needs and what they do. Drawing and applying them comes with milestone M5.

const PATH := "res://data/events.json"
## deck: drawn from the season's weighted deck; weather: announces an extreme weather roll;
## province_chance: rolled per province and year; fixed: fires on its season and years;
## once: fires once when its condition holds.
const TRIGGERS: Array[String] = ["deck", "weather", "province_chance", "fixed", "once"]
const EFFECTS: Array[String] = [
	"grain", "grain_demand", "harvest", "population", "satisfaction", "prestige", "gold",
	"favour", "ban_chance", "no_passage", "battle", "adventure", "marriage", "homage",
	"secure_vote", "send_units", "patron_strength",
]
const SCOPES: Array[String] = [
	"house", "home", "province", "province_and_neighbors", "neighbor",
	"highest_church_favour", "lowest_church_favour",
]
const ADVENTURES: Array[String] = ["joust", "castle_raid", "merchant_train"]
## Effects that put companies of `unit` on the field or send them away.
const UNIT_EFFECTS: Array[String] = ["battle", "send_units"]

var events: Dictionary[String, EventDef] = {}


class EventDef:
	var id: String
	var trigger: String
	## GameState.Season values; empty means every season.
	var seasons: Array[int] = []
	var weight: float
	var chance_per_year: float
	## Weather values the event announces (trigger "weather").
	var weather: PackedFloat64Array
	var is_enabled: bool
	## Feature one of the house's provinces needs (MapData.FEATURES); "" for none.
	var needs_feature: String
	## Province the house must own; "" for none.
	var needs_province: String
	## Lord whose favour must reach favour_min; "" for none.
	var favour_province: String
	var favour_min: float
	## Game years (1 = the first year) the event can fire in; to_year 0 means no end.
	var from_year: int
	var to_year: int
	var effects: Array[EffectDef] = []
	var choices: Array[ChoiceDef] = []


class ChoiceDef:
	var id: String
	var cost: float
	var effects: Array[EffectDef] = []
	## Effects once the battle this choice starts is won.
	var victory: Array[EffectDef] = []


class EffectDef:
	var type: String
	var amount: float
	var scope: String
	## Province id, adventure, patron power or group of lords the effect aims at.
	var target: String
	var unit: String
	var rounds: int
	## Building that halves the effect where it stands; "" for none.
	var halved_by: String


static func load_file(path: String = PATH) -> EventData:
	var data: Variant = DataReader.load_json(path)
	if not data is Dictionary:
		push_error("%s: expected a JSON object" % path)
		return null
	var reader := DataReader.new()
	var event_data := EventData.new()
	event_data._read(reader, data)
	for error: String in reader.errors:
		push_error("%s: %s" % [path, error])
	return null if reader.errors else event_data


func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	for event: EventDef in events.values():
		var where := "event %s" % event.id
		if event.trigger not in TRIGGERS:
			errors.append("%s: unknown trigger '%s'" % [where, event.trigger])
		if event.trigger == "deck" and event.weight <= 0.0:
			errors.append("%s: a deck card needs a positive weight" % where)
		var chance := event.chance_per_year
		if event.trigger == "province_chance" and not (chance > 0.0 and chance <= 1.0):
			errors.append("%s: chance_per_year must lie in (0, 1]" % where)
		if event.trigger == "weather" and event.weather.is_empty():
			errors.append("%s: a weather event needs weather values" % where)
		if event.to_year > 0 and event.to_year < event.from_year:
			errors.append("%s: to_year before from_year" % where)
		errors.append_array(_validate_effects(where, event.effects))
		var choice_ids: Array[String] = []
		for choice: ChoiceDef in event.choices:
			if choice.id in choice_ids:
				errors.append("%s: choice '%s' listed twice" % [where, choice.id])
			choice_ids.append(choice.id)
			errors.append_array(_validate_effects("%s.%s" % [where, choice.id], choice.effects))
			errors.append_array(_validate_effects("%s.%s" % [where, choice.id], choice.victory))
	return errors


## Every effect of the event, its choices and their victories.
func all_effects(event: EventDef) -> Array[EffectDef]:
	var result: Array[EffectDef] = event.effects.duplicate()
	for choice: ChoiceDef in event.choices:
		result.append_array(choice.effects)
		result.append_array(choice.victory)
	return result


func _validate_effects(where: String, effects: Array[EffectDef]) -> PackedStringArray:
	var errors: PackedStringArray = []
	for effect: EffectDef in effects:
		if effect.type not in EFFECTS:
			errors.append("%s: unknown effect '%s'" % [where, effect.type])
		if effect.scope not in SCOPES:
			errors.append("%s: unknown scope '%s'" % [where, effect.scope])
		if effect.type == "adventure" and effect.target not in ADVENTURES:
			errors.append("%s: unknown adventure '%s'" % [where, effect.target])
		if effect.type in UNIT_EFFECTS and (effect.unit.is_empty() or effect.amount <= 0.0):
			errors.append("%s: %s needs a unit and a positive amount" % [where, effect.type])
	return errors


func _read(r: DataReader, data: Dictionary) -> void:
	for item: Variant in r.list(data, "events"):
		if not item is Dictionary:
			r.errors.append("events: expected objects")
			continue
		var entry: Dictionary = item
		var event := _read_event(r, entry)
		if events.has(event.id):
			r.errors.append("events: duplicate id '%s'" % event.id)
		events[event.id] = event
	r.context = ""


func _read_event(r: DataReader, entry: Dictionary) -> EventDef:
	var event := EventDef.new()
	event.id = r.text(entry, "id")
	r.context = "events.%s" % event.id
	if event.id.is_empty():
		r.errors.append("%s: missing id" % r.context)
	event.trigger = r.text(entry, "trigger")
	var season_names: Array = GameState.Season.keys()
	for season: String in r.strings(entry, "seasons", false):
		var index := season_names.find(season.to_upper())
		if index < 0:
			r.errors.append("%s.seasons: unknown season '%s'" % [r.context, season])
		else:
			event.seasons.append(index)
	event.weight = r.number(entry, "weight", 0.0)
	event.chance_per_year = r.number(entry, "chance_per_year", 0.0)
	if entry.has("weather"):
		event.weather = r.numbers(entry, "weather")
	event.is_enabled = not entry.has("enabled") or r.flag(entry, "enabled")
	event.needs_feature = r.text(entry, "needs_feature")
	event.needs_province = r.text(entry, "needs_province")
	event.favour_province = r.text(entry, "favour_province")
	event.favour_min = r.number(entry, "favour_min", 0.0)
	event.from_year = r.integer(entry, "from_year", 0)
	event.to_year = r.integer(entry, "to_year", 0)
	event.effects = _read_effects(r, entry, "effects")
	for item: Variant in r.list(entry, "choices", false):
		if not item is Dictionary:
			r.errors.append("%s.choices: expected objects" % r.context)
			continue
		var choice_entry: Dictionary = item
		var choice := ChoiceDef.new()
		choice.id = r.text(choice_entry, "id")
		choice.cost = r.number(choice_entry, "cost", 0.0)
		choice.effects = _read_effects(r, choice_entry, "effects")
		choice.victory = _read_effects(r, choice_entry, "victory")
		event.choices.append(choice)
	return event


func _read_effects(r: DataReader, entry: Dictionary, key: String) -> Array[EffectDef]:
	var effects: Array[EffectDef] = []
	for item: Variant in r.list(entry, key, false):
		if not item is Dictionary:
			r.errors.append("%s.%s: expected objects" % [r.context, key])
			continue
		var effect_entry: Dictionary = item
		var effect := EffectDef.new()
		effect.type = r.text(effect_entry, "type")
		effect.amount = r.number(effect_entry, "amount", 0.0)
		effect.scope = r.text(effect_entry, "scope", "house")
		effect.target = r.text(effect_entry, "target")
		effect.unit = r.text(effect_entry, "unit")
		effect.rounds = r.integer(effect_entry, "rounds", 0)
		effect.halved_by = r.text(effect_entry, "halved_by")
		effects.append(effect)
	return effects
