class_name CampaignRules
extends RefCounted
## Army, conquest, leader and victory values from the "campaign" section of data/map.json,
## with the formulas that only need these values (docs/design/map.md, "Armies").

const SKILLS: Array[String] = ["leadership", "lance", "blade"]
## Computer skill levels of the adventure minigames (0 sloppy … 3 veteran).
const ADVENTURE_SKILLS := 4

var max_rounds: int
var army_size_captain: int
var army_size_leader_base: int
var army_count_base: int
var army_count_castle_divisor: int
var moves: int
var summer_moves: int
var recovery_own: float
var recovery_foreign: float
var disband_health: float
var occupation_rounds: int
var garrison_unit: String
var garrison_population_divisor: float
var exile_rounds: int
var exile_min_castle_level: int
var leader_points: int
var leader_min: int
var leader_max: int
## Wins in one discipline that raise its skill by one point.
var leader_wins_per_point: int
## Skill that gets the house's bonus point; "" lets the seed pick one.
var leader_bonus: Dictionary[String, String] = {}
var legitimacy_tags: Dictionary[String, float] = {}
var legitimacy_forged_regalia: float
var legitimacy_per_vote: float
var legitimacy_per_province: float
var legitimacy_prestige_divisor: float
## Skill 0–3 of the computer playing a house's own side of an adventure it lets resolve itself,
## and of the computer opponents in adventures (escorts, guards, jousters) until the AI's
## difficulty levels exist (M7).
var adventure_auto_skill: int
var adventure_opponent_skill: int
## Lance of the champions a house meets at tournaments.
var adventure_opponent_lance: int


static func read(r: DataReader, data: Dictionary) -> CampaignRules:
	var rules := CampaignRules.new()
	rules.max_rounds = r.integer(data, "max_rounds")
	var adventures := r.object(data, "adventures")
	rules.adventure_auto_skill = r.integer(adventures, "auto_skill")
	rules.adventure_opponent_skill = r.integer(adventures, "opponent_skill")
	rules.adventure_opponent_lance = r.integer(adventures, "opponent_lance")
	rules.army_size_captain = r.integer(data, "army_size_captain")
	rules.army_size_leader_base = r.integer(data, "army_size_leader_base")
	rules.army_count_base = r.integer(data, "army_count_base")
	rules.army_count_castle_divisor = maxi(1, r.integer(data, "army_count_castle_divisor"))
	rules.moves = r.integer(data, "moves")
	rules.summer_moves = r.integer(data, "summer_moves")
	rules.recovery_own = r.number(data, "recovery_own")
	rules.recovery_foreign = r.number(data, "recovery_foreign")
	rules.disband_health = r.number(data, "disband_health")
	rules.occupation_rounds = r.integer(data, "occupation_rounds")
	rules.garrison_unit = r.text(data, "garrison_unit")
	rules.garrison_population_divisor = r.number(data, "garrison_population_divisor")
	rules.exile_rounds = r.integer(data, "exile_rounds")
	rules.exile_min_castle_level = r.integer(data, "exile_min_castle_level")
	var leader := r.object(data, "leader")
	rules.leader_points = r.integer(leader, "points")
	rules.leader_min = r.integer(leader, "min")
	rules.leader_max = r.integer(leader, "max")
	rules.leader_wins_per_point = r.integer(leader, "wins_per_point")
	var bonus := r.object(leader, "house_bonus")
	for house: String in bonus:
		rules.leader_bonus[house] = r.text(bonus, house)
	var legitimacy := r.object(data, "legitimacy")
	var tags := r.object(legitimacy, "tags")
	for tag: String in tags:
		rules.legitimacy_tags[tag] = r.number(tags, tag)
	rules.legitimacy_forged_regalia = r.number(legitimacy, "forged_regalia")
	rules.legitimacy_per_vote = r.number(legitimacy, "per_vote")
	rules.legitimacy_per_province = r.number(legitimacy, "per_province")
	rules.legitimacy_prestige_divisor = r.number(legitimacy, "prestige_divisor")
	rules._check(r)
	return rules


func max_armies(home_castle_level: int) -> int:
	@warning_ignore("integer_division")
	return army_count_base + home_castle_level / army_count_castle_divisor


func max_companies(has_leader: bool, leadership: int) -> int:
	return army_size_leader_base + leadership if has_leader else army_size_captain


func moves_per_round(is_summer: bool) -> int:
	return summer_moves if is_summer else moves


## Share of full HP a company regains per round.
func recovery(is_own_province: bool) -> float:
	return recovery_own if is_own_province else recovery_foreign


## Levy companies defending a province that belongs to no house; fixed_size > 0 overrides.
func neutral_garrison(population: float, fixed_size: int) -> int:
	if fixed_size > 0:
		return fixed_size
	return ceili(population / garrison_population_divisor)


## Skills of a new leader: each starts at the minimum, the house bonus adds one point and
## the seed spreads the rest without exceeding the maximum.
func roll_leader(house: String, rng: RandomNumberGenerator) -> Dictionary[String, int]:
	var skills: Dictionary[String, int] = {}
	for skill: String in SKILLS:
		skills[skill] = leader_min
	var bonus: String = leader_bonus.get(house, "")
	if bonus.is_empty():
		bonus = SKILLS[rng.randi_range(0, SKILLS.size() - 1)]
	skills[bonus] += 1
	var spare := leader_points - leader_min * SKILLS.size() - 1
	for _i: int in spare:
		var open: Array[String] = []
		for skill: String in SKILLS:
			if skills[skill] < leader_max:
				open.append(skill)
		skills[open[rng.randi_range(0, open.size() - 1)]] += 1
	return skills


## L = Σ tag weights of held provinces + forged regalia + per_vote · S + per_province · P
## + A / prestige_divisor.
func legitimacy(
	held_tags: Array[String],
	province_count: int,
	prestige: float,
	has_forged_regalia: bool = false,
	secure_votes: int = 0
) -> float:
	var total := legitimacy_per_province * province_count + prestige / legitimacy_prestige_divisor
	total += legitimacy_per_vote * secure_votes
	if has_forged_regalia:
		total += legitimacy_forged_regalia
	for tag: String in held_tags:
		total += legitimacy_tags.get(tag, 0.0)
	return total


func _check(r: DataReader) -> void:
	for skill: int in [adventure_auto_skill, adventure_opponent_skill]:
		if skill < 0 or skill >= ADVENTURE_SKILLS:
			r.errors.append("campaign.adventures: skill %d outside 0–3" % skill)
	for house: String in leader_bonus:
		var skill := leader_bonus[house]
		if not skill.is_empty() and skill not in SKILLS:
			r.errors.append("campaign.leader.house_bonus.%s: unknown skill '%s'" % [house, skill])
	var spare := leader_points - leader_min * SKILLS.size() - 1
	if spare < 0 or spare > (leader_max - leader_min) * SKILLS.size() - 1:
		r.errors.append("campaign.leader: points do not fit min and max")
