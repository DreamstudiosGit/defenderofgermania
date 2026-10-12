class_name AiPlayer
extends RefCounted
## The computer opponents (GDD "KI-Gegner"): plays the active computer house's phase with the
## same Commands as a human — event cards, then supply, security and goals in the
## administration, opportunity on campaign — and keeps every house's log for the debug overlay.
## The session ends the phase afterwards (CampaignSession.computer).

var rules: GameRules
var cfg: AiConfig
var logs: Dictionary[String, AiLog] = {}


func _init(game_rules: GameRules, config: AiConfig) -> void:
	rules = game_rules
	cfg = config


## Personality and difficulty of every house nobody plays, by the data's defaults.
static func opponents(
	config: AiConfig, houses: Array[String], humans: Array[String], difficulty: int = -1
) -> Dictionary[String, Array]:
	var result: Dictionary[String, Array] = {}
	var level := config.default_difficulty if difficulty < 0 else difficulty
	for house: String in houses:
		if house not in humans:
			result[house] = [config.personality_of(house), level]
	return result


func play_phase(state: GameState) -> void:
	var house := state.active_house()
	if house.is_empty() or not state.houses[house].is_computer():
		return
	if not logs.has(house):
		logs[house] = AiLog.new()
	var turn := AiTurn.new(state, rules, cfg, house, logs[house])
	match state.phase:
		GameState.Phase.EVENT:
			AiEvents.answer(turn)
		GameState.Phase.ADMINISTRATION:
			AiSupply.run(turn)
			AiSecurity.run(turn)
			AiGoals.run(turn)
		GameState.Phase.CAMPAIGN:
			AiCampaign.run(turn)
