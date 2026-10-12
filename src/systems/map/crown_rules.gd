class_name CrownRules
extends RefCounted
## Favour, votes, regalia and the coronation rule (GDD "Setting & Legitimität", "Wahlfürsten"):
## reads of the state plus the favour and ban changes every other rule goes through.

const ABSTAIN := ""
const REGALIA_TAG := "imperial_regalia"
const ELECTOR := "elector"
const NEUTRAL := "neutral"
const ERROR_NO_REGALIA := "CROWN_NO_REGALIA"
const ERROR_NO_SITE := "CROWN_NO_SITE"
const ERROR_NO_ARCHBISHOP := "CROWN_NO_ARCHBISHOP"
const ERROR_NOT_ENOUGH_VOTES := "CROWN_NOT_ENOUGH_VOTES"


## Electors and neutral secular lords keep favour lists; church land and houses do not.
static func keeps_favour(map: MapData, province_id: String) -> bool:
	var def: MapData.ProvinceDef = map.provinces.get(province_id)
	return def != null and (def.owner == ELECTOR or (def.owner == NEUTRAL and not def.is_church))


## Favour gains grow with the house's multiplier (Wittelsbacher diplomats), losses do not.
static func change_favour(
	state: GameState, map: MapData, province_id: String, house: String, amount: float
) -> void:
	if not state.crown.has_favour_list(province_id, house):
		return
	if amount > 0.0:
		amount *= map.crown.house_favour_multiplier.get(house, 1.0)
	var current := state.crown.favour_of(province_id, house)
	state.crown.set_favour(province_id, house, current + amount, map.crown.favour_max)


## Changes the house's favour with every elector except `spared`.
static func change_elector_favour(
	state: GameState, map: MapData, house: String, amount: float, spared: String = ""
) -> void:
	for id: String in map.electors():
		if id != spared:
			change_favour(state, map, id, house, amount)


## Each elector's vote: the occupier of his province, the house he promised his vote, or the
## house with the highest favour from the threshold on; ABSTAIN on a tie or below it. Church
## electors never vote for a banned house.
static func votes(state: GameState, map: MapData) -> Dictionary[String, String]:
	var result: Dictionary[String, String] = {}
	for id: String in map.electors():
		result[id] = _vote(state, map, id)
	return result


static func vote_count(state: GameState, map: MapData, house: String) -> int:
	return votes(state, map).values().count(house)


static func holds_true_regalia(state: GameState, house: String) -> bool:
	var province: ProvinceState = state.provinces.get(state.crown.regalia_province)
	return province != null and province.owner == house


## Regalia the house holds: "true", "forged", both or none.
static func regalia(state: GameState, house: String) -> Array[String]:
	var held: Array[String] = []
	if holds_true_regalia(state, house):
		held.append("true")
	if house in state.crown.forged_regalia:
		held.append("forged")
	return held


## True if the house holds a province with this coronation site tag.
static func holds_site(state: GameState, map: MapData, house: String, site: String) -> bool:
	for province: ProvinceState in state.provinces_of(house):
		if site in map.provinces[province.id].tags:
			return true
	return false


## The archbishop who crowns at the site is willing: favour from the minimum, or his province
## is the house's.
static func archbishop_willing(
	state: GameState, map: MapData, house: String, site: String
) -> bool:
	var id: String = map.crown.archbishops.get(site, "")
	if id.is_empty():
		return false
	if state.provinces[id].owner == house:
		return true
	return state.crown.favour_of(id, house) >= map.crown.archbishop_min_favour


## Site tag of the cheapest coronation the house may hold now; "" if none.
static func coronation_site(state: GameState, map: MapData, house: String) -> String:
	var votes_held := vote_count(state, map, house)
	var best := ""
	var fewest := 0
	for rule: CrownData.CoronationRule in map.crown.coronation:
		if not _meets(state, map, house, rule) or votes_held < rule.votes:
			continue
		if best.is_empty() or rule.votes < fewest:
			best = rule.site
			fewest = rule.votes
	return best


## Why the house cannot be crowned now, naming the first missing pillar; "" if it can.
static func coronation_error(state: GameState, map: MapData, house: String) -> String:
	if not coronation_site(state, map, house).is_empty():
		return ""
	var held := regalia(state, house)
	if held.is_empty():
		return ERROR_NO_REGALIA
	var has_site := false
	for site: String in map.crown.archbishops:
		if holds_site(state, map, house, site):
			has_site = true
			if archbishop_willing(state, map, house, site):
				return ERROR_NOT_ENOUGH_VOTES
	return ERROR_NO_ARCHBISHOP if has_site else ERROR_NO_SITE


