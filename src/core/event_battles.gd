class_name EventBattles
extends RefCounted
## Battles event cards start: the house hunts a band next to one of its provinces with its
## largest army there or next door, or a neutral count's band attacks the province (feud) and
## takes it over unless it holds.

const HUNT := "hunt"
const DEFEND := "defend"
const BAND_OWNER := "neutral"
const ERROR_NO_ARMY := "EVENT_NO_ARMY"


## The choice's battle effect, or null when it fights none.
static func battle_of(choice: EventData.ChoiceDef) -> EventData.EffectDef:
	for effect: EventData.EffectDef in choice.effects:
		if effect.type == "battle":
			return effect
	return null


## Why the choice's battle cannot be fought; "" if it can or fights none.
static func error(
	state: GameState, rules: GameRules, card: EventState.EventCard, choice: EventData.ChoiceDef
) -> String:
	var effect := battle_of(choice)
	if effect != null and effect.target == HUNT and hunter(state, rules, card) == null:
		return ERROR_NO_ARMY
	return ""


## Fights the choice's battle; true if the house won it.
static func fight(
	state: GameState, rules: GameRules, card: EventState.EventCard, choice: EventData.ChoiceDef
) -> bool:
	var effect := battle_of(choice)
	var band := BattleSide.new()
	band.owner = BAND_OWNER
	for _i: int in int(effect.amount):
		band.add_company(effect.unit)
	if effect.target == HUNT:
		var army := hunter(state, rules, card)
		return CampaignBattles.fight_band(state, rules, army, band, card.province)
	var defender := _largest(state.armies_in(card.province), card.house)
	if CampaignBattles.defend_against_band(state, rules, band, card.province, defender):
		return true
	Conquest.to_neutral(state.provinces[card.province])
	return false


## The house's largest army in the card's province or next to it; null without one.
static func hunter(state: GameState, rules: GameRules, card: EventState.EventCard) -> ArmyState:
	var armies := state.armies_in(card.province)
	for id: String in rules.map.provinces[card.province].neighbors:
		armies.append_array(state.armies_in(id))
	return _largest(armies, card.house)


static func _largest(armies: Array[ArmyState], house: String) -> ArmyState:
	var best: ArmyState = null
	for army: ArmyState in armies:
		if army.owner == house and (best == null or army.company_count() > best.company_count()):
			best = army
	return best
