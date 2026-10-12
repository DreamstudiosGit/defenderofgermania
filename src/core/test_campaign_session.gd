extends GutTest
## The campaign session behind the map scene: two human houses play, the other two pass,
## battles can be fought live and the last settlement is kept for the report.

const HUMANS: Array[String] = ["welfen", "staufer"]
const SEED := 1198

var _rules: GameRules
var _session: CampaignSession


func before_each() -> void:
	_rules = GameRules.load_files()
	_session = CampaignSession.create(_rules, HUMANS, SEED)


func test_two_houses_play_eight_rounds_while_the_others_pass() -> void:
	assert_true(_session.is_human_turn())
	for round_index: int in 8:
		assert_eq(_session.state.turn, round_index)
		var steps := 0
		while _session.state.turn == round_index and steps < 10:
			assert_true(_session.active_house() in HUMANS, "only humans are asked to move")
			assert_eq(_end_phase(), "")
			steps += 1
		# Administration and campaign of both, plus an event phase per card awaiting a choice.
		assert_between(steps, 4, 8)
	assert_eq(_session.state.turn, 8, "eight rounds were settled")
	assert_not_null(_session.before_settlement)
	assert_eq(_session.before_settlement.turn, 7, "the snapshot is from before the last settlement")


func test_commands_of_other_houses_are_refused() -> void:
	var other := "staufer" if _session.active_house() == "welfen" else "welfen"
	var command := SetTaxRateCommand.new(_rules.economy, other, 20)
	assert_eq(_session.execute(command), Command.ERROR_NOT_ACTIVE)
	assert_eq(_session.state.houses[other].tax_rate, _rules.economy.start_tax_rate)


func test_battle_ahead_and_a_live_result_decide_the_move() -> void:
	_until_campaign_of("welfen")
	var welfen := _session.state.armies_of("welfen")[0]
	assert_null(_session.battle_ahead(welfen.id, "HOL"), "no battle in an empty own province")
	# An enemy raid into Holstein: after the battle no garrison waits in an own province.
	var enemy := _session.state.add_army("staufer", "HOL")
	enemy.add_company("levy")
	enemy.add_company("levy")
	var setup := _session.battle_ahead(welfen.id, "HOL")
	assert_not_null(setup, "moving onto an enemy army means battle")
	assert_eq(setup.attacker.owner, "welfen")
	assert_eq(setup.defender.company_count(), 2)
	var result := BattleResult.new()
	result.attacker_won = true
	result.attacker_health = PackedFloat64Array()
	for i: int in setup.attacker.company_count():
		result.attacker_health.append(0.5)
	result.defender_health = PackedFloat64Array([0.1, 0.1])
	assert_eq(_session.move_after_battle(welfen.id, "HOL", result), "")
	assert_eq(_session.state.army(welfen.id).province, "HOL")
	assert_eq(_session.state.army(welfen.id).health[0], 0.5, "the live result decided the battle")
	assert_null(_session.state.army(enemy.id), "the beaten levy broke and disbanded")


func _end_phase() -> String:
	return _session.execute(EndPhaseCommand.new(_rules, _session.active_house()))


func _until_campaign_of(house: String) -> void:
	for i: int in 16:
		var state := _session.state
		if state.active_house() == house and state.phase == GameState.Phase.CAMPAIGN:
			return
		_end_phase()
	fail_test("never reached the campaign phase of %s" % house)
