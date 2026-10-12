class_name CrownData
extends RefCounted
## The road to the crown from the "crown" section of data/map.json: favour, the coronation
## table, homage, patron cards and the church ban (GDD "Setting & Legitimität",
## "Wahlfürsten"). Start favour lists sit on the provinces (MapData.ProvinceDef.start_favour).

const REGALIA: Array[String] = ["true", "forged"]
const FAVOUR_CHANGES: Array[String] = [
	"tournament_hosted", "tournament_won", "protection", "imperial_palace", "war",
	"occupation_others",
]

## Patron power of each camp, e.g. north → england.
var camp_patrons: Dictionary[String, String] = {}
var favour_default: float
var favour_max: float
var vote_threshold: float
var favour_prestige_divisor: float
var favour_drift_to: float
var favour_drift_per_round: float
var house_favour_multiplier: Dictionary[String, float] = {}
var gift_cost: float
var gift_favour: float
## Each further gift to the same lord within a year gains this much less.
var gift_repeat_penalty: float
var house_gift_cost_multiplier: Dictionary[String, float] = {}
var favour_changes: Dictionary[String, float] = {}
var imperial_palace_home_castle: int
var occupation_prestige: float
## Coronation site tag → province of the archbishop who crowns there.
var archbishops: Dictionary[String, String] = {}
var archbishop_min_favour: float
var coronation: Array[CoronationRule] = []
var forged_regalia_cost: float
var forged_regalia_rounds: int
var forged_regalia_home_castle: int
var homage_threshold: float
var homage_cost: float
var patron_cards: int
var patron_cards_per_round: int
var patron_silver: float
var patron_embassy_favour: float
var patron_mercenary_unit: String
var patron_mercenary_companies: int
var ban_attack_church_chance: float
var ban_raid_church_chance: float
var penance_gold: float
var penance_prestige: float
var penance_campaign_rounds: int
var chapel_home_castle: int
var chapel_gold_multiplier: float


class CoronationRule:
	var regalia: String
	var site: String
	var votes: int


static func read(r: DataReader, data: Dictionary) -> CrownData:
	var crown := CrownData.new()
	r.context = "crown"
	var camps := r.object(data, "camps")
	for camp: String in camps:
		crown.camp_patrons[camp] = r.text(camps, camp)
	crown._read_favour(r, r.object(data, "favour"))
	r.context = "crown"
	crown._read_coronation(r, r.object(data, "coronation"))
	r.context = "crown"
	var homage := r.object(data, "homage")
	var patrons := r.object(data, "patrons")
	var ban := r.object(data, "ban")
	r.context = "crown.homage"
	crown.homage_threshold = r.number(homage, "threshold")
	crown.homage_cost = r.number(homage, "cost")
	r.context = "crown.patrons"
	crown.patron_cards = r.integer(patrons, "cards")
	crown.patron_cards_per_round = r.integer(patrons, "per_round")
	crown.patron_silver = r.number(patrons, "silver")
	crown.patron_embassy_favour = r.number(patrons, "embassy")
	var mercenaries := r.object(patrons, "mercenaries")
	crown.patron_mercenary_unit = r.text(mercenaries, "unit")
	crown.patron_mercenary_companies = r.integer(mercenaries, "companies")
	crown._read_ban(r, ban)
	r.context = "crown"
	crown._check(r)
	r.context = ""
	return crown


## Electors' votes a coronation needs with these regalia ("true" or "forged") at this
## coronation site tag; 0 when the table has no such row.
func votes_needed(regalia: String, site: String) -> int:
	for rule: CoronationRule in coronation:
		if rule.regalia == regalia and rule.site == site:
			return rule.votes
	return 0


