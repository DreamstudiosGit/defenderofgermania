class_name AiEvents
extends RefCounted
## A computer house answers its event cards: every choice the rules accept is valued in taler
## — its cost, gold, prestige, satisfaction, favour, votes and provinces — and battles and
## adventures by the chance they go well; the best (or, for a squire, sometimes a worse) wins.


static func answer(turn: AiTurn) -> void:
	var guard := 0
	while turn.state.phase == GameState.Phase.EVENT and guard < 4:
		guard += 1
		var card := turn.state.events.next_pending()
		if card == null:
			return
		var options: Array[AiOption] = []
		for choice: EventData.ChoiceDef in turn.rules.events.events[card.event].choices:
			var command := ChooseEventCommand.new(turn.rules, turn.house, choice.id)
			var worth := _worth(turn, card, choice)
			options.append(AiOption.create("%s: %s" % [card.event, choice.id], worth, command))
		var pick := turn.choose(options)
		if pick == null or not turn.act(pick.command, pick.label, pick.utility):
			return


static func _worth(turn: AiTurn, card: EventState.EventCard, choice: EventData.ChoiceDef) -> float:
	var worth := -choice.cost
	for effect: EventData.EffectDef in choice.effects:
		worth += _effect_worth(turn, effect)
	var battle := EventBattles.battle_of(choice)
	var adventure := EventEffects.adventure_of(choice)
	var chance := 1.0
	if battle != null:
		chance = _battle_chance(turn, card, battle)
		if battle.target == EventBattles.DEFEND:
			worth -= (1.0 - chance) * turn.value("province") * 2.0
	elif not adventure.is_empty():
		chance = turn.cfg.success(Adventures.auto_skill(turn.state, turn.rules, turn.house))
		worth += chance * _adventure_prize(turn, adventure) * turn.weight("adventure")
	for effect: EventData.EffectDef in choice.victory:
		worth += chance * _effect_worth(turn, effect)
	return worth


static func _effect_worth(turn: AiTurn, effect: EventData.EffectDef) -> float:
	match effect.type:
		"gold":
			return effect.amount
		"prestige":
			return effect.amount * turn.value("prestige") * 4.0
		"satisfaction":
			return effect.amount * turn.value("satisfaction") * 3.0
		"favour":
			var lords := maxf(turn.rules.events.lords(effect.target).size(), 1.0)
			return effect.amount * lords * turn.value("favour") * turn.weight("favour")
		"secure_vote":
			return turn.value("vote")
		"homage":
			return turn.value("province") * 3.0
		"send_units":
			var unit := turn.rules.economy.units[effect.unit]
			return -effect.amount * (unit.cost * 0.6 + unit.upkeep_gold * effect.rounds * 0.3)
	return 0.0


static func _battle_chance(
	turn: AiTurn, card: EventState.EventCard, battle: EventData.EffectDef
) -> float:
	var band := BattleSide.new()
	band.owner = EventBattles.BAND_OWNER
	for _i: int in int(battle.amount):
		band.add_company(battle.unit)
	var own := 0.0
	if battle.target == EventBattles.HUNT:
		var hunter := EventBattles.hunter(turn.state, turn.rules, card)
		if hunter == null:
			return 0.0
		own = AiStrength.army_power(turn.state, turn.rules, hunter)
	else:
		own = AiStrength.defense(turn.state, turn.rules, turn.house, card.province)
	var theirs := AiStrength.side_power(turn.rules, band)
	return AutoResolve.win_chance(turn.rules.combat, own, theirs)


## What a successful adventure from a card brings.
static func _adventure_prize(turn: AiTurn, adventure: String) -> float:
	match adventure:
		Adventures.JOUST:
			var prestige := turn.rules.economy.tournament_won_prestige * turn.value("prestige")
			return turn.rules.joust.prize_gold + prestige * 4.0 + 5.0 * turn.value("favour")
		Adventures.MERCHANT_TRAIN:
			return 150.0
		Adventures.CASTLE_RAID:
			return 3.0 * turn.value("prestige") * 4.0 + 40.0
	return 0.0
