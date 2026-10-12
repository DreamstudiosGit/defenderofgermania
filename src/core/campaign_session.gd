class_name CampaignSession
extends RefCounted
## A running campaign for the map scene: human houses issue commands, the others stay passive
## (they end their phases at once until the AI of milestone M7 plays them). A move into a
## battle can be fought live first; its result then decides that battle. Adventures work the
## same way: the minigame is played first, its result decides the command.

var state: GameState
var rules: GameRules
var humans: Array[String] = []
## Snapshot taken just before the last settlement, for the settlement report; null before.
var before_settlement: GameState = null

## Holds the live result apart from the session, so the rules' resolver does not keep the
## session alive through a reference cycle.
var _live := LiveBattle.new()


class LiveBattle:
	var result: BattleResult = null
	var adventure: RefCounted = null

	## The live result of the command's adventure, once; without one the computer plays.
	func resolve_adventure(_setup: RefCounted) -> RefCounted:
		var live := adventure
		adventure = null
		return live

	## The live result for the first battle of a move, once; other battles auto-resolve.
	func resolve(setup: BattleSetup) -> BattleResult:
		var live := result
		result = null
		if live == null:
			return null
		var fits := live.attacker_health.size() == setup.attacker.company_count()
		fits = fits and live.defender_health.size() == setup.defender.company_count()
		return live if fits else null


static func create(
	game_rules: GameRules, human_houses: Array[String], seed_value: int
) -> CampaignSession:
	var session := CampaignSession.new()
	session.rules = game_rules
	session.humans = human_houses.duplicate()
	session.state = GameSetup.create(game_rules.map, game_rules.economy, seed_value)
	session.rules.resolver = session._live.resolve
	session.rules.adventure_resolver = session._live.resolve_adventure
	session.advance_passive()
	return session


func active_house() -> String:
	return state.active_house()


func is_human_turn() -> bool:
	return not state.is_over() and active_house() in humans


## Runs a command of the active human house; returns its error key ("" on success). Ending the
## last campaign phase of a round settles it; passive houses then take their turns.
func execute(command: Command) -> String:
	if not is_human_turn() or command.house != active_house():
		return Command.ERROR_NOT_ACTIVE
	var settles := _settles_round(command)
	var snapshot := GameState.from_dict(state.to_dict()) if settles else null
	var error := command.execute(state)
	if error.is_empty():
		if settles:
			before_settlement = snapshot
		advance_passive()
	return error


## The first battle the move would fight, or null when it fights none.
func battle_ahead(army_id: int, target: String) -> BattleSetup:
	return MoveArmyCommand.new(rules, active_house(), army_id, target).first_battle(state)


## Executes a move whose first battle was fought live and ended with `result`.
func move_after_battle(army_id: int, target: String, result: BattleResult) -> String:
	_live.result = result
	var error := execute(MoveArmyCommand.new(rules, active_house(), army_id, target))
	_live.result = null
	return error


## Executes a command whose adventure was played live and ended with `result`.
func execute_after_adventure(command: Command, result: RefCounted) -> String:
	_live.adventure = result
	var error := execute(command)
	_live.adventure = null
	return error


## Passive houses end their phases until a human house is to move or the game is over.
func advance_passive() -> void:
	while not state.is_over() and active_house() not in humans:
		var house := active_house()
		var settles := state.phase == GameState.Phase.CAMPAIGN and _last_in_round()
		var snapshot := GameState.from_dict(state.to_dict()) if settles else null
		var error := EndPhaseCommand.new(rules, house).execute(state)
		if not error.is_empty():
			push_error("campaign: passive house %s cannot end its phase: %s" % [house, error])
			return
		if settles:
			before_settlement = snapshot


func _settles_round(command: Command) -> bool:
	return (
		command is EndPhaseCommand
		and state.phase == GameState.Phase.CAMPAIGN
		and _last_in_round()
	)


func _last_in_round() -> bool:
	for i: int in range(state.active_index + 1, state.turn_order.size()):
		if not state.houses[state.turn_order[i]].is_eliminated:
			return false
	return true
