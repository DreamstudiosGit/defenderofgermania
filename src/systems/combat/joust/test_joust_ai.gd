extends GutTest
## Computer riders: fixed error patterns per skill, clear ordering of the skills over many
## seeds, either rider, and the length of a joust.

const SEEDS := 24
const MIN_SECONDS := 60.0
const MAX_SECONDS := 180.0

var _cfg: JoustConfig


func before_all() -> void:
	_cfg = JoustConfig.load_file()


func test_higher_skill_beats_lower_skill_clearly() -> void:
	for pair: Array in [[3, 0, 0.95], [3, 1, 0.85], [2, 0, 0.85], [2, 1, 0.7], [1, 0, 0.7]]:
		var wins := _wins(pair[0], pair[1])
		var needed := ceili(SEEDS * float(pair[2]))
		assert_gte(wins, needed, "skill %d vs %d won %d of %d" % [pair[0], pair[1], wins, SEEDS])


func test_the_champion_beats_the_tournament_knight_more_often_than_not() -> void:
	var wins := _wins(3, 2)
	assert_gt(wins * 2, SEEDS, "skill 3 vs 2 won %d of %d" % [wins, SEEDS])


func test_the_computer_plays_either_rider() -> void:
	var setup := JoustSetup.new()
	setup.opponent_skill = 3
	var losses := 0
	for seed_value: int in SEEDS:
		if not JoustSim.play_out(_cfg, setup, seed_value, 0).won:
			losses += 1
	assert_gte(losses, ceili(SEEDS * 0.95), "a champion opponent beats a clumsy player side")


func test_a_typical_joust_lasts_one_to_three_minutes() -> void:
	for skills: Array in [[1, 1], [2, 1], [3, 0], [0, 0], [3, 3]]:
		var setup := JoustSetup.new()
		setup.opponent_skill = skills[1]
		for seed_value: int in 6:
			var result := JoustSim.play_out(_cfg, setup, seed_value, skills[0])
			assert_between(result.duration, MIN_SECONDS, MAX_SECONDS, str(skills))


func _wins(player_skill: int, opponent_skill: int) -> int:
	var setup := JoustSetup.new()
	setup.opponent_skill = opponent_skill
	var wins := 0
	for seed_value: int in SEEDS:
		if JoustSim.play_out(_cfg, setup, seed_value, player_skill).won:
			wins += 1
	return wins
