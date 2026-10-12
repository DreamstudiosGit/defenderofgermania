class_name AiGoals
extends RefCounted
## Decision level 3, goals (GDD): the next steps on the pillars of the crown and for the land,
## each valued as taler worth per taler spent; the best are taken one after another while the
## treasury keeps its reserve. The coronation comes first whenever the rules allow it.

const MAX_ACTIONS := 6


static func run(turn: AiTurn) -> void:
	if AiCourt.crown(turn):
		return
	for _i: int in MAX_ACTIONS:
		var options: Array[AiOption] = []
		var floor := turn.cfg.goals["min_utility"]
		var all := AiCourt.options(turn) + AiBuilding.options(turn) + AiSecurity.field_options(turn)
		for option: AiOption in all:
			if option.utility >= floor and turn.owner().gold - option.cost >= turn.reserve():
				options.append(option)
		var choice := turn.choose(options)
		if choice == null or not turn.act(choice.command, choice.label, choice.utility):
			return
