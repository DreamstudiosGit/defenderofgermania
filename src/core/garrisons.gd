class_name Garrisons
extends RefCounted
## Defenders without an army: castle garrisons of house provinces and the levy of provinces
## without a house. Their companies share one health value (ProvinceState.garrison_health).


## Companies defending the province now; 0 once the garrison has broken.
static func size(state: GameState, rules: GameRules, province_id: String) -> int:
	var province := state.provinces[province_id]
	if province.garrison_health < rules.map.campaign.disband_health:
		return 0
	if not state.houses.has(province.owner):
		var fixed := rules.map.provinces[province_id].garrison
		return rules.map.campaign.neutral_garrison(province.population, fixed)
	return castle(state, rules, province_id).garrison


static func wall(state: GameState, rules: GameRules, province_id: String) -> int:
	return castle(state, rules, province_id).wall


## The castle level the province's owner holds: home castle table in a house's home
## province, province castle table everywhere else.
static func castle(state: GameState, rules: GameRules, province_id: String) -> CastleLevelDef:
	var province := state.provinces[province_id]
	var owner: HouseState = state.houses.get(province.owner)
	var is_home := owner != null and owner.home_province == province_id
	var table := rules.economy.home_castle if is_home else rules.economy.province_castle
	return table[province.castle_level]


static func side(state: GameState, rules: GameRules, province_id: String) -> BattleSide:
	var province := state.provinces[province_id]
	var defenders := BattleSide.new()
	defenders.owner = province.owner
	for _i: int in size(state, rules, province_id):
		defenders.add_company(rules.map.campaign.garrison_unit, province.garrison_health)
	return defenders


## Settlement: every besieged garrison loses a share of its HP (less with a granary); a
## broken garrison hands the castle to the first besieging house.
static func starve(state: GameState, rules: GameRules) -> void:
	for province: ProvinceState in state.provinces.values():
		var besiegers := state.armies_in(province.id).filter(
			func(army: ArmyState) -> bool: return state.is_besieging(army)
		)
		if besiegers.is_empty():
			continue
		var loss := rules.economy.siege_starve_loss
		for id: String in province.buildings:
			loss *= rules.economy.buildings[id].siege_starve_multiplier
		province.garrison_health = maxf(0.0, province.garrison_health - loss)
		if size(state, rules, province.id) == 0:
			var winner: ArmyState = besiegers[0]
			Conquest.conquer(state, rules, province.id, winner.owner, true)


## Settlement: garrisons that are not besieged heal like armies in their own province.
static func recover(state: GameState, rules: GameRules) -> void:
	for province: ProvinceState in state.provinces.values():
		if not Movement.has_hostile_army(state, province.id, province.owner):
			var healed := province.garrison_health + rules.map.campaign.recovery_own
			province.garrison_health = minf(1.0, healed)