## Votes the cheapest coronation the house could reach needs; 0 without regalia and site.
static func votes_needed(state: GameState, map: MapData, house: String) -> int:
	var fewest := 0
	for rule: CrownData.CoronationRule in map.crown.coronation:
		if _meets(state, map, house, rule) and (fewest == 0 or rule.votes < fewest):
			fewest = rule.votes
	return fewest


static func gift_cost(map: MapData, house: String) -> float:
	return map.crown.gift_cost * map.crown.house_gift_cost_multiplier.get(house, 1.0)


## Favour the next gift to this lord brings before the house multiplier: each gift this year
## brings less.
static func gift_favour(
	state: GameState, map: MapData, province_id: String, house: String
) -> float:
	var given: int = state.crown.gifts.get(CrownState.key(province_id, house), 0)
	return maxf(map.crown.gift_favour - map.crown.gift_repeat_penalty * given, 0.0)


## Taler a penance costs; the chapel of a high enough home castle halves them.
static func penance_gold(state: GameState, map: MapData, house: String) -> float:
	var crown := map.crown
	if state.home_castle_level(house) >= crown.chapel_home_castle:
		return crown.penance_gold * crown.chapel_gold_multiplier
	return crown.penance_gold


static func patron_of(map: MapData, house: String) -> String:
	return map.crown.camp_patrons[map.house_camps[house]]


## The church bans the house with this chance; state.rng decides.
static func risk_ban(state: GameState, house: String, chance: float) -> void:
	var target: HouseState = state.houses.get(house)
	if target != null and not target.is_banned and state.rng.randf() < chance:
		target.is_banned = true


## The lord pays homage: his province joins the house without a fight or occupation.
static func pay_homage(state: GameState, province_id: String, house: String) -> void:
	var province := state.provinces[province_id]
	province.owner = house
	province.occupied_rounds = 0
	province.in_revolt = false
	province.garrison_health = 1.0


## An army enters a province it does not hold: war against its lord costs his favour, and an
## attack on church land risks the ban.
static func attack(state: GameState, map: MapData, house: String, province_id: String) -> void:
	var province := state.provinces[province_id]
	if province.owner == house:
		return
	var def := map.provinces[province_id]
	if province.owner == def.owner:
		change_favour(state, map, province_id, house, map.crown.favour_changes["war"])
	if def.is_church:
		risk_ban(state, house, map.crown.ban_attack_church_chance)


## The house took an elector's province: his vote is forced, the other electors and the
## realm frown on it.
static func occupy(state: GameState, map: MapData, house: String, province_id: String) -> void:
	if map.provinces[province_id].owner != ELECTOR:
		return
	var others: float = map.crown.favour_changes["occupation_others"]
	change_elector_favour(state, map, house, others, province_id)
	state.houses[house].pending_prestige += map.crown.occupation_prestige


## The house beat an enemy army next to electors: they are grateful for the protection.
static func protect(state: GameState, map: MapData, house: String, province_id: String) -> void:
	for id: String in map.provinces[province_id].neighbors:
		if map.provinces[id].owner == ELECTOR:
			change_favour(state, map, id, house, map.crown.favour_changes["protection"])


## True while the house may not campaign after a penance.
static func is_doing_penance(state: GameState, house: String) -> bool:
	return state.turn < state.crown.penance_until.get(house, 0)


static func _vote(state: GameState, map: MapData, id: String) -> String:
	var occupier := state.provinces[id].owner
	if state.houses.has(occupier):
		return occupier
	var promised: String = state.crown.promised_votes.get(id, ABSTAIN)
	if state.houses.has(promised) and not state.houses[promised].is_eliminated:
		return promised
	var is_church := map.provinces[id].is_church
	var best := ABSTAIN
	var best_favour := -1.0
	var tied := false
	for house: HouseState in state.houses.values():
		if house.is_eliminated or (is_church and house.is_banned):
			continue
		var value := state.crown.favour_of(id, house.id)
		if value > best_favour:
			best = house.id
			best_favour = value
			tied = false
		elif value == best_favour:
			tied = true
	if tied or best_favour < map.crown.vote_threshold:
		return ABSTAIN
	return best


static func _meets(
	state: GameState, map: MapData, house: String, rule: CrownData.CoronationRule
) -> bool:
	return (
		rule.regalia in regalia(state, house)
		and holds_site(state, map, house, rule.site)
		and archbishop_willing(state, map, house, rule.site)
	)
