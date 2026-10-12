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
	for army: ArmyState in armies:
		if turn.state.army(army.id) == null or turn.state.is_over():
			continue
		if turn.state.is_besieging(army):
			_siege(turn, army)
			continue
		for _i: int in MAX_STEPS:
			if turn.state.army(army.id) == null or army.moves_left <= 0:
				break
			if not _step(turn, army, leader, goals):
				break


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


## The only army at home stays while enemies within two steps outmatch the garrison alone;
## it may still strike an army that threatens the home.
static func must_guard(turn: AiTurn, army: ArmyState) -> bool:
	var state := turn.state
	var home := turn.owner().home_province
	if army.province != home:
		return false
	for other: ArmyState in state.armies_in(home):
		if other.owner == turn.house and other.id != army.id:
			return false
	var garrison := AiStrength.side_power(turn.rules, Garrisons.side(state, turn.rules, home))
	var wall := Garrisons.wall(state, turn.rules, home)
	garrison *= 1.0 + turn.rules.combat.castle_per_wall * wall
	var danger := AiStrength.threat(state, turn.rules, turn.house, home, 2)
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
	var chance := turn.cfg.success(Adventures.auto_skill(state, turn.rules, turn.house))
	var ransom := PayRansomCommand.ransom(state, turn.rules.economy, turn.house)
	var options: Array[AiOption] = []
	for castle: String in CastleRaids.castles(state, turn.rules, turn.house):
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
			return prestige + weights.get(CrownRules.REGALIA_TAG, 0.0) * turn.value("legitimacy")
	return prestige


## Attacker's strength over the defender's (the auto-resolve's K, counters and walls in).
static func _ratio(turn: AiTurn, setup: BattleSetup) -> float:
	if setup.defender.company_count() == 0 and not setup.defender.has_leader:
		return INF
	var k := AutoResolve.strengths(turn.rules.combat, setup)
	return k[0] / maxf(k[1], 0.001)
