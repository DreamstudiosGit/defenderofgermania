class_name HostTournamentCommand
extends Command
## Hosts a tournament at the home castle's tourney ground in spring or summer, once a round:
## taler for prestige and the favour of every elector.

const SEASONS: Array[GameState.Season] = [GameState.Season.SPRING, GameState.Season.SUMMER]
const ERROR_SEASON := "ECONOMY_TOURNAMENT_SEASON"
const ERROR_NO_GROUND := "ECONOMY_TOURNAMENT_NO_GROUND"
const ERROR_HOSTED := "ECONOMY_TOURNAMENT_HOSTED"

var _cfg: EconomyConfig
var _map: MapData


func _init(cfg: EconomyConfig, map: MapData, house_id: String) -> void:
	_cfg = cfg
	_map = map
	house = house_id


func validate(state: GameState) -> String:
	var error := super(state)
	if not error.is_empty():
		return error
	if state.season() not in SEASONS:
		return ERROR_SEASON
	var home: ProvinceState = state.provinces.get(state.houses[house].home_province)
	if home == null or home.owner != house or _cfg.tournament_building not in home.buildings:
		return ERROR_NO_GROUND
	if state.crown.tournament_turn.get(house, -1) == state.turn:
		return ERROR_HOSTED
	return gold_error(state, _cfg.tournament_cost)


func apply(state: GameState) -> void:
	var host := state.houses[house]
	host.gold -= _cfg.tournament_cost
	host.pending_prestige += _cfg.tournament_hosted_prestige
	var favour: float = _map.crown.favour_changes["tournament_hosted"]
	CrownRules.change_elector_favour(state, _map, house, favour)
	state.crown.tournament_turn[house] = state.turn
