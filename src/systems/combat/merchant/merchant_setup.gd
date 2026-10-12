class_name MerchantSetup
extends RefCounted
## What the campaign passes into a merchant train raid; MerchantSim answers with a
## MerchantResult. Prestige and Cologne's favour for the raid stay with the event card.

const MIN_BLADE := 1
const MAX_BLADE := 5

## House of the raiding leader: colours and crest.
var house: String = "welfen"
## The leader's blade: strike damage and parry window (data/combat.json leader_skills).
var blade: int = 2
## Unit ids of the companies from the leader's army that lie in ambush, at most companies.max.
var companies: Array[String] = []
## Escort pattern 0 (sloppy) … 3 (veterans).
var escort_skill: int = 1
## Escort soldiers; 0 takes the count of the escort skill.
var escort_count: int = 0
## Province of the event (a river province): scenery and the town at the gate.
var province: String = "KOE"
## GameState.Season; the event comes in spring (0) or summer (1).
var season: int = 1
## Skill 0–3 of the computer raider when no device plays the leader.
var raider_skill: int = 1
## Practice from the menu: the scene offers retry and quit instead of continue.
var practice: bool = false


## Problems of this setup; MerchantSim reports them and plays a clamped copy.
func errors(cfg: MerchantConfig, combat: CombatConfig) -> PackedStringArray:
	var problems := PackedStringArray()
	if blade < MIN_BLADE or blade > MAX_BLADE:
		problems.append("blade %d outside %d–%d" % [blade, MIN_BLADE, MAX_BLADE])
	if companies.size() > cfg.max_companies:
		problems.append("%d companies, at most %d" % [companies.size(), cfg.max_companies])
	for unit: String in companies:
		if not combat.units.has(unit):
			problems.append("unknown unit '%s'" % unit)
		elif unit == "leader" or combat.units[unit].melee <= 0.0:
			problems.append("unit '%s' cannot raid a train" % unit)
	if escort_skill < 0 or escort_skill >= MerchantConfig.SKILLS:
		problems.append("escort skill %d outside 0–%d" % [escort_skill, MerchantConfig.SKILLS - 1])
	if escort_count != 0 and (
		escort_count < cfg.min_escorts() or escort_count > cfg.max_escorts()
	):
		problems.append(
			"%d escorts outside %d–%d" % [escort_count, cfg.min_escorts(), cfg.max_escorts()]
		)
	if raider_skill < 0 or raider_skill >= MerchantConfig.SKILLS:
		problems.append("raider skill %d outside 0–%d" % [raider_skill, MerchantConfig.SKILLS - 1])
	return problems


## A copy the simulation can play: values clamped, unusable companies dropped.
func playable(cfg: MerchantConfig, combat: CombatConfig) -> MerchantSetup:
	var copy := MerchantSetup.new()
	copy.house = house
	copy.blade = clampi(blade, MIN_BLADE, MAX_BLADE)
	for unit: String in companies:
		var usable := combat.units.has(unit) and unit != "leader"
		if usable and combat.units[unit].melee > 0.0 and copy.companies.size() < cfg.max_companies:
			copy.companies.append(unit)
	copy.escort_skill = clampi(escort_skill, 0, MerchantConfig.SKILLS - 1)
	copy.escort_count = cfg.escort_skill(copy.escort_skill).count
	if escort_count != 0:
		copy.escort_count = clampi(escort_count, cfg.min_escorts(), cfg.max_escorts())
	copy.province = province
	copy.season = season
	copy.raider_skill = clampi(raider_skill, 0, MerchantConfig.SKILLS - 1)
	copy.practice = practice
	return copy
