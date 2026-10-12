class_name CrownSettlement
extends RefCounted
## Round phase 4 for the crown, before the economy closes the round: favour grows with
## prestige and the imperial palace and drifts back towards its rest value, forged regalia
## get finished, patron cards may be played again, and a new year forgets last year's gifts.


static func settle(state: GameState, map: MapData) -> void:
	var crown := map.crown
	var electors := map.electors()
	for house: HouseState in state.houses.values():
		if house.is_eliminated:
			continue
		var gain := house.prestige / crown.favour_prestige_divisor
		var has_palace := state.home_castle_level(house.id) >= crown.imperial_palace_home_castle
		var palace := crown.favour_changes["imperial_palace"] if has_palace else 0.0
		for id: String in map.provinces:
			if not state.crown.has_favour_list(id, house.id):
				continue
			var bonus := palace if id in electors else 0.0
			CrownRules.change_favour(state, map, id, house.id, gain + bonus)
			_drift(state, map, id, house.id)
	_finish_forging(state)
	state.crown.patron_played.clear()
	if state.season() == GameState.Season.WINTER:
		state.crown.gifts.clear()


static func _drift(state: GameState, map: MapData, province_id: String, house: String) -> void:
	var crown := map.crown
	var value := state.crown.favour_of(province_id, house)
	var limit := crown.favour_drift_per_round
	var step := clampf(crown.favour_drift_to - value, -limit, limit)
	state.crown.set_favour(province_id, house, value + step, crown.favour_max)


static func _finish_forging(state: GameState) -> void:
	for house: String in state.crown.forging.keys():
		state.crown.forging[house] -= 1
		if state.crown.forging[house] <= 0:
			state.crown.forging.erase(house)
			state.crown.forged_regalia.append(house)
