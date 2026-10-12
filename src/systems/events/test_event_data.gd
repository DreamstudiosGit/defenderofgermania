extends GutTest
## Event cards in data/events.json against the GDD table "Ereignisse".

var _events: EventData


func before_each() -> void:
	_events = EventData.load_file()


func test_events_file_loads_and_passes_validation() -> void:
	assert_not_null(_events)
	assert_eq_deep(_events.validate(), PackedStringArray())


func test_gdd_lists_18_events() -> void:
	assert_eq(_events.events.size(), 18)


func test_trigger_counts() -> void:
	var counts := {}
	for event: EventData.EventDef in _events.events.values():
		counts[event.trigger] = counts.get(event.trigger, 0) + 1
	assert_eq_deep(counts, {"deck": 11, "weather": 1, "province_chance": 1, "fixed": 2, "once": 3})


func test_seasons_follow_the_gdd() -> void:
	var autumn_winter: Array[int] = [GameState.Season.AUTUMN, GameState.Season.WINTER]
	assert_eq_deep(_events.events["rat_plague"].seasons, autumn_winter)
	assert_eq_deep(_events.events["papal_legate"].seasons, [GameState.Season.WINTER] as Array[int])
	assert_true(_events.events["jugglers"].seasons.is_empty(), "jugglers come at any time")


func test_jugglers_cost_20_taler_for_3_satisfaction_at_home() -> void:
	var accept := _events.events["jugglers"].choices[0]
	assert_eq(accept.id, "accept")
	assert_eq(accept.cost, 20.0)
	assert_eq(accept.effects[0].type, "satisfaction")
	assert_eq(accept.effects[0].amount, 3.0)
	assert_eq(accept.effects[0].scope, "home")


func test_plague_strikes_four_percent_of_provinces_a_year_halved_by_monasteries() -> void:
	var plague := _events.events["plague"]
	assert_eq(plague.chance_per_year, 0.04)
	for effect: EventData.EffectDef in plague.effects:
		assert_eq(effect.scope, "province_and_neighbors")
		assert_eq(effect.halved_by, "monastery")


func test_lionheart_dies_in_the_spring_of_year_two() -> void:
	var event := _events.events["death_of_lionheart"]
	assert_eq_deep(event.seasons, [GameState.Season.SPRING] as Array[int])
	assert_eq_deep([event.from_year, event.to_year], [2, 2])
	assert_eq(event.effects[0].amount, 0.75)
	assert_eq(event.effects[0].target, "england")


func test_marriage_offer_waits_until_marriages_exist() -> void:
	assert_false(_events.events["marriage_offer"].is_enabled)
	assert_true(_events.events["jugglers"].is_enabled)


func test_validate_reports_unknown_trigger_effect_and_adventure() -> void:
	var event := _events.events["hostage"]
	event.trigger = "comet"
	event.choices[0].effects[0].target = "dragon_hunt"
	event.choices[2].effects[0].type = "smite"
	assert_eq(_events.validate().size(), 3, str(_events.validate()))


func test_validate_reports_repeated_choice_and_unit_effect_without_unit() -> void:
	var event := _events.events["robber_knights"]
	event.choices[1].id = "hunt"
	event.choices[0].effects[0].unit = ""
	assert_eq(_events.validate().size(), 2, str(_events.validate()))
