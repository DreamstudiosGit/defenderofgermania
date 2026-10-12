class_name ChooseEventCommand
extends Command
## The active house answers the event card in front of it (EventState.next_pending); after the
## last card its administration phase begins.

const ERROR_NO_CARD := "EVENT_NO_CARD"
const ERROR_UNKNOWN_CHOICE := "EVENT_UNKNOWN_CHOICE"

var choice: String
var _rules: GameRules


func _init(rules: GameRules, house_id: String, choice_id: String) -> void:
	_rules = rules
	house = house_id
	choice = choice_id


func accepts_phase(phase: GameState.Phase) -> bool:
	return phase == GameState.Phase.EVENT


func validate(state: GameState) -> String:
	var error := super(state)
	if not error.is_empty():
		return error
	var card := state.events.next_pending()
	if card == null:
		return ERROR_NO_CARD
	return choice_error(state, _rules, card, choice)


func apply(state: GameState) -> void:
	resolve(state, _rules, choice)


## Why the house cannot take this choice on the card; "" if it can.
static func choice_error(
	state: GameState, rules: GameRules, card: EventState.EventCard, choice_id: String
) -> String:
	var def := rules.events.events[card.event].choice(choice_id)
	if def == null:
		return ERROR_UNKNOWN_CHOICE
	var error := EventEffects.choice_error(state, card, def)
	if not error.is_empty():
		return error
	if not EventEffects.adventure_of(def).is_empty():
		error = Adventures.error(state, card.house)
		if not error.is_empty():
			return error
	return EventBattles.error(state, rules, card, def)


## The minigame setup this choice starts on the next card, or null; lets the player play it
## live before the command runs (GameRules.adventure_resolver).
func adventure_setup(state: GameState) -> RefCounted:
	var card := state.events.next_pending()
	if card == null or not validate(state).is_empty():
		return null
	var def := _rules.events.events[card.event].choice(choice)
	return Adventures.event_setup(state, _rules, card, EventEffects.adventure_of(def))


## Takes a valid choice on the next pending card: cost, effects, the battle and its reward.
static func resolve(state: GameState, rules: GameRules, choice_id: String) -> void:
	var card := state.events.next_pending()
	var def := rules.events.events[card.event].choice(choice_id)
	state.houses[card.house].gold -= def.cost
	card.choice = choice_id
	EventEffects.apply(state, rules.events, rules.map, rules.economy, card, def.effects)
	var adventure := EventEffects.adventure_of(def)
	if EventBattles.battle_of(def) != null:
		card.won = EventBattles.fight(state, rules, card, def)
	elif not adventure.is_empty():
		card.won = Adventures.play_event(state, rules, card, adventure)
	if card.won:
		EventEffects.apply(state, rules.events, rules.map, rules.economy, card, def.victory)
	_next(state)


## A house that does not choose takes each card's default, else the first choice it can take;
## a card it can answer in no way passes.
static func resolve_by_default(state: GameState, rules: GameRules) -> void:
	while state.events.pending > 0:
		var card := state.events.next_pending()
		var event := rules.events.events[card.event]
		var options: Array[String] = [event.default_choice]
		for candidate: EventData.ChoiceDef in event.choices:
			options.append(candidate.id)
		var taken := ""
		for option: String in options:
			if choice_error(state, rules, card, option).is_empty():
				taken = option
				break
		if taken.is_empty():
			_next(state)
		else:
			resolve(state, rules, taken)


static func _next(state: GameState) -> void:
	state.events.pending -= 1
	if state.events.pending == 0:
		state.phase = GameState.Phase.ADMINISTRATION
