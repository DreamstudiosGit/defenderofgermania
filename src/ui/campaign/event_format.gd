class_name EventFormat
extends RefCounted
## Texts of event cards (keys EVENT_<ID>_TITLE/_TEXT/_CHOICE_<CHOICE>): where a card happens,
## what a choice costs and does, and how an answered card turned out.


static func title(event_id: String) -> String:
	return CampaignFormat.t(_key(event_id) + "_TITLE")


static func text(event_id: String) -> String:
	return CampaignFormat.t(_key(event_id) + "_TEXT")


static func choice_label(event_id: String, choice_id: String) -> String:
	return CampaignFormat.t("%s_CHOICE_%s" % [_key(event_id), choice_id.to_upper()])


## Province, region or house the card concerns; "" for the whole realm.
static func place(card: EventState.EventCard) -> String:
	if not card.province.is_empty():
		return CampaignFormat.province_name(card.province)
	if not card.region.is_empty():
		return CampaignFormat.t("CAMPAIGN_REGION_" + card.region.to_upper())
	return CampaignFormat.house_name(card.house) if not card.house.is_empty() else ""


## The answer given on a card and, after a battle, whether it was won; "" while open.
static func outcome(card: EventState.EventCard, events: EventData) -> String:
	if card.choice.is_empty():
		return ""
	var line := CampaignFormat.t("CAMPAIGN_EVENTS_CHOSE") % choice_label(card.event, card.choice)
	var choice := events.events[card.event].choice(card.choice)
	if choice != null and EventBattles.battle_of(choice) != null:
		line += " " + CampaignFormat.t("CAMPAIGN_EVENTS_WON" if card.won else "CAMPAIGN_EVENTS_LOST")
	return line


## Cost, effects and the reward of a victory, one line each.
static func choice_lines(choice: EventData.ChoiceDef) -> PackedStringArray:
	var lines := PackedStringArray()
	if choice.cost > 0.0:
		lines.append(CampaignFormat.t("EVENT_EFFECT_COST") % CampaignFormat.number(choice.cost))
	for effect: EventData.EffectDef in choice.effects:
		lines.append(effect_line(effect))
	for effect: EventData.EffectDef in choice.victory:
		lines.append(CampaignFormat.t("EVENT_EFFECT_VICTORY") % effect_line(effect))
	if lines.is_empty():
		lines.append(CampaignFormat.t("EVENT_EFFECT_NOTHING"))
	return lines


static func effect_line(effect: EventData.EffectDef) -> String:
	var amount := effect.amount
	match effect.type:
		"grain", "grain_demand", "harvest", "population":
			return _t(effect, CampaignFormat.signed(amount * 100.0, 0))
		"satisfaction", "prestige", "gold", "favour":
			return _t(effect, CampaignFormat.signed(amount, 0), _lords(effect.target))
		"ban_chance":
			return _t(effect, CampaignFormat.percent(amount))
		"no_passage":
			return _t(effect, str(effect.rounds))
		"battle":
			var key := "EVENT_EFFECT_BATTLE_" + effect.target.to_upper()
			return CampaignFormat.t(key) % [int(amount), CampaignFormat.unit_name(effect.unit)]
		"adventure":
			return _t(effect, CampaignFormat.t("EVENT_ADVENTURE_" + effect.target.to_upper()))
		"homage", "secure_vote":
			return _t(effect, CampaignFormat.province_name(effect.target))
		"send_units":
			return CampaignFormat.t("EVENT_EFFECT_SEND_UNITS") % [
				int(amount), CampaignFormat.unit_name(effect.unit), effect.rounds
			]
		"patron_strength":
			return _t(effect, CampaignFormat.t("PATRON_" + effect.target.to_upper()))
	return CampaignFormat.t("EVENT_EFFECT_" + effect.type.to_upper())


## News of the round, one entry per event with every place it struck.
static func grouped(news: Array[EventState.EventCard]) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var by_event: Dictionary[String, Dictionary] = {}
	for card: EventState.EventCard in news:
		if not by_event.has(card.event):
			by_event[card.event] = {"event": card.event, "places": PackedStringArray()}
			entries.append(by_event[card.event])
		var where := place(card)
		var places: PackedStringArray = by_event[card.event]["places"]
		if not where.is_empty() and where not in places:
			places.append(where)
			by_event[card.event]["places"] = places
	return entries


static func _t(effect: EventData.EffectDef, value: String, target: String = "") -> String:
	var line := CampaignFormat.t("EVENT_EFFECT_" + effect.type.to_upper()) % value
	if not target.is_empty():
		line += " " + CampaignFormat.t("EVENT_EFFECT_WITH") % target
	if not effect.halved_by.is_empty():
		var building := CampaignFormat.t(EconomyTerm.building_key(effect.halved_by))
		line += " " + CampaignFormat.t("EVENT_EFFECT_HALVED") % building
	return line


static func _lords(target: String) -> String:
	if target.is_empty():
		return ""
	if target == target.to_upper():
		return CampaignFormat.province_name(target)
	return CampaignFormat.t("EVENT_GROUP_" + target.to_upper())


static func _key(event_id: String) -> String:
	return "EVENT_" + event_id.to_upper()
