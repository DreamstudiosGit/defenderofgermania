class_name Adventures
extends RefCounted
## The campaign side of the adventure minigames (GDD "Abenteuer-Module"): a house needs its
## leader free and has at most one adventure a round; the minigame is played live through
## GameRules.adventure_resolver or by the computer at the campaign's auto skill, and its
## result changes the game.

const MERCHANT_TRAIN := "merchant_train"
const JOUST := "joust"
const CASTLE_RAID := "castle_raid"
## The trebuchet minigame of a siege; no adventure in the GDD's sense (no leader, not counted).
const TREBUCHET := "trebuchet"
## Owner id of the champions at a tournament: an elector's court, or knights visiting the host.
const ELECTOR_CHAMPION := "elector"
const VISITING_CHAMPION := "neutral"
const ERROR_DONE := "ADVENTURE_DONE_THIS_ROUND"
const ERROR_LEADER_CAPTURED := "ADVENTURE_LEADER_CAPTURED"
## Captor of a leader whom a merchant train's escort took.
const MERCHANT_CAPTOR := "neutral"


## Skill the computer plays the house's side of a minigame with: a computer house's difficulty,
## else the campaign's auto skill for a human house that lets it resolve itself.
static func auto_skill(state: GameState, rules: GameRules, house: String) -> int:
	var owner := state.houses[house]
	return owner.difficulty if owner.is_computer() else rules.map.campaign.adventure_auto_skill


## Why the house cannot start an adventure now; "" if it can.
static func error(state: GameState, house: String) -> String:
	var owner := state.houses[house]
	if owner.is_leader_captured():
		return ERROR_LEADER_CAPTURED
	return ERROR_DONE if owner.adventure_turn == state.turn else ""


## The minigame setup an event card's adventure starts, or null.
static func event_setup(
	state: GameState, rules: GameRules, card: EventState.EventCard, adventure: String
) -> RefCounted:
	match adventure:
		MERCHANT_TRAIN:
			return merchant_setup(state, rules, card.house, card.province)
		JOUST:
			var host := favourite_elector(state, rules, card.house)
			return joust_setup(state, rules, card.house, host)
		CASTLE_RAID:
			var castle := hostage_castle(state, card.house)
			if castle.is_empty():
				return null
			return CastleRaids.setup(state, rules, card.house, castle, CastleRaids.DUNGEON)
	return null


## Plays the adventure an event card starts and applies its result; true if it went well.
static func play_event(
	state: GameState, rules: GameRules, card: EventState.EventCard, adventure: String
) -> bool:
	match adventure:
		MERCHANT_TRAIN:
			var setup := merchant_setup(state, rules, card.house, card.province)
			var result := play_merchant(state, rules, setup)
			apply_merchant(state, card.house, result)
			return not result.leader_captured and result.wagons_stopped > 0
		JOUST:
			var invitation := event_setup(state, rules, card, adventure) as JoustSetup
			var joust := play_joust(state, rules, invitation)
			apply_joust(state, rules, invitation, joust)
			return joust.won
		CASTLE_RAID:
			var rescue := event_setup(state, rules, card, adventure) as RaidSetup
			if rescue == null:
				return false
			var castle := hostage_castle(state, card.house)
			var raid := CastleRaids.play(state, rules, rescue)
			CastleRaids.apply(state, rules, rescue, castle, raid)
			return raid.success
	return false


## Where the house's kinsman is held hostage: the home castle of its strongest rival (highest
## prestige, the first in turn order on a tie); "" without one.
static func hostage_castle(state: GameState, house: String) -> String:
	var best: HouseState = null
	for id: String in state.turn_order:
		var rival := state.houses[id]
		if id == house or rival.is_eliminated or state.home_castle_level(id) == 0:
			continue
		if best == null or rival.prestige > best.prestige:
			best = rival
	return best.home_province if best != null else ""


## A joust at the host's tournament against a champion of the host's court.
static func joust_setup(
	state: GameState, rules: GameRules, house: String, host_province: String
) -> JoustSetup:
	var rider := state.houses[house]
	var setup := JoustSetup.new()
	setup.house = house
	setup.lance = rider.lance
	var is_elector := rules.map.provinces[host_province].owner == CrownRules.ELECTOR
	setup.opponent = ELECTOR_CHAMPION if is_elector else VISITING_CHAMPION
	setup.opponent_lance = rules.map.campaign.adventure_opponent_lance
	setup.opponent_skill = rules.map.campaign.adventure_opponent_skill
	setup.host_province = host_province
	return setup


