class_name AiTurn
extends RefCounted
## One computer house's phase in progress: state, rules, its personality and difficulty, and
## the log of every option it weighed (the debug overlay shows it). Every action is a Command,
## validated exactly like a human's.

var state: GameState
var rules: GameRules
var cfg: AiConfig
var house: String
var personality: String
var level: AiConfig.Difficulty
var log: AiLog


func _init(
	game_state: GameState, game_rules: GameRules, config: AiConfig, house_id: String, sink: AiLog
) -> void:
	state = game_state
	rules = game_rules
	cfg = config
	house = house_id
	var owner := state.houses[house]
	personality = owner.personality
	level = cfg.difficulty(owner.difficulty)
	log = sink


func owner() -> HouseState:
	return state.houses[house]


func weight(category: String) -> float:
	return cfg.weight(personality, category)


func value(key: String) -> float:
	return cfg.values.get(key, 0.0)


## Taler the house keeps back from spending: more when the coming settlement runs a deficit.
func reserve() -> float:
	var change := EconomyTerm.sum(
		EconomyBreakdown.gold_change(state, rules.map, rules.economy, house)
	)
	return maxf(cfg.supply["gold_reserve"], -change * 2.0)


func spare_gold() -> float:
	return owner().gold - reserve()


## True if the rules would accept the command were the treasury full: the house may save for it.
func allowed(command: Command) -> bool:
	var house_state := owner()
	var gold := house_state.gold
	house_state.gold = 1.0e12
	var ok := command.validate(state).is_empty()
	house_state.gold = gold
	return ok


## Pillars of the crown the house holds; a step towards a missing one is worth more the more it
## already holds (the last pillar decides the game) and the later it is in the game.
func pillar_worth() -> float:
	var held := AiStrength.pillars(state, rules, house)
	var urgency := 1.0 + float(state.turn) / value("pillar_urgency_rounds")
	return value("pillar") * (1.0 + held) * urgency


## Enemy strength that could strike the province next round (lone home guards count partly);
## with `far` also armies two steps away at the data's share (used by the home guard).
func threat(province_id: String, far: bool = false) -> float:
	var security := cfg.security
	var far_share: float = security["far_share"] if far else 0.0
	return AiStrength.threat(
		state, rules, house, province_id, far_share, security["guarding_share"]
	)


## Runs the command if the rules accept it and logs it; true if it ran.
func act(command: Command, label: String, utility: float) -> bool:
	var turn := state.turn
	var phase := state.phase
	var error := command.execute(state)
	log.add(turn, phase, label, utility, error.is_empty(), error)
	return error.is_empty()


## The option to take among those the rules accept: the best by utility, or — at the
## difficulty's suboptimal share — a random worse one. Every option is logged.
func choose(options: Array[AiOption]) -> AiOption:
	var valid: Array[AiOption] = []
	for option: AiOption in options:
		if option.command == null or option.command.validate(state).is_empty():
			valid.append(option)
	valid.sort_custom(func(a: AiOption, b: AiOption) -> bool: return a.utility > b.utility)
	for option: AiOption in valid:
		log.add(state.turn, state.phase, option.label, option.utility, false, "")
	if valid.is_empty():
		return null
	var share := level.suboptimal_share
	if valid.size() > 1 and share > 0.0 and state.rng.randf() < share:
		return valid[state.rng.randi_range(1, valid.size() - 1)]
	return valid[0]
