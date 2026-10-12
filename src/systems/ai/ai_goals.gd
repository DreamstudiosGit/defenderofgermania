class_name AiGoals
extends RefCounted
## Decision level 3, goals (GDD): the next steps on the pillars of the crown and for the land,
## each valued as taler worth per taler spent; the best are taken one after another while the
## treasury keeps its reserve. When the best step is still too dear but within reach of a few
## rounds' income, the house saves for it instead of buying something weaker. The coronation
## comes first whenever the rules allow it.

const MAX_ACTIONS := 6


static func run(turn: AiTurn) -> void:
	if AiCourt.crown(turn):
		return
	var income := maxf(
		EconomyTerm.sum(EconomyBreakdown.gold_change(
			turn.state, turn.rules.map, turn.rules.economy, turn.house
		)),
		0.0
	)
	for _i: int in MAX_ACTIONS:
		var options: Array[AiOption] = []
		var floor := turn.cfg.goals["min_utility"]
		var saving_for: AiOption = null
		var all := AiCourt.options(turn) + AiBuilding.options(turn) + AiSecurity.field_options(turn)
		for option: AiOption in all:
			if option.utility < floor:
				continue
			if option.upkeep > 0.0 and income - option.upkeep < 0.0:
				continue
			if turn.owner().gold - option.cost >= turn.reserve():
				options.append(option)
			elif option.cost <= turn.owner().gold + income * turn.cfg.goals["save_rounds"]:
				if saving_for == null or option.utility > saving_for.utility:
					saving_for = option
		var best_now := 0.0
		for option: AiOption in options:
			best_now = maxf(best_now, option.utility)
		if saving_for != null and saving_for.utility > best_now * turn.cfg.goals["save_factor"]:
			var label := "save for " + saving_for.label
			turn.log.add(turn.state.turn, turn.state.phase, label, saving_for.utility, false, "")
			return
		var choice := turn.choose(options)
		if choice == null or not turn.act(choice.command, choice.label, choice.utility):
			return
		income -= choice.upkeep
