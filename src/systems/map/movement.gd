class_name Movement
extends RefCounted
## Campaign movement on the map (docs/design/map.md, "Armies"): steps per round, retreats
## and recovery of wounded companies.


## Gives every army of the house its steps for this campaign phase.
static func start_campaign(state: GameState, rules: CampaignRules, house: String) -> void:
	var steps := rules.moves_per_round(state.season() == GameState.Season.SUMMER)
	for army: ArmyState in state.armies_of(house):
		army.moves_left = steps


## Steps left after entering a province: the summer bonus step only follows an own province.
static func steps_after(army_owner: String, province_owner: String, moves_left: int) -> int:
	return moves_left - 1 if province_owner == army_owner else 0


static func has_hostile_army(state: GameState, province_id: String, house: String) -> bool:
	for army: ArmyState in state.armies_in(province_id):
		if army.owner != house:
			return true
	return false


## Own neighbour without hostile armies a beaten army falls back to, preferring `preferred`;
## "" if there is none.
static func retreat_target(
	state: GameState, map: MapData, army: ArmyState, preferred: String
) -> String:
	var candidates: Array[String] = []
	if map.are_neighbors(army.province, preferred):
		candidates.append(preferred)
	candidates.append_array(map.provinces[army.province].neighbors)
	for id: String in candidates:
		if state.provinces[id].owner == army.owner and not has_hostile_army(state, id, army.owner):
			return id
	return ""


## Wounded companies heal a share of their full HP each round, more in own provinces.
static func recover(state: GameState, rules: CampaignRules) -> void:
	for army: ArmyState in state.armies:
		var amount := rules.recovery(state.provinces[army.province].owner == army.owner)
		for i: int in army.health.size():
			army.health[i] = minf(1.0, army.health[i] + amount)
