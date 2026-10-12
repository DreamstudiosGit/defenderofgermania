extends SceneTree

var _trace := false
var _last_turn := -1
## Balance run (M7): whole games between four computer houses, one JSON line per game with
## the winner, how the game ended, the round, and which houses went bankrupt (taler below 0
## after a settlement). scripts/balance.mjs runs it in parallel and sums up.
## godot --headless --script res://scripts/balance_run.gd -- --games=10 --seed=1
##   [--difficulty=1] [--out=user://balance.jsonl] [--trace=1: every round's houses]
##   [--ai=<path of an alternative data/ai.json>]


func _init() -> void:
	var args := _arguments()
	var games := int(args.get("games", "10"))
	var first := int(args.get("seed", "1"))
	var difficulty := int(args.get("difficulty", "1"))
	_trace = args.get("trace", "0") == "1"
	var out := FileAccess.open(args.get("out", "user://balance.jsonl"), FileAccess.WRITE)
	var config := AiConfig.load_file(args.get("ai", AiConfig.PATH))
	for i: int in games:
		var line := JSON.stringify(_play(config, first + i, difficulty))
		print(line)
		if out != null:
			out.store_line(line)
	quit(0)


func _play(config: AiConfig, seed_value: int, difficulty: int) -> Dictionary:
	var rules := GameRules.load_files()
	var ai := AiPlayer.new(rules, config)
	var bankrupt: Dictionary[String, Dictionary] = {}
	var player := func(state: GameState) -> void:
		for house: HouseState in state.houses.values():
			if house.gold < 0.0 and not bankrupt.has(house.id):
				var companies := 0
				for army: ArmyState in state.armies_of(house.id):
					companies += army.company_count()
				bankrupt[house.id] = {
					"round": state.turn, "gold": roundi(house.gold),
					"provinces": state.provinces_of(house.id).size(), "companies": companies,
					"exile": house.exile_rounds > 0, "castle": state.home_castle_level(house.id),
				}
		if _trace and state.turn != _last_turn:
			_last_turn = state.turn
			_print_round(state, rules)
		var house := state.active_house()
		ai.play_phase(state)
		if _trace and ai.logs.has(house):
			var taken := PackedStringArray()
			for entry: AiLog.Entry in ai.logs[house].entries:
				if entry.taken and entry.turn == state.turn:
					taken.append("%s%s" % [entry.label, "" if entry.error.is_empty() else "!"])
			if not taken.is_empty():
				print("   %s: %s" % [house, ", ".join(taken)])
			ai.logs[house].entries.clear()
	var houses := rules.map.houses
	var none: Array[String] = []
	var computers := AiPlayer.opponents(config, houses, none, difficulty)
	var started := Time.get_ticks_msec()
	var session := CampaignSession.create(rules, none, seed_value, computers, player)
	var state := session.state
	var ending := "time"
	if not state.crown.crowned_at.is_empty():
		ending = "coronation"
	elif state.turn < rules.map.campaign.max_rounds:
		ending = "subjugation"
	var legitimacy := {}
	var finals := {}
	for house: String in houses:
		legitimacy[house] = snappedf(Victory.legitimacy(state, rules, house), 0.1)
		var owner := state.houses[house]
		finals[house] = {
			"castle": state.home_castle_level(house),
			"votes": CrownRules.vote_count(state, rules.map, house),
			"regalia": CrownRules.regalia(state, house).size(),
			"site": AiStrength.pillars(state, rules, house),
			"provinces": state.provinces_of(house).size(),
			"gold": roundi(owner.gold),
			"prestige": roundi(owner.prestige),
			"out": owner.is_eliminated,
			"crown_error": CrownRules.coronation_error(state, rules.map, house),
			"needed": CrownRules.votes_needed(state, rules.map, house),
		}
	return {
		"seed": seed_value,
		"winner": state.winner,
		"ending": ending,
		"round": state.turn + 1,
		"bankrupt": bankrupt.keys(),
		"bankruptcies": bankrupt,
		"legitimacy": legitimacy,
		"houses": finals,
		"ms": Time.get_ticks_msec() - started,
	}


func _print_round(state: GameState, rules: GameRules) -> void:
	var parts := PackedStringArray()
	for house: HouseState in state.houses.values():
		if house.is_eliminated:
			parts.append("%s out" % house.id)
			continue
		var companies := 0
		for army: ArmyState in state.armies_of(house.id):
			companies += army.company_count()
		parts.append("%s g%d p%d a%d/%d c%d v%d pr%d%s" % [
			house.id.substr(0, 4), house.gold, state.provinces_of(house.id).size(),
			state.armies_of(house.id).size(), companies, state.home_castle_level(house.id),
			CrownRules.vote_count(state, rules.map, house.id), house.prestige,
			" EXILE" if house.exile_rounds > 0 else "",
		])
	print("r%d %s" % [state.turn + 1, " | ".join(parts)])


func _arguments() -> Dictionary[String, String]:
	var result: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			var parts := arg.substr(2).split("=", true, 1)
			result[parts[0]] = parts[1]
	return result
