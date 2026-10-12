class_name Conquest
extends RefCounted
## Ownership changes: conquest with occupation and castle damage, loss of the home castle
## (exile), a new home castle for an exiled house, and elimination.

const NEUTRAL := "neutral"


## Hands the province to the house. A castle taken by siege loses one level; a castle that
## is nobody's home castle any more is capped at the province castle table. An exiled house
## that takes its old home back, or a castle from the exile level, makes it its home castle.
static func conquer(
	state: GameState, rules: GameRules, province_id: String, house_id: String, by_siege: bool
) -> void:
	var province := state.provinces[province_id]
	var previous: HouseState = state.houses.get(province.owner)
	var was_home := previous != null and previous.home_province == province_id
	var level_before := province.castle_level
	province.owner = house_id
	province.occupied_rounds = rules.map.campaign.occupation_rounds
	province.in_revolt = false
	province.garrison_health = 1.0
	province.constructions.clear()
	var level := maxi(level_before - 1, 0) if by_siege else level_before
	var conqueror := state.houses[house_id]
	var is_old_home := conqueror.home_province == province_id
	var is_castle := level_before >= rules.map.campaign.exile_min_castle_level
	if conqueror.exile_rounds > 0 and (is_old_home or is_castle):
		conqueror.home_province = province_id
		conqueror.exile_rounds = 0
		province.castle_level = maxi(level, 1)
	else:
		province.castle_level = mini(level, _max_province_castle(rules))
	CrownRules.occupy(state, rules.map, house_id, province_id)
	if was_home:
		_lose_home(state, rules, previous)


## Settlement: exiled houses run out of time and are eliminated.
static func count_down_exile(state: GameState) -> void:
	for house: HouseState in state.houses.values():
		if house.exile_rounds > 0:
			house.exile_rounds -= 1
			if house.exile_rounds == 0:
				eliminate(state, house)


## The house leaves the game: its provinces fall to neutral lords, its armies disband.
static func eliminate(state: GameState, house: HouseState) -> void:
	house.is_eliminated = true
	house.exile_rounds = 0
	for province: ProvinceState in state.provinces_of(house.id):
		province.owner = NEUTRAL
		province.garrison_health = 1.0
		province.occupied_rounds = 0
		province.in_revolt = false
		province.constructions.clear()
	for army: ArmyState in state.armies_of(house.id):
		state.remove_army(army)


## Exile: the house keeps one army (the leader's, else the largest) and its decorations are
## lost with the castle; without provinces or armies it is eliminated at once.
static func _lose_home(state: GameState, rules: GameRules, house: HouseState) -> void:
	house.decorations.clear()
	var armies := state.armies_of(house.id)
	if armies.is_empty() and state.provinces_of(house.id).is_empty():
		eliminate(state, house)
		return
	house.exile_rounds = rules.map.campaign.exile_rounds
	var kept: ArmyState = null
	for army: ArmyState in armies:
		if army.id == house.leader_army:
			kept = army
			break
		if kept == null or army.company_count() > kept.company_count():
			kept = army
	for army: ArmyState in armies:
		if army != kept:
			state.remove_army(army)


static func _max_province_castle(rules: GameRules) -> int:
	var highest := 0
	for level: int in rules.economy.province_castle:
		highest = maxi(highest, level)
	return highest
