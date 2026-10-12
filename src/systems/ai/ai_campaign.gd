class_name AiCampaign
extends RefCounted
## Decision level 4, opportunity (GDD), in the campaign phase: a castle raid when it pays,
## then each army storms or bombards the castle it besieges, attacks where its strength reaches
## the attack ratio (counters included, the auto-resolve's K), or marches towards the pillars
## of the crown. A house holding two pillars draws everyone's attacks (anti-leader); an emperor
## spares the others meanwhile (coalition).

const MAX_STEPS := 3


static func run(turn: AiTurn) -> void:
	_raid(turn)
	var leader := AiStrength.leader(turn.state, turn.rules, int(turn.cfg.anti_leader["pillars"]))
	var goals := AiTargets.goals(turn, leader)
	var armies := turn.state.armies_of(turn.house)
	var rescue := _rescues(turn, armies)
	for army: ArmyState in armies:
		if turn.state.army(army.id) == null or turn.state.is_over():
			continue
		if rescue.has(army.id):
			_march(turn, army, rescue[army.id])
			continue
		if is_home_guard(turn, army):
			continue
		if turn.state.is_besieging(army):
			_siege(turn, army)
			continue
		for _i: int in MAX_STEPS:
			if turn.state.army(army.id) == null or army.moves_left <= 0:
				break
			if not _step(turn, army, leader, goals):
				break


## A small army at home that is not the leader's: it stays to hold the castle.
static func is_home_guard(turn: AiTurn, army: ArmyState) -> bool:
	var owner := turn.owner()
	return (
		army.province == owner.home_province
		and army.id != owner.leader_army
		and army.company_count() <= int(turn.cfg.security["home_guard_companies"])
	)


## For every threatened key province without an own army, the nearest free army marches there
## before anything else: army id → province.
static func _rescues(turn: AiTurn, armies: Array[ArmyState]) -> Dictionary[int, String]:
	var result: Dictionary[int, String] = {}
	var state := turn.state
	for key: String in AiTargets.keys(turn):
		var guarded := false
		for army: ArmyState in armies:
			guarded = guarded or army.province == key
		if guarded:
			continue
		var threat := turn.threat(key)
		var defense := AiStrength.defense(state, turn.rules, turn.house, key)
		if threat * turn.cfg.security["threat_ratio"] <= defense:
			continue
		var steps := AiTargets.distances(turn.rules.map, key)
		var nearest: ArmyState = null
		for army: ArmyState in armies:
			if result.has(army.id):
				continue
			if nearest == null or steps[army.province] < steps[nearest.province]:
				nearest = army
		if nearest != null:
			result[nearest.id] = key
	return result


static func _march(turn: AiTurn, army: ArmyState, target: String) -> void:
	var steps := AiTargets.distances(turn.rules.map, target)
	for _i: int in MAX_STEPS:
		if turn.state.army(army.id) == null or army.moves_left <= 0 or army.province == target:
			return
		var best := ""
		for neighbor: String in turn.rules.map.provinces[army.province].neighbors:
			var move := MoveArmyCommand.new(turn.rules, turn.house, army.id, neighbor)
			if steps[neighbor] < steps[army.province] and move.validate(turn.state).is_empty():
				best = neighbor
				break
		if best.is_empty():
			return
		var move := MoveArmyCommand.new(turn.rules, turn.house, army.id, best)
		if not turn.act(move, "%d to defend %s" % [army.id, target], turn.value("province")):
			return


## Storm when strong enough behind the walls, else bombard with trebuchets, else starve.
static func _siege(turn: AiTurn, army: ArmyState) -> void:
	var storm := StormCommand.new(turn.rules, turn.house, army.id)
	var setup := storm.battle_setup(turn.state)
	if setup != null and _ratio(turn, setup) >= turn.cfg.opportunity["storm_ratio"]:
		turn.act(storm, "storm " + army.province, _ratio(turn, setup))
		return
	var bombard := TrebuchetCommand.new(turn.rules, turn.house, army.id)
	if bombard.validate(turn.state).is_empty():
		turn.act(bombard, "bombard " + army.province, turn.weight("military"))


## The only army in a key province (home, true regalia, coronation site) stays while enemies
## near it (data: two steps away and lone home guards count partly) outmatch its garrison
## alone; it may still strike an army that threatens it.
static func must_guard(turn: AiTurn, army: ArmyState) -> bool:
	var state := turn.state
	var key := army.province
	if key not in AiTargets.keys(turn):
		return false
	for other: ArmyState in state.armies_in(key):
		if other.owner == turn.house and other.id != army.id:
			return false
	var garrison := AiStrength.side_power(turn.rules, Garrisons.side(state, turn.rules, key))
	var wall := Garrisons.wall(state, turn.rules, key)
	garrison *= 1.0 + turn.rules.combat.castle_per_wall * wall
	var danger := turn.threat(key, true)
	return danger * turn.cfg.security["threat_ratio"] > garrison