func _read_favour(r: DataReader, data: Dictionary) -> void:
	r.context = "crown.favour"
	favour_default = r.number(data, "default")
	favour_max = r.number(data, "max")
	vote_threshold = r.number(data, "vote_threshold")
	favour_prestige_divisor = r.number(data, "prestige_divisor")
	favour_drift_to = r.number(data, "drift_to")
	favour_drift_per_round = r.number(data, "drift_per_round")
	house_favour_multiplier = _house_values(r, data, "house_multiplier")
	imperial_palace_home_castle = r.integer(data, "imperial_palace_home_castle")
	occupation_prestige = r.number(data, "occupation_prestige")
	var changes := r.object(data, "changes")
	var gift := r.object(data, "gift")
	r.context = "crown.favour.changes"
	for change: String in FAVOUR_CHANGES:
		favour_changes[change] = r.number(changes, change)
	for change: String in changes:
		if change not in FAVOUR_CHANGES:
			r.errors.append("%s: unknown change '%s'" % [r.context, change])
	r.context = "crown.favour.gift"
	gift_cost = r.number(gift, "cost")
	gift_favour = r.number(gift, "favour")
	gift_repeat_penalty = r.number(gift, "repeat_penalty")
	house_gift_cost_multiplier = _house_values(r, gift, "house_cost_multiplier")


func _read_coronation(r: DataReader, data: Dictionary) -> void:
	r.context = "crown.coronation"
	var sites := r.object(data, "archbishops")
	for site: String in sites:
		archbishops[site] = r.text(sites, site)
	archbishop_min_favour = r.number(data, "archbishop_min_favour")
	var rules := r.list(data, "rules")
	var forged := r.object(data, "forged_regalia")
	for item: Variant in rules:
		if not item is Dictionary:
			r.errors.append("%s.rules: expected objects" % r.context)
			continue
		var entry: Dictionary = item
		var rule := CoronationRule.new()
		rule.regalia = r.text(entry, "regalia")
		rule.site = r.text(entry, "site")
		rule.votes = r.integer(entry, "votes")
		coronation.append(rule)
	r.context = "crown.coronation.forged_regalia"
	forged_regalia_cost = r.number(forged, "cost")
	forged_regalia_rounds = r.integer(forged, "build_rounds")
	forged_regalia_home_castle = r.integer(forged, "home_castle")


func _read_ban(r: DataReader, data: Dictionary) -> void:
	r.context = "crown.ban"
	ban_attack_church_chance = r.number(data, "attack_church_chance")
	ban_raid_church_chance = r.number(data, "raid_church_chance")
	var penance := r.object(data, "penance")
	r.context = "crown.ban.penance"
	penance_gold = r.number(penance, "gold")
	penance_prestige = r.number(penance, "prestige")
	penance_campaign_rounds = r.integer(penance, "campaign_rounds")
	chapel_home_castle = r.integer(penance, "chapel_home_castle")
	chapel_gold_multiplier = r.number(penance, "chapel_gold_multiplier")


func _house_values(r: DataReader, data: Dictionary, key: String) -> Dictionary[String, float]:
	var values: Dictionary[String, float] = {}
	var entry := r.object(data, key, false)
	for house: String in entry:
		values[house] = r.number(entry, house)
	return values


func _check(r: DataReader) -> void:
	for camp: String in camp_patrons:
		if camp_patrons[camp].is_empty():
			r.errors.append("crown.camps.%s: missing patron" % camp)
	var bounded: Dictionary[String, float] = {
		"favour.default": favour_default,
		"favour.drift_to": favour_drift_to,
		"favour.vote_threshold": vote_threshold,
		"coronation.archbishop_min_favour": archbishop_min_favour,
		"homage.threshold": homage_threshold,
	}
	for key: String in bounded:
		if bounded[key] < 0.0 or bounded[key] > favour_max:
			r.errors.append("crown.%s: outside 0–%s" % [key, favour_max])
	var pairs: Array[String] = []
	for rule: CoronationRule in coronation:
		var pair := "%s at %s" % [rule.regalia, rule.site]
		if rule.regalia not in REGALIA:
			r.errors.append("crown.coronation: unknown regalia '%s'" % rule.regalia)
		if not archbishops.has(rule.site):
			r.errors.append("crown.coronation: no archbishop for site '%s'" % rule.site)
		if rule.votes <= 0:
			r.errors.append("crown.coronation: %s needs at least one vote" % pair)
		if pair in pairs:
			r.errors.append("crown.coronation: %s listed twice" % pair)
		pairs.append(pair)
	if pairs.size() != REGALIA.size() * archbishops.size():
		r.errors.append("crown.coronation: needs one rule per regalia and site")
