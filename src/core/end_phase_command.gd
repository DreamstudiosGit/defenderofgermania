class_name EndPhaseCommand
extends Command
## Ends the active house's administration or campaign phase; after the last house's
## campaign the settlement runs and the next round begins (TurnLoop).

var _rules: GameRules


func _init(rules: GameRules, house_id: String) -> void:
	_rules = rules
	house = house_id


func accepts_phase(phase: GameState.Phase) -> bool:
	return phase == GameState.Phase.ADMINISTRATION or phase == GameState.Phase.CAMPAIGN


func apply(state: GameState) -> void:
	TurnLoop.end_phase(state, _rules)
