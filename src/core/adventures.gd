class_name Adventures
extends RefCounted
## The campaign side of the adventure minigames (GDD "Abenteuer-Module"): a house needs its
## leader free and has at most one adventure a round; the minigame is played live through
## GameRules.adventure_resolver or by the computer at the campaign's auto skill, and its
## result changes the game.

const MERCHANT_TRAIN := "merchant_train"
const ERROR_DONE := "ADVENTURE_DONE_THIS_ROUND"
const ERROR_LEADER_CAPTURED := "ADVENTURE_LEADER_CAPTURED"
## Captor of a leader whom a merchant train's escort took.
const MERCHANT_CAPTOR := "neutral"


## Why the house cannot start an adventure now; "" if it can.
static func error(state: GameState, house: String) -> String:
	var owner := state.houses[house]
	if owner.is_leader_captured():
		return ERROR_LEADER_CAPTURED
	return ERROR_DONE if owner.adventure_turn == state.turn else ""


## True for the adventures the campaign can start already.
static func supports(adventure: String) -> bool:
	return adventure == MERCHANT_TRAIN


## The minigame setup an event card's adventure starts, or null.
static func event_setup(
	state: GameState, rules: GameRules, card: EventState.EventCard, adventure: String
) -> RefCounted:
	match adventure:
		MERCHANT_TRAIN:
			return merchant_setup(state, rules, card.house, card.province)
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
	return false


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
	setup.raider_skill = rules.map.campaign.adventure_auto_skill
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
