class_name CampaignBattles
extends RefCounted
## Builds battles from armies and garrisons, runs them through the rules' resolver and
## applies the result: losses, disbanding, retreat, captured leaders and prestige.


## Field battle of the arriving army against one hostile army; true if the attacker won.
static func fight_army(
	state: GameState, rules: GameRules, attacker: ArmyState, defender: ArmyState, came_from: String
) -> bool:
	var province := attacker.province
	var setup := army_battle(state, rules, attacker, defender, province)
	var result := rules.resolve_battle(state, setup)
	var winner := attacker.owner if result.attacker_won else defender.owner
	_apply(state, rules, attacker, result, true, defender.owner, came_from)
	_apply(state, rules, defender, result, false, attacker.owner, "")
	CrownRules.protect(state, rules.map, winner, province)
	return result.attacker_won


## Battle against the province's garrison, behind walls of level `wall` (0 in the open);
## true if the attacker won.
static func fight_garrison(
	state: GameState, rules: GameRules, attacker: ArmyState, wall: int, came_from: String
) -> bool:
	var province := state.provinces[attacker.province]
	var setup := garrison_battle(state, rules, attacker, wall, province.id)
	var result := rules.resolve_battle(state, setup)
	var won := result.attacker_won
	province.garrison_health = 0.0 if won else _lowest(result.defender_health)
	_add_prestige(state, rules, province.owner, not won)
	_apply(state, rules, attacker, result, true, province.owner, came_from)
	return won


## The battle an army fights against a hostile army in the province.
static func army_battle(
	state: GameState, rules: GameRules, attacker: ArmyState, defender: ArmyState, province: String
) -> BattleSetup:
	var setup := _setup(state, rules, province)
	setup.attacker = army_side(state, rules, attacker)
	setup.defender = army_side(state, rules, defender)
	return setup


## The battle an army fights against the province's garrison behind walls of level `wall`.
static func garrison_battle(
	state: GameState, rules: GameRules, attacker: ArmyState, wall: int, province: String
) -> BattleSetup:
	var setup := _setup(state, rules, province)
	setup.defender_wall = wall
	setup.attacker = army_side(state, rules, attacker)
	setup.defender = Garrisons.side(state, rules, province)
	return setup


static func army_side(state: GameState, rules: GameRules, army: ArmyState) -> BattleSide:
	var house := state.houses[army.owner]
	var side := BattleSide.new()
	side.owner = army.owner
	for i: int in army.company_count():
		side.add_company(army.units[i], army.health[i])
	for _i: int in state.crown.mercenaries.get(army.owner, 0):
		side.add_company(rules.map.crown.patron_mercenary_unit, 1.0)
	side.has_leader = house.leader_army == army.id
	side.leadership = house.leadership if side.has_leader else 0
	if house.is_leader_captured():
		side.morale_bonus = rules.combat.morale_leader_captured
	return side


static func _setup(state: GameState, rules: GameRules, province_id: String) -> BattleSetup:
	var setup := BattleSetup.new()
	setup.terrain = rules.map.provinces[province_id].terrain
	setup.is_winter = state.season() == GameState.Season.WINTER
	setup.season = state.season()
	return setup


## Losses, then retreat or disbanding for the loser. A leader is captured when the battle
## says so, or when a beaten army has nowhere to retreat.
static func _apply(
	state: GameState,
	rules: GameRules,
	army: ArmyState,
	result: BattleResult,
	is_attacker: bool,
	enemy: String,
	preferred_retreat: String
) -> void:
	var house := state.houses[army.owner]
	var won := result.attacker_won == is_attacker
	var captured := (
		result.attacker_leader_captured if is_attacker else result.defender_leader_captured
	)
	_add_prestige(state, rules, army.owner, won)
	if captured and house.leader_army == army.id:
		_capture(house, enemy)
	# Patron mercenaries fight behind the army's own companies and leave after one battle.
	var health := result.attacker_health if is_attacker else result.defender_health
	army.health = health.slice(0, army.company_count())
	state.crown.mercenaries.erase(army.owner)
	for i: int in range(army.company_count() - 1, -1, -1):
		if army.health[i] < rules.map.campaign.disband_health:
			army.remove_company(i)
	if not won:
		army.moves_left = 0
		var target := Movement.retreat_target(state, rules.map, army, preferred_retreat)
		if target.is_empty() or army.company_count() == 0:
			if house.leader_army == army.id:
				_capture(house, enemy)
			state.remove_army(army)
			return
		army.province = target
	if army.company_count() == 0:
		state.remove_army(army)


static func _capture(house: HouseState, captor: String) -> void:
	house.leader_captor = captor
	house.leader_army = HouseState.NO_ARMY


static func _add_prestige(state: GameState, rules: GameRules, owner: String, won: bool) -> void:
	var house: HouseState = state.houses.get(owner)
	if house != null:
		var change := rules.economy.battle_won_prestige
		house.pending_prestige += change if won else -rules.economy.battle_lost_prestige


static func _lowest(health: PackedFloat64Array) -> float:
	var lowest := 1.0
	for value: float in health:
		lowest = minf(lowest, value)
	return lowest
