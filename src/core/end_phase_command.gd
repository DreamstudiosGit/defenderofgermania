class_name EndPhaseCommand
extends Command
## Ends the active house's event, administration or campaign phase (waiting event cards take
## their default choice); after the last house's campaign the settlement runs and the next
## round begins (TurnLoop).

var _rules: GameRules


func _init(rules: GameRules, house_id: String) -> void:
	_rules = rules
	house = house_id


func accepts_phase(phase: GameState.Phase) -> bool:
	return phase in [
		GameState.Phase.EVENT, GameState.Phase.ADMINISTRATION, GameState.Phase.CAMPAIGN
	]


func apply(state: GameState) -> void:
	TurnLoop.end_phase(state, _rules)
