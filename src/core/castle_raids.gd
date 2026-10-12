class_name CastleRaids
extends RefCounted
## The campaign side of the castle raid (GDD "Burgüberfall"): which castles the leader can
## reach, which targets they hold, playing the raid live or by the computer, and its
## consequences — loot, prestige and a blade win, or captivity or a wound; church land risks
## the ban.

const TREASURY := "treasury"
const DUNGEON := "dungeon"
const GRANARY := "granary"
const REGALIA := "regalia"
## A wound costs the leader's aura for the rest of this round and the next.
const WOUND_ROUNDS := 2


## Foreign castles in or next to the province where the house's leader rides with an army.
static func castles(state: GameState, rules: GameRules, house: String) -> Array[String]:
	var result: Array[String] = []
	var army := state.army(state.houses[house].leader_army)
	if army == null:
		return result
	var nearby: Array[String] = [army.province]
	nearby.append_array(rules.map.provinces[army.province].neighbors)
	for id: String in nearby:
		var province := state.provinces[id]
		if province.owner != house and province.castle_level > 0:
			result.append(id)
	return result


## Targets the castle holds: a house's treasury and granary, the true regalia where they lie,
## a dungeon with prisoners.
static func targets(state: GameState, province_id: String) -> Array[String]:
	var result: Array[String] = []
	var owner := state.provinces[province_id].owner
	if state.houses.has(owner):
		result.append_array([TREASURY, GRANARY])
	if not prisoners(state, owner).is_empty():
		result.append(DUNGEON)
	if state.crown.regalia_province == province_id:
		result.append(REGALIA)
	return result


## Houses whose leaders the owner holds captive.
static func prisoners(state: GameState, owner: String) -> Array[String]:
	var result: Array[String] = []
	for house: HouseState in state.houses.values():
		if house.leader_captor == owner and not owner.is_empty():
			result.append(house.id)
	return result


static func setup(
	state: GameState, rules: GameRules, house: String, province_id: String, target: String
) -> RaidSetup:
	var province := state.provinces[province_id]
	var owner: HouseState = state.houses.get(province.owner)
	var raid := RaidSetup.new()
	raid.raider_house = house
	raid.blade = state.houses[house].blade
	raid.target = target
	raid.defender_owner = province.owner
	raid.castle_level = province.castle_level
	raid.home_castle = owner != null and owner.home_province == province_id
	raid.guard_skill = rules.map.campaign.adventure_opponent_skill
	return raid


## What the player achieved live, else the computer's raid at the campaign's auto skill.
static func play(state: GameState, rules: GameRules, raid: RaidSetup) -> RaidResult:
	var live: RefCounted = null
	if rules.adventure_resolver.is_valid():
		live = rules.adventure_resolver.call(raid)
	if live is RaidResult:
		return live
	var skill := rules.map.campaign.adventure_auto_skill
	return RaidAI.auto_resolve(rules.raid, raid, state.rng.randi(), skill)


static func apply(
	state: GameState, rules: GameRules, raid: RaidSetup, province_id: String, result: RaidResult
) -> void:
	var raider := state.houses[raid.raider_house]
	raider.adventure_turn = state.turn
	if rules.map.provinces[province_id].is_church:
		CrownRules.risk_ban(state, raider.id, rules.map.crown.ban_raid_church_chance)
	if not result.success:
		if result.outcome == RaidResult.Outcome.CAPTURED:
			CampaignBattles.capture(raider, raid.defender_owner)
		else:
			raider.wounded_until = state.turn + WOUND_ROUNDS
		return
	_take(state, rules, raider, raid)
	raider.pending_prestige += rules.raid.prestige(raid.target)
	var campaign := rules.map.campaign
	raider.add_win("blade", campaign.leader_wins_per_point, campaign.leader_max)


static func _take(state: GameState, rules: GameRules, raider: HouseState, raid: RaidSetup) -> void:
	var victim: HouseState = state.houses.get(raid.defender_owner)
	match raid.target:
		TREASURY:
			if victim != null:
				var loot := rules.raid.treasury_loot(int(maxf(victim.gold, 0.0)))
				victim.gold -= loot
				raider.gold += loot
		GRANARY:
			if victim != null:
				victim.grain -= rules.raid.granary_loss(victim.grain)
		REGALIA:
			state.crown.regalia_province = raider.home_province
		DUNGEON:
			for id: String in prisoners(state, raid.defender_owner):
				state.houses[id].leader_captor = ""