## One move of the army: the best target the rules allow, or staying put.
static func _step(
	turn: AiTurn, army: ArmyState, leader: String, goals: Dictionary[String, float]
) -> bool:
	var guarding := must_guard(turn, army)
	var options: Array[AiOption] = []
	var pull := AiTargets.pull(turn, goals)
	var here: float = pull.get(army.province, 0.0)
	for neighbor: String in turn.rules.map.provinces[army.province].neighbors:
		var move := MoveArmyCommand.new(turn.rules, turn.house, army.id, neighbor)
		if not move.validate(turn.state).is_empty():
			continue
		var worth := 0.0
		var setup := move.battle_setup(turn.state)
		var strikes_army := Movement.has_hostile_army(turn.state, neighbor, turn.house)
		if guarding and (setup == null or not strikes_army):
			continue
		if setup != null:
			if _ratio(turn, setup) < turn.cfg.opportunity["attack_ratio"]:
				continue
			worth += AiTargets.conquest_worth(turn, neighbor, leader)
		elif turn.state.provinces[neighbor].owner != turn.house:
			if not _can_besiege(turn, army, neighbor):
				continue
			worth += AiTargets.conquest_worth(turn, neighbor, leader)
		worth += pull.get(neighbor, 0.0) - here
		worth += AiTargets.defense_worth(turn, army, neighbor)
		if worth > 0.0:
			options.append(AiOption.create("%d to %s" % [army.id, neighbor], worth, move))
	var pick := turn.choose(options)
	return pick != null and turn.act(pick.command, pick.label, pick.utility)


## The leader steals into a castle when the expected loot outweighs the risk of capture.
static func _raid(turn: AiTurn) -> void:
	var state := turn.state
	if not Adventures.error(state, turn.house).is_empty():
		return
	var skill := Adventures.auto_skill(state, turn.rules, turn.house)
	var ransom := PayRansomCommand.ransom(state, turn.rules.economy, turn.house)
	var options: Array[AiOption] = []
	for castle: String in CastleRaids.castles(state, turn.rules, turn.house):
		var guards := CastleRaids.guard_skill(turn.rules, state.provinces[castle].castle_level)
		var chance := turn.cfg.success(skill - maxi(guards - 1, 0))
		for target: String in CastleRaids.targets(state, castle):
			var prize := _raid_prize(turn, castle, target)
			var worth := chance * prize - (1.0 - chance) * ransom * 0.5
			if turn.rules.map.provinces[castle].is_church:
				worth -= turn.rules.map.crown.ban_raid_church_chance * turn.value("vote")
			worth *= turn.weight("adventure")
			if worth >= turn.cfg.opportunity["raid_min_loot"]:
				var command := CastleRaidCommand.new(turn.rules, turn.house, castle, target)
				options.append(AiOption.create("raid %s %s" % [castle, target], worth, command))
	var pick := turn.choose(options)
	if pick != null:
		turn.act(pick.command, pick.label, pick.utility)


static func _raid_prize(turn: AiTurn, castle: String, target: String) -> float:
	var victim: HouseState = turn.state.houses.get(turn.state.provinces[castle].owner)
	var prestige := turn.rules.raid.prestige(target) * turn.value("prestige") * 4.0
	match target:
		CastleRaids.TREASURY:
			return prestige + turn.rules.raid.treasury_loot(int(maxf(victim.gold, 0.0)))
		CastleRaids.GRANARY:
			return prestige + turn.rules.raid.granary_loss(victim.grain) * 0.4
		CastleRaids.REGALIA:
			var weights := turn.rules.map.campaign.legitimacy_tags
			var gain: float = weights.get(CrownRules.REGALIA_TAG, 0.0)
			gain -= turn.rules.map.campaign.legitimacy_forged_regalia
			return prestige + gain * turn.value("legitimacy") + turn.pillar_worth() / 4.0
	return prestige


## A siege raises the army's upkeep; the treasury must carry it through the coming settlement.
static func _can_besiege(turn: AiTurn, army: ArmyState, province_id: String) -> bool:
	var state := turn.state
	if state.provinces[province_id].castle_level == 0:
		return true
	var cfg := turn.rules.economy
	var extra := IncomeRules.unit_upkeep(cfg, army.units) * (cfg.siege_upkeep_multiplier - 1.0)
	var change := EconomyTerm.sum(
		EconomyBreakdown.gold_change(state, turn.rules.map, cfg, turn.house)
	)
	return turn.owner().gold + change - extra >= 0.0


## Attacker's strength over the defender's (the auto-resolve's K, counters and walls in).
static func _ratio(turn: AiTurn, setup: BattleSetup) -> float:
	if setup.defender.company_count() == 0 and not setup.defender.has_leader:
		return INF
	var k := AutoResolve.strengths(turn.rules.combat, setup)
	return k[0] / maxf(k[1], 0.001)
