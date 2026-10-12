extends GutTest
## What the campaign does to the road to the crown: war costs a lord's favour, attacking church
## land risks the ban, occupying an elector angers the others, beating an enemy next to an
## elector earns his thanks, and patron mercenaries fight one battle.

var _rules: GameRules
var _state: GameState


func before_each() -> void:
	_rules = GameRules.load_files()
	_state = GameSetup.create(_rules.map, _rules.economy, 1)


func test_war_against_a_lord_costs_twenty_favour() -> void:
	CrownRules.attack(_state, _rules.map, "staufer", "ELS")
	assert_eq(_state.crown.favour_of("ELS", "staufer"), 30.0, "50 − 20")
	CrownRules.attack(_state, _rules.map, "staufer", "SPT")
	assert_eq(_state.crown.favour_of("SPT", "staufer"), 0.0, "an own province is no war")


func test_attacking_church_land_risks_the_ban() -> void:
	_rules.map.crown.ban_attack_church_chance = 1.0
	CrownRules.attack(_state, _rules.map, "staufer", "ELS")
	assert_false(_state.houses["staufer"].is_banned, "Alsace is secular")
	CrownRules.attack(_state, _rules.map, "welfen", "OSN")
	assert_true(_state.houses["welfen"].is_banned)
	_rules.map.crown.ban_attack_church_chance = 0.0
	CrownRules.attack(_state, _rules.map, "wettiner", "MAG")
	assert_false(_state.houses["wettiner"].is_banned)


func test_occupying_an_elector_forces_his_vote_and_angers_the_others() -> void:
	Conquest.conquer(_state, _rules, "TRI", "welfen", false)
	assert_eq(CrownRules.votes(_state, _rules.map)["TRI"], "welfen")
	assert_eq(_state.crown.favour_of("KOE", "welfen"), 45.0, "55 − 10")
	assert_eq(_state.crown.favour_of("TRI", "welfen"), 30.0, "his own list is untouched")
	assert_eq(_state.houses["welfen"].pending_prestige, -5.0)
	Conquest.conquer(_state, _rules, "ELS", "welfen", false)
	assert_eq(_state.crown.favour_of("KOE", "welfen"), 45.0, "a neutral province is no elector")


func test_beating_an_enemy_next_to_an_elector_earns_his_thanks() -> void:
	var welfen := _state.add_army("welfen", "AAC")
	welfen.add_company("knights")
	var staufer := _state.add_army("staufer", "AAC")
	staufer.add_company("levy")
	_rules.resolver = func(setup: BattleSetup) -> BattleResult: return _won(setup)
	assert_true(CampaignBattles.fight_army(_state, _rules, welfen, staufer, ""))
	assert_eq(_state.crown.favour_of("KOE", "welfen"), 65.0, "Cologne borders Aachen: +10")
	assert_eq(_state.crown.favour_of("TRI", "welfen"), 40.0, "so does Trier")
	assert_eq(_state.crown.favour_of("MAI", "welfen"), 30.0, "Mainz does not")


func test_patron_mercenaries_fight_one_battle_and_leave() -> void:
	_state.crown.mercenaries["welfen"] = 4
	var welfen := _state.armies_of("welfen")[0]
	var raiders := _state.add_army("staufer", welfen.province)
	raiders.add_company("levy")
	var sizes: Array[int] = []
	_rules.resolver = func(setup: BattleSetup) -> BattleResult:
		sizes.append(setup.defender.company_count())
		return _won(setup, false)
	CampaignBattles.fight_army(_state, _rules, raiders, welfen, "")
	assert_eq(sizes, [8] as Array[int], "four own companies and four Brabanters")
	assert_eq(welfen.company_count(), 4, "the mercenaries are gone after the battle")
	assert_false(_state.crown.mercenaries.has("welfen"))


func test_a_move_into_a_lords_province_is_war() -> void:
	var army := _state.armies_of("staufer")[0]
	army.province = "SPT"
	_state.phase = GameState.Phase.CAMPAIGN
	_state.active_index = _state.turn_order.find("staufer")
	army.moves_left = 1
	MoveArmyCommand.new(_rules, "staufer", army.id, "ELS").execute(_state)
	assert_eq(_state.crown.favour_of("ELS", "staufer"), 30.0)


func _won(setup: BattleSetup, attacker_wins: bool = true) -> BattleResult:
	var result := BattleResult.new()
	result.attacker_won = attacker_wins
	for i: int in setup.attacker.company_count():
		result.attacker_health.append(1.0)
	for i: int in setup.defender.company_count():
		result.defender_health.append(1.0)
	return result