## The elector who invites the house to his tournament: the one who likes it most (the first
## in data order on a tie).
static func favourite_elector(state: GameState, rules: GameRules, house: String) -> String:
	var best := ""
	var best_favour := -1.0
	for id: String in rules.map.electors():
		var value := state.crown.favour_of(id, house)
		if value > best_favour:
			best = id
			best_favour = value
	return best


## What the player achieved live, else the computer's ride at the campaign's auto skill.
static func play_joust(state: GameState, rules: GameRules, setup: JoustSetup) -> JoustResult:
	var live := _live(rules, setup)
	if live is JoustResult:
		return live
	var skill := auto_skill(state, rules, setup.house)
	return JoustSim.play_out(rules.joust, setup, state.rng.randi(), skill)


## A tournament win brings prestige, the prize and the host's favour, and counts towards the
## leader's lance.
static func apply_joust(
	state: GameState, rules: GameRules, setup: JoustSetup, result: JoustResult
) -> void:
	var rider := state.houses[setup.house]
	rider.adventure_turn = state.turn
	if not result.won:
		return
	rider.pending_prestige += rules.economy.tournament_won_prestige
	rider.gold += rules.joust.prize_gold
	var favour: float = rules.map.crown.favour_changes["tournament_won"]
	CrownRules.change_favour(state, rules.map, setup.host_province, setup.house, favour)
	var campaign := rules.map.campaign
	rider.add_win("lance", campaign.leader_wins_per_point, campaign.leader_max)


## The bombardment the player shot live, else the computer crew's at the campaign's auto skill.
static func play_trebuchet(
	state: GameState, rules: GameRules, setup: TrebuchetSetup
) -> TrebuchetResult:
	var live := _live(rules, setup)
	if live is TrebuchetResult:
		return live
	var sim := TrebuchetSim.new(rules.siege, setup, state.rng.randi())
	var skill := auto_skill(state, rules, setup.attacker_house)
	return TrebuchetAimer.new(rules.siege, skill).play(sim)


## The leader and up to the allowed number of the strongest melee companies of the army he
## rides with lie in wait for the train.
static func merchant_setup(
	state: GameState, rules: GameRules, house: String, province: String
) -> MerchantSetup:
	var raider := state.houses[house]
	var setup := MerchantSetup.new()
	setup.house = house
	setup.blade = raider.blade
	setup.companies = _strongest(state, rules, raider, rules.merchant.max_companies)
	setup.escort_skill = rules.map.campaign.adventure_opponent_skill
	setup.province = province
	setup.season = state.season()
	setup.raider_skill = auto_skill(state, rules, house)
	return setup


## What the player achieved live, else the computer's run of the raid.
static func play_merchant(
	state: GameState, rules: GameRules, setup: MerchantSetup
) -> MerchantResult:
	var live := _live(rules, setup)
	if live is MerchantResult:
		return live
	var sim := MerchantSim.new(rules.merchant, rules.combat, setup, state.rng.randi())
	var ai := MerchantAI.new(rules.merchant, setup.raider_skill)
	while not sim.is_over():
		sim.step(ai.think(sim))
	return sim.result()


## The cargo of the stopped wagons; a captured leader forfeits it to the escort.
static func apply_merchant(state: GameState, house: String, result: MerchantResult) -> void:
	var raider := state.houses[house]
	raider.adventure_turn = state.turn
	raider.gold += result.taler
	if result.leader_captured:
		CampaignBattles.capture(raider, MERCHANT_CAPTOR)


static func _live(rules: GameRules, setup: RefCounted) -> RefCounted:
	if not rules.adventure_resolver.is_valid():
		return null
	return rules.adventure_resolver.call(setup)


## Unit ids of the house's best melee companies in the leader's army, strongest first.
static func _strongest(
	state: GameState, rules: GameRules, house: HouseState, count: int
) -> Array[String]:
	var units: Array[String] = []
	var army := state.army(house.leader_army)
	if army == null:
		return units
	for unit: String in army.units:
		if rules.combat.units[unit].melee > 0.0:
			units.append(unit)
	units.sort_custom(
		func(a: String, b: String) -> bool:
			return rules.combat.units[a].melee > rules.combat.units[b].melee
	)
	return units.slice(0, count)
