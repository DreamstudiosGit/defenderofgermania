class_name HostTournamentCommand
extends Command
## Hosts a tournament at the home castle's tourney ground in spring or summer, once a round:
## taler for prestige and the favour of every elector, and the house's leader rides the joust
## (an adventure: a free leader, one a round).

const SEASONS: Array[GameState.Season] = [GameState.Season.SPRING, GameState.Season.SUMMER]
const ERROR_SEASON := "ECONOMY_TOURNAMENT_SEASON"
const ERROR_NO_GROUND := "ECONOMY_TOURNAMENT_NO_GROUND"
const ERROR_HOSTED := "ECONOMY_TOURNAMENT_HOSTED"

var _rules: GameRules


func _init(rules: GameRules, house_id: String) -> void:
	_rules = rules
	house = house_id


func validate(state: GameState) -> String:
	var error := super(state)
	if not error.is_empty():
		return error
	if state.season() not in SEASONS:
		return ERROR_SEASON
	var home: ProvinceState = state.provinces.get(state.houses[house].home_province)
	var ground := _rules.economy.tournament_building
	if home == null or home.owner != house or ground not in home.buildings:
		return ERROR_NO_GROUND
	if state.crown.tournament_turn.get(house, -1) == state.turn:
		return ERROR_HOSTED
	error = gold_error(state, _rules.economy.tournament_cost)
	return error if not error.is_empty() else Adventures.error(state, house)


## The joust the tournament starts, for playing it live first; null if the command is refused.
func adventure_setup(state: GameState) -> RefCounted:
	if not validate(state).is_empty():
		return null
	return Adventures.joust_setup(state, _rules, house, state.houses[house].home_province)


func apply(state: GameState) -> void:
	var host := state.houses[house]
	var cfg := _rules.economy
	host.gold -= cfg.tournament_cost
	host.pending_prestige += cfg.tournament_hosted_prestige
	var favour: float = _rules.map.crown.favour_changes["tournament_hosted"]
	CrownRules.change_elector_favour(state, _rules.map, house, favour)
	state.crown.tournament_turn[house] = state.turn
	var setup := Adventures.joust_setup(state, _rules, house, host.home_province)
	Adventures.apply_joust(state, _rules, setup, Adventures.play_joust(state, _rules, setup))
