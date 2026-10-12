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


## Taler the house keeps back from spending.
func reserve() -> float:
	return cfg.supply["gold_reserve"]


func spare_gold() -> float:
	return owner().gold - reserve()


## Runs the command if the rules accept it and logs it; true if it ran.
func act(command: Command, label: String, utility: float) -> bool:
	var error := command.execute(state)
	log.add(state.turn, state.phase, label, utility, error.is_empty(), error)
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
